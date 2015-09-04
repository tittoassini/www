module Quid2.Pipe.File(fileValue) where

import Pipes
import qualified Pipes.Prelude as P
import Quid2.Pipes
import qualified System.IO as IO
-- -- import Quid2.Util.Strict
import Quid2.Util.Time
import Control.Applicative
-- -- import Control.Monad
import Control.DeepSeq

t :: IO ()
t = runEffect $ fileValue 3 "/Users/titto/workspace/quid2-titto/test/value.hs" >-> P.map (id::Either String Int-> Either String Int) >-> P.print

fileValue :: (MonadIO m, Read a, Eq a ,NFData a) => Int -> FilePath -> Producer (Either String a) m ()
fileValue delayInSecs filePath = period (secs delayInSecs) >-> io_ ((Prelude.read <$>) . IO.readFile $ filePath) >-> undup
