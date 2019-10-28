{-# LANGUAGE OverloadedStrings #-}
module Control.Hackbus.JsonCommands where

import Control.Applicative
import Control.Monad (liftM)
import Data.Aeson
import qualified Data.Text as T
import qualified Data.Map.Lazy as M

data Command = Read [T.Text] | Write (M.Map T.Text Value) deriving (Show)

data Answer = Wrote | Return (M.Map T.Text Value) | Failed String deriving (Show)

instance FromJSON Command where
  parseJSON = withObject "Commands" $ \v -> do
    method <- v .: "method"
    case method of
      "r" -> Read <$> (v .: "params" <|> s (v .: "params"))
      "w" -> Write <$> v .: "params"
      x -> fail $ "Unknown command: " ++ x
    where s = liftM pure -- In case of single value we don't need a list

instance ToJSON Answer where
  toJSON Wrote      = object []
  toJSON (Return x) = object ["v" .= x]
  toJSON (Failed x) = object ["error" .= x]
