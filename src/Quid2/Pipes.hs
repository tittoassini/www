{-# LANGUAGE NoMonomorphismRestriction #-}
module Quid2.Pipes(undup
                  --,everySecs,everyTime
                  ,period
                  ,io_,io) where

import Pipes
import qualified Pipes.Prelude as P
import Control.Applicative
import Control.Monad
import Quid2.Util.Time
import Quid2.Util.Strict
import Control.DeepSeq

t,tt :: IO ()
t = runEffect $ period (secs 2) >-> io (print . ("GOT " ++) . show)  >-> P.print

tt = runEffect $ each [1,3,3,3,4,4,5,7::Int] >-> undup >-> P.print

-- Remove duplicates values
undup :: (Monad m, Eq a) => Pipe a a m ()
undup = go Nothing
  where
    go p = do
      curr <- await
      case p of
        Nothing   -> yield curr
        Just prev -> when (curr /= prev) $ yield curr
      go (Just curr)

-- Produce a () indefinitely every given number of usecs. 
period :: MonadIO m => Int -> Producer () m ()
period delay = forever $ do
  yield ()
  waitFor delay

-- As mapM_ but with io executed in a strict try.
io_ :: (NFData b, MonadIO m) => IO b -> Pipe a (Either String b) m ()
io_ act = io (\_ -> act)

-- As mapM but with io executed in a strict try.
io :: (NFData b, MonadIO m) => (a -> IO b) -> Pipe a (Either String b) m ()
io act = forever $ do
  p <- await 
  v <- liftIO . (either (Left . show) Right <$>) . strictTry $ act p
  yield v

everySecs delayInSecs = everyTime (secs delayInSecs)

everyTime :: (MonadIO m, NFData a) => Int -> IO a -> Producer (Either String a) m ()
everyTime delay io = forever $ do
  v <- liftIO . (either (Left . show) Right <$>) . strictTry $ io
  yield v
  waitFor delay
  