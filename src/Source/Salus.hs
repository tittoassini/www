{-# LANGUAGE OverloadedStrings ,ScopedTypeVariables #-}
module Source.Salus(runSalus) where
import           Pipes
import qualified Pipes.Prelude as P
import qualified Data.Text.Lazy as T
import           Data.Text.Lazy.Encoding
import           Quid2.Util.Time
import           Control.Concurrent.Async hiding (wait)
import           Control.Applicative
import           Quid2.Pipes hiding (mapM,concat)
import           Quid2.Util.String
import           Data.List
import           Data.Aeson
-- -- import           Data.Aeson.Types
import qualified Network.Browser as N
import qualified Network.HTTP as N
-- import qualified Data.ByteString.Lazy
import Quid2.Util.PrivData

s = salus "/tmp/lore"
s2 = runSalus "/tmp/lore"

runSalus :: FilePath -> IO (Async ())
runSalus dir =
  async $
  runEffect $
  cronMinutes 5 >->
  io_ (salus dir) >->
  P.drain -- P.print

salus dir = readSalus >>= writeSalus dir

readSalus :: IO (Maybe Salus)
readSalus = do
      salusUser <- getPwd "salusUser"
      salusPassword <- getPwd "salusPassword"
      (_, rsp) <- N.browse $ do
        N.setAllowRedirects True
        (_,devs) <- N.request (N.postRequestWithBody "http://salus-it500.com/public/login.php?lang=en" "application/x-www-form-urlencoded" (concat ["IDemail=",salusUser,"&password=",salusPassword,"&login=Login"]))
        let Just token = (\b -> after "name=\"token\"" b >>= between "value=\"" "\"") . N.rspBody $ devs

        N.request $ N.getRequest $ "http://salus-it500.com/public/ajax_device_values.php?devId=17517&token=" ++ token
      let dt = encodeUtf8 . T.pack . N.rspBody $ rsp
      -- print dt
      return $ decode dt

writeSalus dir Nothing  = return ()
writeSalus fs (Just s) = do
  [d,t] <- words <$> timeDateTime
  -- appendFile (fs </> "salus")
  appendFile fs $ intercalate "," ([d,let Just s = till "." t in s] ++ flds s) ++ "\r\n"

data Salus = Salus {flds::[String]} deriving Show

instance FromJSON Salus where
     parseJSON (Object v) = Salus <$> (mapM (v .:) salusFlds) -- <$> (read <$> v .: "CH1currentRoomTemp") <*> (read <$> v .: "CH2currentRoomTemp")
     parseJSON _          = mzero

salusFlds = ["CH1currentRoomTemp","CH1currentSetPoint","CH1autoOff","CH1manual","CH1schedType","CH1heatOnOffStatus","CH1autoMode","CH1heatOnOff","CH1frostActive","CH2currentRoomTemp","CH2currentSetPoint","CH2autoOff","CH2manual","CH2schedType","CH2heatOnOffStatus","CH2autoMode","CH2heatOnOff","CH2frostActive","HWmode","HWboost","HWschedType","HWonOffStatus","HWautoMode","esStatus","tempUnit"]
