{-# LANGUAGE OverloadedStrings ,ScopedTypeVariables #-}
-- -*- mode:org;mode:haskell; -*-

import           Pipes
import qualified Pipes.Prelude as P
import           Pipes.Concurrent
import           Control.Concurrent.Async hiding (wait)
-- import           Control.Applicative
import           Control.Concurrent.STM.TVar as STM
-- import           Control.Monad
-- import           Data.Maybe
import qualified Data.Text.Lazy as TL
import qualified           Data.Text.Lazy.Encoding as TL
-- import           Data.Text.Encoding
import qualified Data.Text as T
import           Quid2.Pipes hiding (print,mapM,mapM_,take,show,concat)
import           Quid2.Pipe.Finance
import           Quid2.Pipe.File
import           Quid2.Util.Voice
import           Quid2.Util.Time
import           Quid2.Util.Dir
import           Quid2.Util.Email(email,titto)
import           Quid2.Util.Service
import qualified Quid2.Pipe.GitHub as GH
import           Web.Scotty
import           Data.String
import           Network.Wai.Middleware.RequestLogger (logStdoutDev)
import           System.Log.Logger
import           System.Log.Handler.Simple
-- import Text.Blaze.Html5
-- import Text.Blaze.Html5.Attributes
import           Data.Aeson
import qualified Data.ByteString.Char8 as S8
import           Data.Aeson.Types
-- import qualified Data.ByteString.Lazy as L
-- import           Data.List
-- import           Data.Ord
-- import qualified Network.Browser as N
-- import qualified Network.HTTP as N
-- import           Quid2.Util.String
import           System.Directory
import           System.FilePath
import           Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
-- import qualified Text.Blaze.Renderer.Utf8 as H
import Source.Salus(runSalus)
import Network.Wai.Middleware.StaticHost
import Network.Wai.Middleware.Autohead (autohead)
import Network.Wai.Middleware.Gzip
import Network.Wai.Middleware.AddHeaders
-- import Network.Wai.Middleware.Routes.ContentTypes

{-
Distributed version:
* Functions (lore, stock warnings) are indipendently deployed
* Delivery of results (by email, web) are not hardwired

Req:
	      	* Keep under control system and finance events.
                * Integrated WWW view
 		  * As most info is probably small is preferable to have a single page tree-like view also spanning multiple servers.
                * Email warnings for important events/errors (system failure,stock limits)
                * Upgradable objects (as for stocks, automatically updated on git update)
                * Upgradable views (a js or haskell view handler per data type)
                * API to post authorised updates to different channels
                  * HTTP API (hubbub stype): POST /1 ... Value
                  * Binary/Quid2 API:
                  * subscription http://dweet.io/

Browse quid2.

Titto Service
input topic "/titto/Warnings"

Stock Warning Service:
-- subscribe to relative "stockWarnings" ::Topic [(String,min,max)]
-- process and continuosly send warnings on relative topic "warnings" and "errors"

Salus Service:
at startup:
-- create endpoints for the two functions
-- associate endpoint folder to lorenzo.ambri/casa/salus/clearData and getData.. in default register (127.0.0.1:..)

To access the service, we just need to browse the central register.

Updatable GitHub Document Service:

Web Call Back Service:

Runnable Services:

TODO:
-- remove tvar, use just accumulating pipe

PROB: exits without apparent reason.

PROB: GOT STUCK with no more events shown (maybe data was incorrect?)

PROB: If the data is incorrect it gets stuck, freezes and NO WARNINGS RECEIVED.

PROB: cannot run as a service as:
-- email won't work as we cannot access secrets after switching to quid2-titto (SOL: read them while still root)
-- propellor shell commands needed to clone git still wont' work (even after not closing file descriptors)

SOL: start manually as (already done by propellor):
killall -s SIGKILL quid2-titto; /root/.cabal/bin/quid2-titto > /dev/null 2>&1 &
-}

-- /titto/stockWarnings

-- SalusData Address Address
data SalusData = SalusData {clearData::IO()
                           ,getDataAsCSV::IO String
                           }

-- data IOEndPoint = IOEndPoint []

type Address = String

-- t = runEffect $ fileValue 2 "/Users/titto/workspace/quid2-titto/stocks.hs") >->  >-> P.print

tt0 = onBounds b2
tt = runEffect $ stockBounds ("AAPL",66,70) >-> P.print

b1 = [("AAPL",366,500)]
b2 = [("unip.mi",2,4),("uni.mi",4.05,5),("mt.mi",1.5,2.3)]

t = main

x = email titto "quid2-titto" "just started"

-- http://nano.quid2.org:9000/hook/repo/test/push

serviceName = "quid2-titto"

main = initService serviceName setup

