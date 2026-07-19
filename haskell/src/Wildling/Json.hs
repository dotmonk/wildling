module Wildling.Json
  ( JsonValue(..)
  , parseJson
  ) where

import Data.Char (chr, isDigit, isHexDigit, isSpace)
import Data.List (foldl')

data JsonValue
  = JsonNull
  | JsonBool Bool
  | JsonNumber Double
  | JsonString String
  | JsonArray [JsonValue]
  | JsonObject [(String, JsonValue)]
  deriving (Eq, Show)

parseJson :: String -> Either String JsonValue
parseJson text =
  case parseValue (dropWhile isSpace text) of
    Left err -> Left err
    Right (value, rest) ->
      case dropWhile isSpace rest of
        "" -> Right value
        _ -> Left "Trailing content"

parseValue :: String -> Either String (JsonValue, String)
parseValue s =
  case dropWhile isSpace s of
    [] -> Left "Unexpected end"
    '{' : rest -> parseObject rest
    '[' : rest -> parseArray rest
    '"' : rest -> do
      (str, rest') <- parseString rest
      pure (JsonString str, rest')
    't' : 'r' : 'u' : 'e' : rest -> pure (JsonBool True, rest)
    'f' : 'a' : 'l' : 's' : 'e' : rest -> pure (JsonBool False, rest)
    'n' : 'u' : 'l' : 'l' : rest -> pure (JsonNull, rest)
    c : _
      | c == '-' || isDigit c -> parseNumber s'
      | otherwise -> Left "Unexpected character"
      where
        s' = dropWhile isSpace s

parseObject :: String -> Either String (JsonValue, String)
parseObject s0 =
  let s = dropWhile isSpace s0
   in case s of
        '}' : rest -> pure (JsonObject [], rest)
        _ -> go [] s
  where
    go acc s =
      case dropWhile isSpace s of
        '"' : rest -> do
          (key, rest1) <- parseString rest
          case dropWhile isSpace rest1 of
            ':' : rest2 -> do
              (value, rest3) <- parseValue rest2
              let acc' = acc ++ [(key, value)]
              case dropWhile isSpace rest3 of
                '}' : rest4 -> pure (JsonObject acc', rest4)
                ',' : rest4 -> go acc' rest4
                _ -> Left "Expected ',' or '}' in object"
            _ -> Left "Expected ':' in object"
        _ -> Left "Expected string key in object"

parseArray :: String -> Either String (JsonValue, String)
parseArray s0 =
  let s = dropWhile isSpace s0
   in case s of
        ']' : rest -> pure (JsonArray [], rest)
        _ -> go [] s
  where
    go acc s = do
      (value, rest1) <- parseValue s
      let acc' = acc ++ [value]
      case dropWhile isSpace rest1 of
        ']' : rest2 -> pure (JsonArray acc', rest2)
        ',' : rest2 -> go acc' rest2
        _ -> Left "Expected ',' or ']' in array"

parseString :: String -> Either String (String, String)
parseString = go []
  where
    go acc [] = Left "Unterminated string"
    go acc ('"' : rest) = pure (reverse acc, rest)
    go acc ('\\' : rest) = do
      (c, rest') <- parseEscape rest
      go (c : acc) rest'
    go acc (c : rest) = go (c : acc) rest

parseEscape :: String -> Either String (Char, String)
parseEscape [] = Left "Unterminated escape"
parseEscape ('"' : rest) = pure ('"', rest)
parseEscape ('\\' : rest) = pure ('\\', rest)
parseEscape ('/' : rest) = pure ('/', rest)
parseEscape ('b' : rest) = pure ('\b', rest)
parseEscape ('f' : rest) = pure ('\f', rest)
parseEscape ('n' : rest) = pure ('\n', rest)
parseEscape ('r' : rest) = pure ('\r', rest)
parseEscape ('t' : rest) = pure ('\t', rest)
parseEscape ('u' : a : b : c : d : rest)
  | all isHexDigit [a, b, c, d] =
      let code = foldl' (\n x -> n * 16 + hexVal x) 0 [a, b, c, d]
       in pure (chr code, rest)
  | otherwise = Left "Invalid unicode escape"
parseEscape _ = Left "Invalid escape"

hexVal :: Char -> Int
hexVal c
  | c >= '0' && c <= '9' = fromEnum c - fromEnum '0'
  | c >= 'a' && c <= 'f' = 10 + fromEnum c - fromEnum 'a'
  | c >= 'A' && c <= 'F' = 10 + fromEnum c - fromEnum 'A'
  | otherwise = 0

parseNumber :: String -> Either String (JsonValue, String)
parseNumber s =
  let (raw, rest, isFloat) = takeNumber s
   in if null raw
        then Left "Invalid number"
        else
          if isFloat
            then case reads raw :: [(Double, String)] of
              [(n, "")] -> pure (JsonNumber n, rest)
              _ -> Left "Invalid number"
            else case reads raw :: [(Integer, String)] of
              [(n, "")] -> pure (JsonNumber (fromIntegral n), rest)
              _ -> Left "Invalid number"

takeNumber :: String -> (String, String, Bool)
takeNumber s = go s [] False
  where
    go ('-' : rest) acc flag = go rest ('-' : acc) flag
    go (c : rest) acc flag
      | isDigit c = go rest (c : acc) flag
    go ('.' : rest) acc _ =
      let (digits, rest', _) = takeDigits rest
       in continueExp ('.' : digits ++ acc) rest' True
    go rest acc flag = continueExp acc rest flag

    continueExp acc ('e' : rest) _ = takeExp ('e' : acc) rest True
    continueExp acc ('E' : rest) _ = takeExp ('E' : acc) rest True
    continueExp acc rest flag = (reverse acc, rest, flag)

    takeExp acc ('+' : rest) flag = takeExpDigits ('+' : acc) rest flag
    takeExp acc ('-' : rest) flag = takeExpDigits ('-' : acc) rest flag
    takeExp acc rest flag = takeExpDigits acc rest flag

    takeExpDigits acc rest flag =
      let (digits, rest', _) = takeDigits rest
       in (reverse (digits ++ acc), rest', flag)

    takeDigits xs =
      let (d, r) = span isDigit xs
       in (reverse d, r, False)
