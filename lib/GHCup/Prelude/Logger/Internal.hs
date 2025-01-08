{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DataKinds        #-}
{-# LANGUAGE OverloadedStrings   #-}

{-|
Module      : GHCup.Utils.Logger.Internal
Description : logger definition
Copyright   : (c) Julian Ospald, 2020
License     : LGPL-3.0
Maintainer  : hasufell@hasufell.de
Stability   : experimental
Portability : portable

Breaking import cycles.
-}
module GHCup.Prelude.Logger.Internal where

import           GHCup.Types
import           GHCup.Types.Optics

import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Reader
import           Data.Text               ( Text )
import           Optics
import           Prelude                 hiding ( appendFile )
import           System.Console.Pretty

import qualified Data.Text                     as T

logInfo :: ( MonadReader env m
           , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
           , MonadIO m
           )
        => Text
        -> m ()
logInfo = logInternal Info

logWarn :: ( MonadReader env m
           , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
           , MonadIO m
           )
        => Text
        -> m ()
logWarn = logInternal Warn

logDebug :: ( MonadReader env m
            , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
            , MonadIO m
            )
         => Text
         -> m ()
logDebug = logInternal Debug

logError :: ( MonadReader env m
            , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
            , MonadIO m
            )
         => Text
         -> m ()
logError = logInternal Error


logInternal :: ( MonadReader env m
               , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
               , MonadIO m
               ) => LogLevel
                 -> Text
                 -> m ()
logInternal logLevel msg = do
  LoggerConfig {..} <- gets @"loggerConfig"
  let color' c = if fancyColors then color c else id
  let style' = case logLevel of
        Debug   -> style Bold . color' Blue
        Info    -> style Bold . color' Green
        Warn    -> style Bold . color' Yellow
        Error   -> style Bold . color' Red
  let l = case logLevel of
        Debug   -> style' "[ Debug ]"
        Info    -> style' "[ Info  ]"
        Warn    -> style' "[ Warn  ]"
        Error   -> style' "[ Error ]"
  let strs = T.split (== '\n') . T.dropWhileEnd (`elem` ("\n\r" :: String)) $ msg
  let out = case strs of
              [] -> T.empty
              (x:xs) ->
                  foldr (\a b -> a <> "\n" <> b) mempty
                . ((l <> " " <> x) :)
                . fmap (\line' -> style' "[ ...   ] " <> line' )
                $ xs

  when (lcPrintDebug || (not lcPrintDebug && (logLevel /= Debug)))
    $ liftIO $ consoleOutter out

  -- raw output
  let lr = case logLevel of
        Debug   -> "Debug:"
        Info    -> "Info:"
        Warn    -> "Warn:"
        Error   -> "Error:"
  let outr = lr <> " " <> msg <> "\n"
  liftIO $ fileOutter outr


logGroupStart :: ( MonadReader env m
               , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
               , MonadIO m
               ) => LogLevel
                 -> Text
                 -> m ()
logGroupStart logLevel msg = do
  LoggerConfig {..} <- gets @"loggerConfig"
  let color' c = if fancyColors then color c else id
  let style' = case logLevel of
        Debug   -> style Bold . color' Blue
        Info    -> style Bold . color' Green
        Warn    -> style Bold . color' Yellow
        Error   -> style Bold . color' Red
  let l = "##[group]" <> case logLevel of
        Debug   -> style' "[ Debug ]"
        Info    -> style' "[ Info  ]"
        Warn    -> style' "[ Warn  ]"
        Error   -> style' "[ Error ]"
  let strs = T.split (== '\n') . T.dropWhileEnd (`elem` ("\n\r" :: String)) $ msg
  let out = case strs of
              [] -> T.empty
              (x:xs) ->
                  foldr (\a b -> a <> "\n" <> b) mempty
                . ((l <> " " <> x) :)
                . fmap (\line' -> "[ ...   ] " <> line' )
                $ xs

  when (lcPrintDebug || (not lcPrintDebug && (logLevel /= Debug)))
    $ liftIO $ consoleOutter out

logGroupEnd :: ( MonadReader env m
               , LabelOptic' "loggerConfig" A_Lens env LoggerConfig
               , MonadIO m
               ) => LogLevel
                 -> m ()
logGroupEnd logLevel = do
  LoggerConfig {..} <- gets @"loggerConfig"
  let l = "##[endgroup]"
  when (lcPrintDebug || (not lcPrintDebug && (logLevel /= Debug)))
    $ liftIO $ consoleOutter l
