{-# LANGUAGE ScopedTypeVariables ,NoMonomorphismRestriction ,TypeSynonymInstances ,FlexibleInstances #-}
module Quid2.Pipe.Finance(
  quote,quoteP,Quote,StockBounds
  ) where

import Control.Applicative
import Control.Monad
import Control.Exception
import Data.Maybe
import qualified Data.Map as M

import Pipes
import qualified Pipes.Prelude as P
import System.IO
import Quid2.Util.Strict(strictTry)
import Quid2.Util.String(after,between)
import Quid2.Util.HTTP(getMime)
import Quid2.Util.Time
import Quid2.Pipes


t :: IO ()
t = runEffect $ stockCheckP ("mt.mi",">=",2) >-> P.print
t4 = runEffect $ stockCheckP ("mtNOTREALLY.mi",">=",2) >-> P.print
ttt = runEffect $ quoteP "mt.mi" >-> P.print
tt = quote "mt.mi"
x = quote "xfvt.l"
y = quote "QFEI1.MI"

-- stockPipe (name,cond,val) = finQuote name >-> filterD (\(s,v)-> getCond cond val v) >-> mapD (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> chanOut "urgentStock"

stockCheckP :: StockCheck -> Producer Quote IO ()
stockCheckP (name,cond,val) = quoteP name >-> P.filter (\(_,ev)-> either (const True) (\v -> getCond cond val v) ev)

getCond cond val = (flip . fromJust $ M.lookup cond conds) val
conds = M.fromList [("<",(<)),("<=",(<=)),(">",(>)),(">=",(>=))]

type StockCheck = (String,String,Double)

type StockBounds = (String,Double,Double)

quoteP :: Symbol -> Producer Quote IO ()
quoteP symbol = loop >-> undup
  where
    loop = do
      q <- liftIO $ quote symbol
      yield q
      waitFor $ minutes 15
      loop

type Symbol = String
type Quote = (Symbol,Either String Double)

-- Return a value when available or never if never available
quote :: String -> IO Quote
quote id = do
  ev <- readYahoo_ id
  return (id,either (Left . show) (\v -> if v > 100000 then Left $ unwords ["Impossible value",show v] else Right v) ev)

quoteEventually :: String -> IO Double
quoteEventually id = do
  r <- readYahoo_ id
  case r of
    Left (err::SomeException) -> print (unwords ["Failed accessing stock",id,show err]) >> wait (secs 30) >> quoteEventually id
    Right ok -> return ok

readYahoo_ id = strictTry $ do
  (_,q) <- getMime 45 $ "http://uk.finance.yahoo.com/q?s=" ++ id
  let Just val = filter (/= ',') <$> (after "<span class=\"time_rtq_ticker\"><" q) >>= between ">" "</span>"
  -- print val  
  return (read val :: Double)
