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
import Propellor.Property.Git -- (wrongRepo) -- (cloned)
import Propellor.Property.File
import Propellor.Attr

import System.Log.Logger
import Data.List (intercalate)

t = fileContent "/tmp" "tittoassini" "test" "master" "values/stocks"

x = rep "test"

rep repo = clonedRepo "titto" ("https://github.com/tittoassini/" ++ repo) ("/tmp/repo/"++repo) Nothing

-- Return contents of file in repo
fileValue ::  (MonadIO m, Read b) => String -> FilePath -> String -> String -> String -> String -> Pipe a (Either String b) m ()
fileValue localUser workDir user repo branch path = io_ (fileContent localUser workDir user repo branch path) >-> val

fileContent :: String -> FilePath -> String -> String -> String -> String -> IO String
fileContent localUser workDir user repo branch path = do  
  -- MadeChange <- clonedRepo localUser (concat ["https://github.com/",user,"/",repo]) (workDir </> repo) (Just branch)
  let repoDir = workDir </> repo
  let url = concat ["https://github.com/",user,"/",repo]
  -- ifM (wrongRepo repoDir url) () ()
  let fs = repoDir </> path
  -- debugM "Quid2.Util.GitHub.fileContent" $ "Reading " ++ fs
  -- r1 <- runProp $ userScriptProperty "quid2-titto" $ ["ls -l"]
  -- debugM "Quid2.Util.GitHub.fileContent" $ "Res1 " ++ show r1
  -- let localUser = "quid2-titto"
  r <- clonedRepo localUser url repoDir (Just branch)
  debugM "Quid2.Util.GitHub.fileContent" $ "Res " ++ show r
  readFile fs

-- updatedRepo :: FilePath -> RepoUrl -> FilePath -> Branch -> IO ()
-- updatedRepo workDir owner url dir branch = return ()

-- PROB: won't run from a daemon
-- commands that produce output will fail with a sendWakeup: invalid argument (Bad file descriptor) as the daemon has no stdin/out/err.  
y = runProp $ userScriptProperty "" $ ["ls -l"]

runProp =  runPropellor hostnameless . ensureProperty

-- PROB: works only in Ubuntu/Debian
clonedRepo :: UserName -> RepoUrl -> FilePath -> Maybe Branch -> IO Result
clonedRepo owner url dir mbranch = runProp $ cloned_ owner url dir mbranch

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