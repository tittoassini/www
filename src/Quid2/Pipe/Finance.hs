{-# LANGUAGE ScopedTypeVariables ,NoMonomorphismRestriction ,TypeSynonymInstances ,FlexibleInstances #-}
module Quid2.Pipe.Finance(
  quote,quoteP,Quote,StockBounds,Symbol
  ) where

import Control.Applicative
import Control.Monad
import Control.Exception
import Data.Maybe
import qualified Data.Map as M
import Data.Char
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
t5 = runEffect $ stockCheckP ("UIMV.DE",">=",2) >-> P.print
ttt = runEffect $ quoteP "UIMV.DE" >-> P.print
tt = mapM quote ["mt.mi","UIMV.dE"]
x = quote "xfvt.l"
y = quote "QFEI1.MI"

-- stockPipe (name,cond,val) = finQuote name >-> filterD (\(s,v)-> getCond cond val v) >-> mapD (\(s,v) -> unwords ["Stock",s,"has reached price",show v]) >-> chanOut "urgentStock"

stockCheckP :: StockCheck -> Producer Quote IO ()
stockCheckP (name,cond,val) = quoteP name >-> P.filter (\(_,ev)-> either (const True) (\v -> getCond cond val v) ev) >-> undup

getCond cond val = (flip . fromJust $ M.lookup cond conds) val
conds = M.fromList [("<",(<)),("<=",(<=)),(">",(>)),(">=",(>=))]

type StockCheck = (String,String,Double)

type StockBounds = (String,Double,Double)

quoteP :: Symbol -> Producer Quote IO ()
quoteP symbol = period (minutes 15) >-> P.mapM (\_ -> quote symbol)

type Symbol = String
type Quote = (Symbol,Either String Double)

quote :: String -> IO Quote
quote id = do
  ev <- if map toLower id == "uimv.de" then readGoogle "FRA%3AUIMV" else readYahoo_ id
  return (id,either (Left . show) (\v -> if v > 100000 then Left $ unwords ["Impossible value",show v] else Right v) ev)

-- Return a value when available or never if never available
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

g = readGoogle "FRA%3AUIMV"

readGoogle id =  strictTry $ do
  (_,q) <- getMime 45 $ "https://www.google.co.uk/finance?q=" ++ id
  -- print $ after "perf:" q >>= between ",p:\"" "\""
  let Just val = after "perf:" q >>= between ",p:\"" "\""
  -- print val  
  return (read val :: Double)
