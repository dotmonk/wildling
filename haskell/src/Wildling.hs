module Wildling
  ( Wildling
  , WildlingResult(..)
  , version
  , createWildling
  , wildlingIndex
  , wildlingCount
  , wildlingReset
  , wildlingNext
  , wildlingGenerators
  , wildlingGet
  ) where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Wildling.Generator (Generator, createGenerator, generatorCount, generatorGet)
import Wildling.ParsePattern (Dictionaries)

version :: String
version = "2.0.0"

data WildlingResult
  = WildlingString String
  | WildlingFalse
  deriving (Eq, Show)

data Wildling = Wildling
  { wlGenerators :: [Generator]
  , wlPatternCount :: Int
  , wlInternalIndex :: IORef Int
  }

createWildling :: [String] -> Dictionaries -> IO Wildling
createWildling patterns dictionaries = do
  let generators = map (`createGenerator` dictionaries) patterns
      total = sum (map generatorCount generators)
  idx <- newIORef 0
  pure
    Wildling
      { wlGenerators = generators
      , wlPatternCount = total
      , wlInternalIndex = idx
      }

wildlingIndex :: Wildling -> IO Int
wildlingIndex w = readIORef (wlInternalIndex w)

wildlingCount :: Wildling -> Int
wildlingCount = wlPatternCount

wildlingReset :: Wildling -> IO ()
wildlingReset w = writeIORef (wlInternalIndex w) 0

wildlingGenerators :: Wildling -> [Generator]
wildlingGenerators = wlGenerators

wildlingGet :: Wildling -> Int -> WildlingResult
wildlingGet w index
  | index > wlPatternCount w - 1 || index < 0 = WildlingFalse
  | otherwise = findSegment 0 (wlGenerators w)
  where
    findSegment _ [] = WildlingFalse
    findSegment segmentIndex (g : gs) =
      let patternIndex = index - segmentIndex
       in if patternIndex < generatorCount g
            then WildlingString (generatorGet g patternIndex)
            else findSegment (segmentIndex + generatorCount g) gs

wildlingNext :: Wildling -> IO WildlingResult
wildlingNext w = do
  idx <- readIORef (wlInternalIndex w)
  if idx == wlPatternCount w
    then pure WildlingFalse
    else do
      writeIORef (wlInternalIndex w) (idx + 1)
      pure (wildlingGet w idx)
