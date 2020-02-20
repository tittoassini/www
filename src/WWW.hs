{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Main where

import           Network.Wai.Handler.WarpTLS (runTLS, tlsSettings)
import           Network.Wai.Handler.Warp (defaultSettings, setPort)
import           Network.Wai.Middleware.RequestLogger (logStdoutDev)
import           Web.Scotty
import           Quid2.Util.Service
import           System.Log.Logger
import           System.Log.Handler.Simple
import           Network.Wai.Middleware.StaticHost
import           Network.Wai.Middleware.Autohead (autohead)
import           Network.Wai.Middleware.Gzip
import           Network.Wai.Middleware.AddHeaders
import qualified Data.Text as T
import           Control.Concurrent (forkIO)
import           System.FilePath
import GitHash
-- import           Web.Scotty.TLS


-- TODO:  move in tapp
versionID :: String 
versionID = concat [giBranch gi, "@", giHash gi, " (", giCommitDate gi, ")"]
  where
        gi = $$tGitInfoCwd

serviceName = "www"

main :: IO ()
main = initService serviceName setup

httpPort = 80

httpsPort = 443

-- httpPort = 8080
-- httpsPort = 4430
setup :: Config () -> IO ()
setup cfg = do
  updateGlobalLogger rootLoggerName $ setLevel DEBUG -- INFO -- DEBUG
  putStrLn $ unwords [serviceName,"version:",versionID]
  forkIO $ scotty httpPort httpServer
  app <- scottyApp httpServer
  let appDev = logStdoutDev app
  -- app <- scottyApp $      get "/" (text "hello")
  let tlsConfig =
        tlsSettings (certFile "fullchain.pem") (certFile "privkey.pem")
      config = setPort httpsPort defaultSettings
  runTLS tlsConfig config appDev

certFile = (certDir </>)

certDir = "./private/certbot/quid2.org"

-- certDir = "/etc/letsencrypt/live"
httpServer = middleware
  $ gzip (def { gzipFiles = GzipCacheFolder "/tmp/www" })
  . autohead
  . staticHost hosts nonStaticPrefixes
  . addHeaders allowHeaders

allowHeaders =
  [ ("Access-Control-Allow-Origin", "*")
  , ("Access-Control-Allow-Headers", "Content-Type,Content-Length")]

nonStaticPrefixes = [] -- ["/api","/auth"]

hosts =
  [ h2 "quid2.org"
  , h "kamus.it"
  , h "jslib.quicquid.org"
  , h "massimoassini.quicquid.org"
  , h "ska.quicquid.org"
    -- , h3 "finance.quicquid.org" "finance.quicquid.org" True -- PROB: NO LIVE UPDATE, NEED TO ADD finance
  , h3 "quid2.com" "quid2.org" False
  , h3 "quid2.biz" "quid2.org" False
  , h3 "quid2.net" "quid2.org" False
  , h3 "quicquid.org" "quid2.org" False]
  where
    h n = h3 n n False

    h2 n = h3 n n True

    h3 n n2 b =
      Host { hostDomain = n, hostDir = T.concat [d, n2, "/web"], mutable = b }

    -- d = "/root/repo/workspace/" -- "/Users/titto/workspace/" -- "/home/workspace/"
    d = "./site/" -- "/Users/titto/workspace/" -- "/home/workspace/"
