{-# LANGUAGE OverloadedStrings ,ScopedTypeVariables #-}

import Pipes
import qualified Pipes.Prelude as P
import Pipes.Concurrent
import Control.Concurrent.Async hiding (wait)
import Control.Applicative
import Control.Concurrent.STM.TVar as STM
import Control.Monad
import Data.Maybe
import qualified Data.Text.Lazy as T
import Data.Text.Lazy.Encoding
import Quid2.Pipes
import Quid2.Pipe.Finance
import Quid2.Pipe.File
import Quid2.Util.Voice
import Quid2.Util.Time
import Quid2.Util.Dir
import Quid2.Util.Email(email,titto)
import Quid2.Util.Service
import qualified Quid2.Pipe.GitHub as GH
import Web.Scotty
import Data.String
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import System.Log.Logger
import System.Log.Handler.Simple
-- import Text.Blaze.Html5
-- import Text.Blaze.Html5.Attributes
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import System.FilePath


{-
TODO:
-- PROB: github raw might return outdated file
-- remove tvar, use just accumulating pipe

Distributed version. 
-}

-- t = runEffect $ fileValue 2 "/Users/titto/workspace/quid2-titto/stocks.hs") >->  >-> P.print

tt = onBounds b2
-- tt = runEffect $ stockBounds b2

b1 = [("AAPL",366,500)]
b2 = [("unip.mi",2,4),("uni.mi",4.05,5),("mt.mi",1.5,2.3)]

t = main

-- http://nano.quid2.org:8080/hook/repo/test/push

serviceName = "quid2-titto"
  
main = initService serviceName setup

setup :: Config () -> IO ()
setup cfg = do
  updateGlobalLogger rootLoggerName $ setLevel DEBUG -- INFO -- DEBUG
  
  reportMem <- STM.newTVarIO Nothing

  (userSeal,userOut) <- tittoMBox (pr reportMem)
  (githubUpdated,githubUpdatedTrigger) <- triggerMBox

  -- local
  -- runEffect $ fileValue 5 "/Users/titto/workspace/quid2-titto/stocks.hs" >-> updateChecksC userOut Nothing

  -- distributed
  repoDir <- makeDir $ stateDir cfg </> "repo"
  debugM "Titto" $ "Made dir " ++ repoDir
  
  async $ runEffect $ githubUpdated >-> GH.fileValue repoDir "tittoassini" "test" "master" "values/stocks" >-> updateChecksC userOut Nothing 

  githubUpdatedTrigger

  serverReport <- do
    t <- timeDateTime
    return . scottyHTML $ 
      H.docTypeHtml $ do
        let h = fromString $ unwords ["Service",serviceName] 
        H.head $ do
          H.title h
        H.body $ do
          H.h1 h
          H.p $ fromString $ unwords ["Started up at",t]

  scotty 8080 $ do
    middleware logStdoutDev

    get "/" $ html serverReport
      
    get "/report" $ do
      report <- liftIO $ atomically $ STM.readTVar reportMem 
      html . scottyHTML . reportAsHTML $ report 
      
    post "/hook/repo/:repo/:action" $ do
      repo :: String <- param "repo"
      action :: String <- param "action"
      liftIO $ githubUpdatedTrigger
      text ""
      
    where
      pr reportMem msg = do
        t <- timeDateTime
        let tmsg = (t,msg) 
        print tmsg
        email titto "stocks" msg
        -- say m
        atomically $ STM.modifyTVar' reportMem (Just . maybe [tmsg] (tmsg:))

      updateChecksC userOut maybeSeal = do
        eitherBounds <- await
        case eitherBounds of
          Left err -> updateChecksC userOut maybeSeal
          Right bounds -> do
            liftIO $ maybe (return ()) atomically maybeSeal
            warnsSeal <- liftIO $ connectBounds userOut bounds
            updateChecksC userOut (Just warnsSeal)

scottyHTML = decodeUtf8 . renderHtml

type Report = [(String,String)]
  
reportAsHTML :: Maybe Report -> H.Html
reportAsHTML mr = H.docTypeHtml $ do
    H.head $ do
        H.title "Events"
    H.body $ do
        H.p "Events"
        maybe
          (H.p "No events.")
          (H.ul . mapM_ (\(d,m) -> H.li . H.toHtml $ d))
          mr

connectBounds userOut bounds = do
  (warnsSeal,warnsInput) <- onBounds bounds
  async $ runEffect $ fromInput warnsInput >-> toOutput userOut
  return warnsSeal

onBounds bounds = do
  (output, input, seal) <- spawn' Unbounded

  ts <- mapM (\b -> async (runEffect $ stockBounds b >-> toOutput output)) bounds
  
  -- mapM_ wait (:ts)
  return (seal,input)

-- stockBounds :: StockBounds -> Effect IO ()
stockBounds (name,low,high) = quoteP name >-> P.filter (\(s,ev)-> either (const True) (\v -> v<=low || v >= high) ev) >-> P.map showQuote -- (\(s,v) -> unwords ["Stock",s,"has reached price",show v])

showQuote (s,Left err) = unwords ["Stock",s,"'s value cannot be read:",take 100 $ show err]
showQuote (s,Right v)  = unwords ["Stock",s,"has reached price",show v]                                                                
triggerMBox :: MonadIO m => IO (Producer () m (), IO Bool)
triggerMBox = do
  (output, input, seal) <- spawn' Unbounded
  return (fromInput input,atomically $ send output ())

tittoMBox pr = do
  (output, input, seal) <- spawn' Unbounded
  mbox <- async $ do runEffect $ fromInput input >-> for cat (liftIO . pr) -- >> 
  return (seal,output) --  (mbox,output)
           

-- printWarn = P.map (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> for cat (\m -> liftIO (print m >> say m)) -- P.print -- P.chain (print) 
