{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Network.Wai.Handler.WarpTLS    ( runTLS
                                                , tlsSettings
                                                )
import           Network.Wai.Handler.Warp       ( defaultSettings
                                                , setPort
                                                )
import           Network.Wai.Middleware.RequestLogger
                                                ( logStdoutDev )
import           Web.Scotty
import           Quid2.Util.Service
import           System.Log.Logger
import           System.Log.Handler.Simple


main :: IO ()
serviceName = "www"

main = initService serviceName setup

setup :: Config () -> IO ()
setup cfg = do
    updateGlobalLogger rootLoggerName $ setLevel DEBUG -- INFO -- DEBUG
    let tlsConfig = tlsSettings "your.crt" "your.key"
        config    = setPort 3443 defaultSettings
    waiApp <- scottyApp $ do
        get "/"      (text "hello")
        get "/hello" (text "hello again")
    runTLS tlsConfig config (logStdoutDev waiApp)
