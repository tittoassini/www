{-# LANGUAGE NoMonomorphismRestriction  #-}
module Quid2.Pipe.Email(
  gmailPipe,quidagentPipe,SimpleMessage(..)
  ) where

import Pipes
import qualified Pipes.Prelude as P
import Quid2.Pipes
import Quid2.Pipe.Time
import Pipes.Safe (bracket, MonadSafe ,runSafeT ,onException)
import qualified Data.Text as T -- hiding (take)
import Data.Text.Encoding
import Network.HaskellNet.IMAP hiding (list)
import Network.HaskellNet.IMAP.SSL
import Network.HaskellNet.POP3 -- as POP3
import Network.HaskellNet.POP3.SSL
import Text.ParserCombinators.Parsec ( parse )
import Text.ParserCombinators.Parsec.Rfc2822
import Control.Applicative
import Control.Monad
import Quid2.Util.Time
import Quid2.Util.Email
import Quid2.Util.Strict
import Quid2.Util.String
import Data.List.Utils
import Data.Maybe

t = runEffect $ quidagentPipe >-> P.print

tt = runSafeT $ runEffect $ quidagentIMAPPipe >-> P.map (getSimpleMessage <$>) >-> P.print

x = mapM (\m -> email quidagent ("prova " ++ m) m) ["aa","bb","cc"]

y = getPOP3Messages "quidagent@gmail.com" "..."

quidagentPipe = gmailPipe 120 "quidagent@gmail.com" "..."

quidagentIMAPPipe = gmailIMAPPipe 15 "quidagent@gmail.com" "..."

-- returned by smtp, not parsable.
l = parseSMTPMessage $ "Return-Path: <quidagent@gmail.com>\nReceived: from  ([85.210.201.148])\nby mx.google.com with ESMTPSA id fi2sm26296841wib.2.2014.05.06.11.29.54\nfor <quidagent@gmail.com>\n(version=TLSv1.2 cipher=RC4-SHA bits=128/128);\nTue, 06 May 2014 11:29:55 -0700 (PDT)\nMessage-ID: <53692a23.c265b40a.18b3.4e7c@mx.google.com>\nDate: Tue, 06 May 2014 11:29:55 -0700 (PDT)\nFrom: <quidagent@gmail.com>\nTo: <quidagent@gmail.com>\nSubject: prova cc\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: quoted-printable\n\ncc\n"

gmailPipe :: MonadIO m => Int -> String -> String -> Producer (Either String SimpleMessage) m () 
gmailPipe delayInSecs username password = gmailPipe_ delayInSecs username password >-> P.map (either Left (Right .getSimpleMessage)) >-> undup

{- 
Email pipe that produces a new value on receipt of a message.
* Could Use gmail atom feed to be warned about arrival of new message
  https://developers.google.com/gmail/gmail_inbox_feed
-}
gmailPipe_ :: MonadIO m => Int -> String -> String -> Producer (Either String Message) m () 
gmailPipe_ delayInSecs username password = email
  where
    email = forever $ do
      emsgs <- liftIO . strictTry $ getPOP3Messages username password
      either (yield . Left . show) (mapM_ emit) emsgs
      waitFor (secs delayInSecs)
    emit msg = yield $ either (Left . show) (Right) $ parseSMTPMsg msg

getPOP3Messages username password = do
  con <- connectPop3SSL "pop.gmail.com"
  userPass con username password
  ids <- allList con -- (id,sizeInBytes)
  -- print $ "ids " ++ (show $ reverse ids)
  msgs <- mapM (retr con) $ map fst ids
  -- msgs <- mapM (\i -> dele con i) $ map fst ids
  -- print msgs
  closePop3 con
  return msgs

gmailIMAPPipe :: MonadSafe m => Int -> String -> String -> Producer (Either String Message) m () 
gmailIMAPPipe delayInSecs username password = 
  bracket
  (liftIO $ openConn username password)
  (liftIO . logout)
  getMessages
    where
      getMessages con = forever $ do
        msgs <- liftIO $ recentMessages con
        mapM yield msgs
        waitFor (secs delayInSecs)

recentMessages con = do
  msgs <- search con [ALLs] -- FLAG Recent]
  forM msgs (\x -> (either (Left . show) Right . parseMsg) <$> fetch con x)

-- IMAP: come leggere efficentemente gli ultimi messaggi?
-- gmail does not seem to return RECENT correctly
-- read all messages and delete them immediately
openConn username password = do
  let imapServer = "imap.gmail.com"
  con <- connectIMAPSSL imapServer
  login con username password
  -- mboxes <- list con
  -- mapM print mboxes
  -- capability con >>= print
  -- select con "INBOX"
  -- subscribe con "INBOX"
  status con "INBOX" [UIDNEXT] >>= print
  -- search con [ALLs] >>= print
  -- print msgs
  -- mapM_ (\x -> print x) (take 4 msgs)
  -- forM_ (take 4 msgs) (\x -> fetch con x >>= print . parseMessage . T.unpack . decodeUtf8 ) -- mapM print . T.lines . decodeUtf8)
  return con

data SimpleMessage = SimpleMessage {from::String,subject::String,content::String} deriving (Eq,Show,Read,Ord)

getSimpleMessage (Message flds b) = SimpleMessage (getFrom flds) (getSubject flds) b 

getSubject flds =
  case filter isSubject $ flds of
    [Subject s] -> s
    _ -> ""  
  where
    isSubject (Subject _) = True
    isSubject _ = False

getFrom flds =
  case filter isFrom $ flds of
    [OptionalField "From" s] -> fromJust . (between "<" ">") $ s -- nameAddr_addr . head $ s
    _ -> ""  
  where
    isFrom (OptionalField "From" _) = True
    isFrom _ = False

parseMessage s = parse message "<msg>" (fixEol s)

parseSMTPMsg = parseSMTPMessage . T.unpack . decodeUtf8
parseMsg = parseMessage . T.unpack . decodeUtf8

parseSMTPMessage = parseMessage . fixSMTP

fixSMTP = fromJust . afterInclude "From:"

afterInclude :: (Eq a) => [a] -> [a] -> Maybe [a]
afterInclude srch text = subIndex srch text >>= \n -> return $ drop (n) text 


-- Make sure all lines are terminated by CRLF.
fixEol :: String -> String
fixEol ('\r':'\n':xs)   = '\r' : '\n' : fixEol xs
fixEol ('\n':xs)        = '\r' : '\n' : fixEol xs
fixEol (x:xs)           = x : fixEol xs
fixEol []               = []
