{-# LANGUAGE OverloadedStrings ,ScopedTypeVariables #-}

import Pipes
import qualified Pipes.Prelude as P
import Pipes.Concurrent
import Control.Concurrent.Async hiding (wait)
import Control.Applicative
import Data.Maybe
import Quid2.Pipes
import Quid2.Pipe.Finance
import Quid2.Pipe.File
import Quid2.Util.Voice
import Quid2.Util.Time
import Quid2.Util.Email(email,titto)
import Quid2.Util.Service
import Quid2.Pipe.HTTP(githubValue)
import Web.Scotty
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import System.Log.Logger
import System.Log.Handler.Simple

-- t = runEffect $ fileValue 2 "/Users/titto/workspace/quid2-titto/stocks.hs") >->  >-> P.print

tt = onBounds b2
-- tt = runEffect $ stockBounds b2

b1 = [("AAPL",366,500)]
b2 = [("unip.mi",2,4),("uni.mi",4.05,5),("mt.mi",1.5,2.3)]

t = main

-- PROB:
-- github raw might return outdated file

main = initService "quid2-titto" setup

setup :: Config () -> IO ()
setup cfg = do      
  updateGlobalLogger rootLoggerName $ setLevel INFO -- DEBUG -- INFO -- DEBUG    

  (userSeal,userOut) <- tittoMBox
  (githubUpdated,githubUpdatedTrigger) <- triggerMBox

  -- local
  -- runEffect $ fileValue 5 "/Users/titto/workspace/quid2-titto/stocks.hs" >-> updateChecksC userOut Nothing

  -- distributed
  async $ runEffect $ githubUpdated >-> githubValue "tittoassini" "test" "master" "values/stocks" >-> updateChecksC userOut Nothing 

  githubUpdatedTrigger

  scotty 8080 $ do
    middleware logStdoutDev
        
    post "/hook/repo/:repo/:action" $ do
      repo :: String <- param "repo"
      action :: String <- param "action"
      liftIO $ githubUpdatedTrigger
      text ""
  
    where
      updateChecksC userOut maybeSeal = do
        eitherBounds <- await
        case eitherBounds of
          Left err -> updateChecksC userOut maybeSeal
          Right bounds -> do
            liftIO $ maybe (return ()) atomically maybeSeal
            warnsSeal <- liftIO $ connectBounds userOut bounds
            updateChecksC userOut (Just warnsSeal)

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

tittoMBox = do
  (output, input, seal) <- spawn' Unbounded
  mbox <- async $ do runEffect $ fromInput input >-> for cat (\m -> liftIO (print m >> email titto "stocks" m)) -- >> say m
  return (seal,output) --  (mbox,output)

-- printWarn = P.map (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> for cat (\m -> liftIO (print m >> say m)) -- P.print -- P.chain (print) 
