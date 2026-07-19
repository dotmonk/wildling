module Main (main) where

import System.Environment (getArgs)
import Wildling.Cli (runCli)

main :: IO ()
main = getArgs >>= runCli
