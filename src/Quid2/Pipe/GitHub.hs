{-# LANGUAGE NoMonomorphismRestriction  #-}
module Quid2.Pipe.GitHub(fileValue) where

import Pipes
import qualified Pipes.Prelude as P
import Quid2.Pipes
-- import Quid2.Pipe.Time
-- import Github.Gists -- import qualified System.IO as IO
import Control.Applicative
import Control.Monad
import Control.DeepSeq
import Quid2.Util.HTTP(getMime)

import Propellor hiding (read)
import Propellor.Property.Git -- (cloned)
import Propellor.Attr

import Data.List (intercalate)

t = rep "test"

rep repo = clonedRepo "titto" ("https://github.com/tittoassini/" ++ repo) ("/tmp/repo/"++repo) Nothing

-- Return contents of file in repo
fileValue ::  (MonadIO m, Read b) => String -> FilePath -> String -> String -> String -> String -> Pipe a (Either String b) m ()
fileValue localUser workDir user repo branch path = io (\_ -> fileContent localUser workDir user repo branch path) >-> val

fileContent :: String -> FilePath -> String -> String -> String -> String -> IO String
fileContent localUser workDir user repo branch path = do
  clonedRepo localUser (concat ["https://github.com/",user,"/",repo]) workDir (Just branch)
  let fs = workDir </> repo </> path
  readFile fs

-- PROB: works only in Ubuntu/Debian
clonedRepo :: UserName -> RepoUrl -> FilePath -> Maybe Branch -> IO Result
clonedRepo owner url dir mbranch = runPropellor hostnameless $ ensureProperty $ cloned owner url dir mbranch

-- Return contents of file in repo
fileValueMIME ::  (MonadIO m, Read b) => FilePath -> String -> String -> String -> String -> Pipe a (Either String b) m ()
fileValueMIME workDir user repo branch path = io (\_ -> fileMIME user repo branch path) >-> valMIME

fileMIME :: String -> String -> String -> String -> IO (String, String)
fileMIME user repo branch path = (getMime 30 . concat $ ["https://raw.githubusercontent.com/",user,"/",repo,"/",branch,"/",path]) --  >>= \v -> print v >> return v 

valMIME = P.map (either Left (Right . read . snd))

val = P.map (either Left (Right . read))

{-
-- (gistFiles) <$> 
t = gist "85fa20a9be6bbbeb6954"

x =  Github.gist "23084"

main = do
  possibleGist <- Github.gist "23084"
  case possibleGist of
    (Left error)  -> putStrLn $ "Error: " ++ (show error)
    (Right gist) -> putStrLn $ formatGist gist

formatGist gist =
  (Github.gistId gist) ++ "\n" ++
    (maybe "indescribable" id $ Github.gistDescription gist) ++ "\n" ++
    (Github.gistHtmlUrl gist) ++ "\n\n" ++
    (intercalate "\n\n" $ map formatGistFile $ Github.gistFiles gist)

formatGistFile gistFile =
  (Github.gistFileFilename gistFile) ++ ":\n" ++
    maybe "[empty]" id (Github.gistFileContent gistFile)
-}