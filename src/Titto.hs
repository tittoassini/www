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
-- remove tvar, use just accumulating pipe

Distributed version.
* Server that returns streams using SSE or long polling. 
* How to add other js handlers?

PROB: If the data is incorrect it gets stuck and NO WARNINGS RECEIVED.

PROB: cannot run as a service as:
-- email won't work as we cannot access secrets after switching to quid2-titto (SOL: read them while still root)
-- propellor shell commands needed to clone git still wont' work (even after not closing file descriptors)
SOL: start manually as (already done by propellor)
killall -s SIGKILL quid2-titto; /root/.cabal/bin/quid2-titto > /dev/null 2>&1 &
-}

-- t = runEffect $ fileValue 2 "/Users/titto/workspace/quid2-titto/stocks.hs") >->  >-> P.print

tt0 = onBounds b2
tt = runEffect $ stockBounds ("AAPL",66,70) >-> P.print

b1 = [("AAPL",366,500)]
b2 = [("unip.mi",2,4),("uni.mi",4.05,5),("mt.mi",1.5,2.3)]

b3 = [("AAPL",60,80)
     ,("XFFE.mi",121,126)
     ,("xstr.mi",220,233)
     ,("XBCT.MI",188,190)
     ,("eue.mi",29.5,35)
     ,("uti.mi",33.3,37)
     ,("ener.mi",15,17)
     ,("fmi.mi",25,37.5)
     ,("ETFMIB.MI",20.5,22.7)
     ,("grc.mi",1.63,2.15)
     ,("lafri.mi",8.1,9)
     ,("unip.mi",3.8,5.36),("uni.mi",3.9,5.8)
     ,("mt.mi",2.2,2.7),("bp.mi",12.5,15),("ubi.mi",6,7.4)
     ,("ana.mc",40,66)
     ,("QFAL.MI",1000,1525)
     ,("QFEI1.MI",550,800)
     ,("QFIRS.MI",945,1150)
     ,("QFOBE.MI",640,850)
     ,("CD91.DE",14.8,25)
     ,("UIMV.DE",4.5,8)
      
     ,("xuks.l",540,590)
     ,("imib.l",750,1080)
     ,("inrg.l",350,410)
     ,("xfvt.l",1370,1953)
      
     ,("IEEM.MI",25,30)
     ,("xmrc.mi",16,22)
     ,("xx25.mi",16,23.5)
     ,("BRZ.MI",28,40)
     ,("ITKY.MI",21,28)
     ,("PSP",11.1,12.5)
     ,("PHAG.MI",13,22)
     ]

t = main

x = email titto "quid2-titto" "just started"

-- http://nano.quid2.org:8080/hook/repo/test/push

serviceName = "quid2-titto"
  
main = initService serviceName setup

setup :: Config () -> IO ()
setup cfg = do
  updateGlobalLogger rootLoggerName $ setLevel DEBUG -- INFO -- DEBUG

  email titto "quid2-titto" "just started"
  
  reportMem <- STM.newTVarIO Nothing

  (userSeal,userOut) <- tittoMBox (pr reportMem)
  (githubUpdated,githubUpdatedTrigger) <- triggerMBox

  -- local
  -- runEffect $ fileValue 5 "/Users/titto/workspace/quid2-titto/test/stocks.hs" >-> updateChecksC userOut Nothing

  -- distributed
  repoDir <- makeDir $ stateDir cfg </> "repo"
  debugM "Titto" $ "Made dir " ++ repoDir

  -- NOTE: use "root" as we are running as cmd and not a real service
  -- Every time we get a github update, rebuild checks
  async $ runEffect $ githubUpdated >-> GH.fileValue "root" repoDir "tittoassini" "test" "master" "values/stocks" >-> updateChecksC userOut Nothing 
  
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
      -- Send output by email and also save it for display on /report
      pr reportMem msg = do
        t <- timeDateTime
        let tmsg = (t,msg) 
        print tmsg
        email titto "stocks" msg
        -- say m
        atomically $ STM.modifyTVar' reportMem (Just . maybe [tmsg] (tmsg:))

      updateChecksC userOut maybeSeal = do
        eitherBounds <- await
        liftIO $ maybe (return ()) atomically maybeSeal
        case eitherBounds of
          Left err -> do -- BUG: no message and gets stuck
            liftIO $ atomically $ send userOut err
            updateChecksC userOut Nothing -- maybeSeal
          Right bounds -> do
            -- liftIO $ maybe (return ()) atomically maybeSeal
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
          (H.ul . mapM_ (\(d,m) -> H.li . H.toHtml $ (unwords [d,":",m])))
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

stockBounds :: (String, Double, Double) -> Producer String IO ()
stockBounds (name,low,high) = quoteP name >-> P.filter (\(s,ev)-> either (const True) (\v -> v<=low || v >= high) ev) >-> P.map showQuote

showQuote (s,Left err) = unwords ["Stock",s,"'s value cannot be read:",take 100 $ show err]
showQuote (s,Right v)  = unwords ["Stock",s,"has reached price",show v]                                                                
triggerMBox :: MonadIO m => IO (Producer () m (), IO Bool)
triggerMBox = do
  (output, input, seal) <- spawn' Unbounded
  return (fromInput input,atomically $ send output ())

tittoMBox :: (b -> IO ()) -> IO (STM (), Output b)
tittoMBox pr = do
  (output, input, seal) <- spawn' Unbounded
  mbox <- async $ do runEffect $ fromInput input >-> for cat (liftIO . pr) -- >> 
  return (seal,output) --  (mbox,output)
           

-- printWarn = P.map (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> for cat (\m -> liftIO (print m >> say m)) -- P.print -- P.chain (print) 
