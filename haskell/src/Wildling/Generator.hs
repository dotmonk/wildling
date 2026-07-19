module Wildling.Generator
  ( Generator(..)
  , createGenerator
  , generatorCount
  , generatorGet
  ) where

import Wildling.ParsePattern (Dictionaries, parsePattern)
import Wildling.Token (Token, tokenCount, tokenGet)

data Generator = Generator
  { generatorSource :: String
  , generatorTokens :: [Token]
  , generatorCount_ :: Int
  }

createGenerator :: String -> Dictionaries -> Generator
createGenerator inputPattern dictionaries =
  let tokens = parsePattern inputPattern dictionaries
      count = product (map tokenCount tokens)
   in Generator
        { generatorSource = inputPattern
        , generatorTokens = tokens
        , generatorCount_ = count
        }

generatorCount :: Generator -> Int
generatorCount = generatorCount_

generatorGet :: Generator -> Int -> String
generatorGet gen index
  | index > generatorCount_ gen - 1 || index < 0 = ""
  | otherwise = concat (go index (generatorTokens gen))
  where
    go _ [] = []
    go idx (t : ts) =
      let c = tokenCount t
       in tokenGet t (idx `mod` c) : go (idx `div` c) ts
