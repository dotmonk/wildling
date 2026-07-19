module Wildling.Token
  ( Token(..)
  , TokenOptions(..)
  , createToken
  , tokenCount
  , tokenSrc
  , tokenGet
  ) where

data TokenOptions = TokenOptions
  { optString :: Maybe String
  , optStartLength :: Maybe Int
  , optEndLength :: Maybe Int
  , optVariants :: [String]
  , optSrc :: String
  }

data Token = Token
  { tokenSrc_ :: String
  , tokenStartLength :: Int
  , tokenEndLength :: Int
  , tokenVariants :: [String]
  , tokenCount_ :: Int
  }

defaultInteger :: Maybe Int -> Int -> Int
defaultInteger (Just n) _ | n >= 0 = n
defaultInteger _ fallback = fallback

powInt :: Int -> Int -> Int
powInt base expn
  | expn < 0 = 0
  | otherwise = go 1 expn
  where
    go acc 0 = acc
    go acc n = go (acc * base) (n - 1)

createToken :: TokenOptions -> Token
createToken options =
  let startLength = defaultInteger (optStartLength options) 1
      endLength = defaultInteger (optEndLength options) 1
      variants = optVariants options
      count =
        sum
          [ powInt (length variants) len
          | len <- [startLength .. endLength]
          ]
   in Token
        { tokenSrc_ = optSrc options
        , tokenStartLength = startLength
        , tokenEndLength = endLength
        , tokenVariants = variants
        , tokenCount_ = count
        }

tokenCount :: Token -> Int
tokenCount = tokenCount_

tokenSrc :: Token -> String
tokenSrc = tokenSrc_

tokenGet :: Token -> Int -> String
tokenGet token index
  | index > tokenCount_ token - 1 || index < 0 = ""
  | index == 0 && tokenStartLength token == 0 = ""
  | otherwise =
      let (stringLength, indexWithOffset) = findLength (tokenStartLength token) index
          variants = tokenVariants token
          n = length variants
       in buildString stringLength indexWithOffset n variants
  where
    findLength length_ idx
      | length_ > tokenEndLength token = (tokenEndLength token, idx)
      | otherwise =
          let offsetCount = powInt (length (tokenVariants token)) length_
           in if idx < offsetCount
                then (length_, idx)
                else findLength (length_ + 1) (idx - offsetCount)

    buildString 0 _ _ _ = ""
    buildString remaining idx n variants =
      let variantIndex = idx `mod` n
          nextIdx = idx `div` n
       in (variants !! variantIndex) ++ buildString (remaining - 1) nextIdx n variants
