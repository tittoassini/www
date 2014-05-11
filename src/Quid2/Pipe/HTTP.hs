{-# LANGUAGE NoMonomorphismRestriction  #-}
module Quid2.Pipe.HTTP(http
                      ,githubValue
                      ) where

import Pipes
import qualified Pipes.Prelude as P
import Quid2.Pipes
-- import Quid2.Pipe.Time
import qualified System.IO as IO
import Quid2.Util.Strict
import Quid2.Util.Time
import Control.Applicative
import Control.Monad
import Control.DeepSeq
import Quid2.Util.HTTP(getMime)

t,tt,ttt,tttt :: IO ()
t = runEffect $ period (secs 2) >-> githubValue "tittoassini" "test" "master" "value" >-> P.map (either Left (Right . (+1))) >-> P.print

tttt = runEffect $ period (secs 2) >-> io_ (githubFile "tittoassini" "test" "master" "values/stocks") >-> P.print

ttt = runEffect $ httpValue 2 "http://kamus.it" >-> P.map (id::Either String Int-> Either String Int) >-> P.print

tt = runEffect $ http 2 "http://kamus.it" >-> P.print

httpValue :: (MonadIO m, Read a, Eq a ,NFData a) => Int -> String -> Producer (Either String a) m ()
httpValue delayInSecs httpURL = http delayInSecs httpURL >-> val

http delayInSecs httpURL = period (secs delayInSecs) >-> io_ (getMime 30 httpURL) >-> undup

-- Return contents of file in repo
githubValue ::  (MonadIO m, Read b) => String -> String -> String -> String -> Pipe a (Either String b) m ()
githubValue user repo branch path = io (\_ -> githubFile user repo branch path) >-> val

githubFile :: String -> String -> String -> String -> IO (String, String)
githubFile user repo branch path = (getMime 30 . concat $ ["https://raw.githubusercontent.com/",user,"/",repo,"/",branch,"/",path]) --  >>= \v -> print v >> return v 

val = P.map (either Left (Right . read . snd))
