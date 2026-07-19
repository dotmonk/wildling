module Wildling.ParsePattern
  ( Dictionaries
  , parsePattern
  ) where

import qualified Data.Map.Strict as Map
import Wildling.Token
  ( Token
  , TokenOptions(..)
  , createToken
  )

type Dictionaries = Map.Map String [String]

isSpecial :: Char -> Bool
isSpecial c = c `elem` ("#@$&?!-*%" :: String)

splitKeepingDelimiters :: String -> [String]
splitKeepingDelimiters input = go 0 0
  where
    len = length input
    at i = input !! i
    slice a b = take (b - a) (drop a input)

    go i literalStart
      | i >= len =
          if literalStart < len
            then [slice literalStart len]
            else []
      | i + 1 < len && at i == '\\' && isSpecial (at (i + 1)) =
          let before =
                if i > literalStart
                  then [slice literalStart i]
                  else []
              esc = [slice i (i + 2)]
           in before ++ esc ++ go (i + 2) (i + 2)
      | isSpecial (at i) && i + 1 < len && at (i + 1) == '{' =
          let j = findClose (i + 2)
           in if j < len && at j == '}'
                then
                  let before =
                        if i > literalStart
                          then [slice literalStart i]
                          else []
                      tok = [slice i (j + 1)]
                   in before ++ tok ++ go (j + 1) (j + 1)
                else go (i + 1) literalStart
      | isSpecial (at i) =
          let before =
                if i > literalStart
                  then [slice literalStart i]
                  else []
              tok = [slice i (i + 1)]
           in before ++ tok ++ go (i + 1) (i + 1)
      | otherwise = go (i + 1) literalStart

    findClose j
      | j >= len = j
      | at j == '}' = j
      | otherwise = findClose (j + 1)

parseLengthWithVariants :: String -> [String] -> TokenOptions
parseLengthWithVariants part variants =
  let (startLength, endLength) = parseBraceLengths part
   in TokenOptions
        { optString = Nothing
        , optStartLength = Just startLength
        , optEndLength = Just endLength
        , optVariants = variants
        , optSrc = part
        }

parseBraceLengths :: String -> (Int, Int)
parseBraceLengths part =
  case break (== '{') part of
    (_, '{' : rest) ->
      case break (== '}') rest of
        (inner, '}' : _) ->
          case break (== '-') inner of
            (left, '-' : right)
              | allDigit left && allDigit right && not (null left) && not (null right) ->
                  (read left, read right)
            _
              | allDigit inner && not (null inner) ->
                  let n = read inner in (n, n)
              | otherwise -> (1, 1)
        _ -> (1, 1)
    _ -> (1, 1)

allDigit :: String -> Bool
allDigit s = not (null s) && all (\c -> c >= '0' && c <= '9') s

data ParsedStringLength = ParsedStringLength
  { pslContent :: String
  , pslStartLength :: Int
  , pslEndLength :: Int
  }

parseLengthWithString :: String -> Maybe ParsedStringLength
parseLengthWithString part =
  case findOpen part of
    Nothing -> Nothing
    Just afterOpen ->
      case findLastQuote afterOpen of
        Nothing -> Nothing
        Just (content, afterQuote) ->
          let lengths = parseAfterQuote afterQuote
           in fmap
                ( \(s, e) ->
                    ParsedStringLength
                      { pslContent = content
                      , pslStartLength = s
                      , pslEndLength = e
                      }
                )
                lengths
  where
    findOpen s =
      case break (== '{') s of
        (_, '{' : '\'' : rest) -> Just rest
        _ -> Nothing

    findLastQuote s =
      case reverseFindQuote s of
        Nothing -> Nothing
        Just idx ->
          let content = take idx s
              after = drop (idx + 1) s
           in Just (content, after)

    reverseFindQuote s =
      case [i | (i, c) <- zip [0 ..] s, c == '\''] of
        [] -> Nothing
        xs -> Just (last xs)

    parseAfterQuote afterQuote
      | null afterQuote = Nothing
      | head afterQuote == '}' = Just (1, 1)
      | head afterQuote == ',' =
          let beforeBrace =
                case reverse afterQuote of
                  ('}' : revRest) -> reverse revRest
                  _ -> drop 1 afterQuote
              body = drop 1 beforeBrace
           in case break (== '-') body of
                (left, '-' : right)
                  | allDigit left && allDigit right ->
                      Just (read left, read right)
                _
                  | allDigit body && not (null body) ->
                      let n = read body in Just (n, n)
                  | otherwise -> Just (1, 1)
      | '}' `elem` afterQuote = Nothing
      | otherwise = Nothing