setup :: Config () -> IO ()
setup cfg = do
  updateGlobalLogger rootLoggerName $ setLevel DEBUG -- INFO -- DEBUG

  email titto "quid2-titto" "just started"

  reportMem <- STM.newTVarIO Nothing

  (userSeal,userOut) <- tittoMBox (pr reportMem)
  (githubUpdated,githubUpdatedTrigger) <- triggerMBox

  -- local test
  -- runEffect $ fileValue 5 "/Users/titto/workspace/quid2-titto/test/stocks.hs" >-> updateChecksC userOut Nothing

  -- distributed
  repoDir <- makeDir $ stateDir cfg </> "repo"
  debugM "Titto" $ "Made dir " ++ repoDir

  -- NOTE: use "root" as we are running as cmd and not a real service
  -- Every time we get a github update, rebuild checks
  async $ runEffect $ githubUpdated >-> GH.fileValue "root" repoDir "tittoassini" "test" "master" "values/stocks" >-> updateChecksC userOut Nothing

  loreDir <- makeDir $ stateDir cfg </> "lore"
  let salusFile = loreDir </> "salus"
  runSalus salusFile

  githubUpdatedTrigger

  serverReport <- do
    t <- timeDateTime
    return . scottyHTML $
      H.docTypeHtml $ do
        let h = fromString $ unwords ["Service",serviceName]
        H.head $ H.title h
        H.body $ do
          H.h1 h
          H.p $ fromString $ unwords ["Started up at",t]

  -- Run web static sites
  forkIO webServer

  -- nano.quid2.org services
  scotty 9000 $ do
    middleware logStdoutDev

    get "/" $ html serverReport

    get "/report" $ do
      report <- liftIO $ atomically $ STM.readTVar reportMem
      html . scottyHTML . reportAsHTML $ report

    get "/lore" $ html $ scottyHTML $
      H.docTypeHtml $ do
        let h = fromString "La roba ddi Lore"
        H.head $ H.title h
        H.body $ do
          H.h1 h
          H.ul $ do
            H.li $ H.a "get data as csv" H.! A.href "/lore/view"
            H.li $ H.a "clear data"      H.! A.href "/lore/clear"

    get "/lore/view" $ do
      setHeader "Content-Type" "text/csv"
      file salusFile

    get "/lore/clear" $ do
      liftIO $ removeFile salusFile
      text "salus file has been deleted"

    post "/hook/repo/:repo/:action" $ do
      repo :: String <- param "repo"
      action :: String <- param "action"
      liftIO githubUpdatedTrigger
      text ""

    -- /titto/plan return application files
    -- ws:quid2.org:8000?? plan app connector

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
            msg $ "Error in stocks data: " ++ err
            updateChecksC userOut Nothing
          Right bounds -> do
            msg "Updated stocks data"
            -- liftIO $ maybe (return ()) atomically maybeSeal
            warnsSeal <- liftIO $ connectBounds userOut bounds
            updateChecksC userOut (Just warnsSeal)
        where msg = liftIO . atomically . send userOut

webServer = scotty 80 $ middleware $ gzip (gzipConf "/tmp") . autohead . staticHost hosts nonStaticPrefixes . addHeaders allowHeaders

hosts = [h "quid2.org"
        ,h "kamus.it"
        ,h "jslib.quicquid.org"
        ,h "massimoassini.quicquid.org"
        ,h "ska.quicquid.org"
        ,h3 "finance.quicquid.org" "finance.quicquid.org" True -- PROB: NO LIVE UPDATE, NEED TO ADD finance
        ,h3 "quid2.com"    "quid2.org" False
        ,h3 "quid2.biz"    "quid2.org" False
        ,h3 "quid2.net"    "quid2.org" False
        ,h3 "quicquid.org" "quid2.org" False
     ] where
    h n = h3 n n False
    h3 n n2 b = Host {hostDomain=n,hostDir=T.concat [d,n2,"/web"],mutable=b}
    d = "/root/repo/workspace/" -- "/Users/titto/workspace/" -- "/home/workspace/"

nonStaticPrefixes = [] -- ["/api","/auth"]

allowHeaders = [("Access-Control-Allow-Origin","*")
               ,("Access-Control-Allow-Headers","Content-Type,Content-Length")
               ]

gzipConf tmpDir = def {
  gzipFiles = GzipCacheFolder (tmpDir ++ "/warp")
  ,gzipCheckMime = \f -> S8.isPrefixOf "text/" f || f == typeOctet
  }

typeOctet = "application/octet-stream"

scottyHTML = TL.decodeUtf8 . renderHtml

type Report = [(String,String)]


reportAsHTML :: Maybe Report -> H.Html
reportAsHTML mr = H.docTypeHtml $ do
    H.head $ H.title "Events"
    H.body $ do
        H.p "Events"
        maybe
          (H.p "No events.")
          (H.ul . mapM_ (\(d,m) -> H.li . H.toHtml $ unwords [d,":",m]))
          mr

connectBounds :: Output String -> [(String, Double, Double)] -> IO (STM ())
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
stockBounds (name,low,high) = quoteP name >-> P.filter (\(s,ev)-> either (const True) (\v -> v<=low || v >= high) ev) >-> P.map showQuote >-> undup

showQuote (s,Left err) = unwords ["Stock",s,"'s value cannot be read:",take 100 $ show err]
showQuote (s,Right v)  = unwords ["Stock",s,"has reached price",show v]

-- triggerMBox :: MonadIO m => IO (Producer () m (), IO Bool)
triggerMBox :: IO (Producer () IO (), IO Bool)
triggerMBox = do
  (output, input, seal) <- spawn' Unbounded
  return (fromInput input,atomically $ send output ())

tittoMBox :: (b -> IO ()) -> IO (STM (), Output b)
tittoMBox pr = do
  (output, input, seal) <- spawn' Unbounded
  mbox <- async $ runEffect $ fromInput input >-> for cat (liftIO . pr) -- >>
  return (seal,output) --  (mbox,output)

-- printWarn = P.map (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> for cat (\m -> liftIO (print m >> say m)) -- P.print -- P.chain (print)
