module System.Hardware.Modbus.Abstractions where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Exception (catch, throw)
import Control.Monad (forever)
import System.Hardware.Modbus

offKeeper :: TVar Bool -> STM Bool
offKeeper var = do
  state <- readTVar var
  if state then return True else retry

onKeeper :: TVar Bool -> TVar Bool -> STM Bool
onKeeper timer var = do
  state <- readTVar var
  timeout <- readTVar timer
  if state && not timeout then retry else return state

-- Public functions follow

-- |Relay which is controlled via Modbus function code 0x05 (force
-- single coil) and needs to be refreshed every given microseconds.
bitRelayWithTimer :: Int -> Master -> Int -> Int -> IO (TVar Bool)
bitRelayWithTimer timeout master slave addr = do
  var <- newTVarIO False
  let loop state = do
        sync $ writeBit master slave addr state
        f <- if state
             then onKeeper <$> registerDelay timeout
             else return offKeeper
        atomically (f var) >>= loop
  forkIO $ loop False
  return var

inputBitsVar :: Int -> Master -> Int -> Int -> Int -> IO ([STM Bool])
inputBitsVar interval master slave addr nb = do
  var <- action >>= mapM newTVarIO
  forkIO $ forever $ do
    threadDelay interval
    -- Try to divide current state to all variables. In case of an
    -- exception, propagate it to them.
    catch
      (action >>= atomically . sequence_ . zipWith writeTVar var)
      (\e -> atomically $ mapM_ (flip writeTVar (throw (e :: ModbusException))) var)
  return $ map readTVar var
  where action = sync $ readInputBits master slave addr nb

-- TODO how to kill these?