charsAsVariants :: String -> [String]
charsAsVariants = map (: [])

simpleTokenizer :: String -> String -> Token
simpleTokenizer alphabet part =
  createToken (parseLengthWithVariants part (charsAsVariants alphabet))

dictionaryTokenizer :: Dictionaries -> String -> Token
dictionaryTokenizer dictionaries part =
  case parseLengthWithString part of
    Just parsed
      | null (pslContent parsed) || Map.member (pslContent parsed) dictionaries ->
          createToken
            TokenOptions
              { optString = Just (pslContent parsed)
              , optStartLength = Just (pslStartLength parsed)
              , optEndLength = Just (pslEndLength parsed)
              , optVariants = Map.findWithDefault [] (pslContent parsed) dictionaries
              , optSrc = part
              }
    _ ->
      createToken
        TokenOptions
          { optString = Nothing
          , optStartLength = Just 1
          , optEndLength = Just 1
          , optVariants = [part]
          , optSrc = part
          }

wordsTokenizer :: String -> Token
wordsTokenizer part =
  case parseLengthWithString part of
    Nothing ->
      createToken
        TokenOptions
          { optString = Nothing
          , optStartLength = Just 1
          , optEndLength = Just 1
          , optVariants = [part]
          , optSrc = part
          }
    Just parsed ->
      let variants = map unescapeComma (splitCommaEscaped (pslContent parsed))
       in createToken
            TokenOptions
              { optString = Just (pslContent parsed)
              , optStartLength = Just (pslStartLength parsed)
              , optEndLength = Just (pslEndLength parsed)
              , optVariants = variants
              , optSrc = part
              }

splitCommaEscaped :: String -> [String]
splitCommaEscaped s = go s ""
  where
    go [] acc = [reverse acc]
    go ('\\' : ',' : rest) acc = go rest (',' : '\\' : acc)
    go (',' : rest) acc = reverse acc : go rest ""
    go (c : rest) acc = go rest (c : acc)

unescapeComma :: String -> String
unescapeComma [] = []
unescapeComma ('\\' : ',' : rest) = ',' : unescapeComma rest
unescapeComma (c : rest) = c : unescapeComma rest

partToToken :: Dictionaries -> String -> Token
partToToken _dictionaries [] =
  createToken
    TokenOptions
      { optString = Nothing
      , optStartLength = Just 1
      , optEndLength = Just 1
      , optVariants = [""]
      , optSrc = ""
      }
partToToken dictionaries part@(c : _) =
  case c of
    '#' -> simpleTokenizer "0123456789" part
    '@' -> simpleTokenizer "abcdefghijklmnopqrstuvwxyz" part
    '*' -> simpleTokenizer "abcdefghijklmnopqrstuvwxyz0123456789" part
    '-' ->
      simpleTokenizer
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        part
    '!' -> simpleTokenizer "ABCDEFGHIJKLMNOPQRSTUVWXYZ" part
    '?' -> simpleTokenizer "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" part
    '&' ->
      simpleTokenizer
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        part
    '%' -> dictionaryTokenizer dictionaries part
    '$' -> wordsTokenizer part
    '\\'
      | length part > 1 && isSpecial (part !! 1) ->
          createToken
            TokenOptions
              { optString = Nothing
              , optStartLength = Just 1
              , optEndLength = Just 1
              , optVariants = [drop 1 part]
              , optSrc = part
              }
      | otherwise ->
          createToken
            TokenOptions
              { optString = Nothing
              , optStartLength = Just 1
              , optEndLength = Just 1
              , optVariants = [part]
              , optSrc = part
              }
    _ ->
      createToken
        TokenOptions
          { optString = Nothing
          , optStartLength = Just 1
          , optEndLength = Just 1
          , optVariants = [part]
          , optSrc = part
          }

parsePattern :: String -> Dictionaries -> [Token]
parsePattern inputPattern dictionaries =
  map (partToToken dictionaries) (filter (not . null) (splitKeepingDelimiters inputPattern))
