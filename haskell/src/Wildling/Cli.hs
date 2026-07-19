module Wildling.Cli
  ( runCli
  ) where

import Control.Exception (IOException, try)
import Control.Monad (foldM, when)
import Data.Char (isDigit)
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import System.Directory (doesFileExist)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode(..), exitWith)
import System.FilePath ((</>), takeDirectory)
import System.IO (hPutStrLn, stderr)

import Wildling
  ( WildlingResult(..)
  , createWildling
  , version
  , wildlingCount
  , wildlingGenerators
  , wildlingGet
  , wildlingNext
  )
import Wildling.Generator (Generator, generatorCount, generatorSource)
import Wildling.Json (JsonValue(..), parseJson)
import Wildling.ParsePattern (Dictionaries)

data Range = Range
  { rangeStart :: Int
  , rangeEnd :: Int
  }

data CliArgs = CliArgs
  { cliSelects :: [Int]
  , cliRanges :: [Range]
  , cliCheck :: Bool
  , cliDictionaries :: Dictionaries
  , cliDictOrder :: [String]
  , cliPatterns :: [String]
  , cliHelp :: Bool
  , cliVersion :: Bool
  }

emptyArgs :: CliArgs
emptyArgs =
  CliArgs
    { cliSelects = []
    , cliRanges = []
    , cliCheck = False
    , cliDictionaries = Map.empty
    , cliDictOrder = []
    , cliPatterns = []
    , cliHelp = False
    , cliVersion = False
    }

parseRange :: String -> Maybe Range
parseRange value =
  case break (== '-') value of
    (left, '-' : right)
      | allDigit left && allDigit right && not (null left) && not (null right) ->
          let start = read left
              end = read right
           in if start <= end then Just (Range start end) else Nothing
    _ -> Nothing

allDigit :: String -> Bool
allDigit s = not (null s) && all isDigit s

loadDictionaryFile :: FilePath -> IO (Maybe [String])
loadDictionaryFile path = do
  result <- try (readFile path) :: IO (Either IOException String)
  case result of
    Left _ -> pure Nothing
    Right content ->
      let words_ =
            filter (not . null)
              . map trim
              . lines
              $ content
       in pure (Just words_)

trim :: String -> String
trim = dropWhile isSpaceChar . reverse . dropWhile isSpaceChar . reverse
  where
    isSpaceChar c = c == ' ' || c == '\t' || c == '\r'

applyDictionaryPath :: CliArgs -> String -> FilePath -> IO CliArgs
applyDictionaryPath result name path = do
  exists <- doesFileExist path
  if not exists
    then pure result
    else do
      loaded <- loadDictionaryFile path
      case loaded of
        Nothing -> pure result
        Just words_ -> pure (insertDictionary result name words_)

insertDictionary :: CliArgs -> String -> [String] -> CliArgs
insertDictionary result name words_ =
  result
    { cliDictionaries = Map.insert name words_ (cliDictionaries result)
    , cliDictOrder =
        if name `elem` cliDictOrder result
          then cliDictOrder result
          else cliDictOrder result ++ [name]
    }

jsonToString :: JsonValue -> Maybe String
jsonToString (JsonString s) = Just s
jsonToString (JsonNumber n) =
  let asInt = round n :: Integer
   in if fromIntegral asInt == n
        then Just (show asInt)
        else Just (show n)
jsonToString (JsonBool True) = Just "true"
jsonToString (JsonBool False) = Just "false"
jsonToString _ = Nothing

applyDictionaryValue :: CliArgs -> String -> JsonValue -> IO CliArgs
applyDictionaryValue result name (JsonArray items) =
  let words_ = [s | item <- items, Just s <- [jsonToString item], not (null s)]
   in pure (insertDictionary result name words_)
applyDictionaryValue result name (JsonString path) = do
  exists <- doesFileExist path
  if not exists
    then pure result
    else do
      loaded <- loadDictionaryFile path
      case loaded of
        Nothing -> pure result
        Just words_ -> pure (insertDictionary result name words_)
applyDictionaryValue result _ _ = pure result

die :: String -> IO a
die msg = hPutStrLn stderr msg >> exitWith (ExitFailure 1)

applyTemplate :: CliArgs -> FilePath -> IO CliArgs
applyTemplate result path = do
  exists <- doesFileExist path
  when (not exists) $ die ("Template file not found: " ++ path)
  contentResult <- try (readFile path) :: IO (Either IOException String)
  content <- case contentResult of
    Left _ -> die ("Invalid JSON template: " ++ path)
    Right c -> pure c
  case parseJson content of
    Left _ -> die ("Invalid JSON template: " ++ path)
    Right (JsonObject obj) -> foldM applyField result obj
    Right _ -> die ("Invalid JSON template: " ++ path)
  where
    applyField acc ("check", JsonBool True) =
      pure acc {cliCheck = True}
    applyField acc ("select", JsonArray vals) =
      pure
        acc
          { cliSelects =
              cliSelects acc
                ++ [n | Just n <- map jsonToInt vals, n >= 0]
          }
    applyField acc ("range", JsonArray vals) =
      pure
        acc
          { cliRanges =
              cliRanges acc
                ++ [r | JsonString s <- vals, Just r <- [parseRange s]]
          }
    applyField acc ("dictionaries", JsonObject dicts) =
      foldM (\a (k, v) -> applyDictionaryValue a k v) acc dicts
    applyField acc ("patterns", JsonArray vals) =
      pure
        acc
          { cliPatterns =
              cliPatterns acc
                ++ [s | JsonString s <- vals]
          }
    applyField acc _ = pure acc

jsonToInt :: JsonValue -> Maybe Int
jsonToInt (JsonNumber n) = Just (round n)
jsonToInt (JsonString s) =
  case reads s of
    [(n, "")] -> Just n
    _ -> Nothing
jsonToInt _ = Nothing

parseArgs :: [String] -> IO CliArgs
parseArgs = go emptyArgs
  where
    go result [] = pure result
    go result (arg : rest)
      | arg == "--help" || arg == "-h" =
          go result {cliHelp = True} rest
      | arg == "--version" || arg == "-v" =
          go result {cliVersion = True} rest
      | arg == "--check" =
          go result {cliCheck = True} rest
      | arg == "--select" =
          case rest of
            [] -> pure result
            (val : rest') ->
              let n = case reads val of
                    [(i, "")] -> i
                    _ -> -1
                  result' =
                    if n >= 0
                      then result {cliSelects = cliSelects result ++ [n]}
                      else result
               in go result' rest'
      | arg == "--range" =
          case rest of
            [] -> pure result
            (val : rest') ->
              let result' = case parseRange val of
                    Just r -> result {cliRanges = cliRanges result ++ [r]}
                    Nothing -> result
               in go result' rest'
      | arg == "--dictionary" =
          case rest of
            [] -> pure result
            (val : rest') ->
              case break (== ':') val of
                (name, ':' : path)
                  | not (null name) && not (null path) -> do
                      result' <- applyDictionaryPath result name path
                      go result' rest'
                _ -> go result rest'
      | arg == "--template" =
          case rest of
            [] -> die "Missing path for --template"
            (path : rest') -> do
              result' <- applyTemplate result path
              go result' rest'
      | otherwise =
          go result {cliPatterns = cliPatterns result ++ [arg]} rest

loadHelpText :: IO String
loadHelpText = do
  exe <- try getExecutablePath :: IO (Either IOException FilePath)
  let exeCandidates = case exe of
        Right path ->
          let dir = takeDirectory path
           in [ dir </> "help.txt"
              , dir </> ".." </> "docs" </> "help.txt"
              ]
        Left _ -> []
  let candidates =
        exeCandidates
          ++ [ "docs/help.txt"
             , "haskell/dist/help.txt"
             ]
  findFirst candidates
  where
    findFirst [] =
      pure "wildling - pattern based string generator\n\nHelp text unavailable.\n"
    findFirst (p : ps) = do
      exists <- doesFileExist p
      if exists
        then readFile p
        else findFirst ps

formatList :: [String] -> String
formatList [] = ""
formatList xs = ' ' : intercalate " " xs

formatCheckOutput :: CliArgs -> Int -> [Generator] -> String
formatCheckOutput args total generators =
  let dictNames = cliDictOrder args
      selects = map show (cliSelects args)
      ranges =
        [ show (rangeStart r) ++ "-" ++ show (rangeEnd r)
        | r <- cliRanges args
        ]
      lines_ =
        [ "patterns:" ++ formatList (cliPatterns args)
        , "dictionaries:" ++ formatList dictNames
        , "select:" ++ formatList selects
        , "range:" ++ formatList ranges
        , "total: " ++ show total
        ]
          ++ [ "generator: " ++ generatorSource g ++ " " ++ show (generatorCount g)
             | g <- generators
             ]
   in intercalate "\n" lines_

printResult :: WildlingResult -> IO ()
printResult (WildlingString s) = putStrLn s
printResult WildlingFalse = putStrLn "false"

runCli :: [String] -> IO ()
runCli argv = do
  args <- parseArgs argv

  when (cliHelp args) $ do
    help <- loadHelpText
    putStrLn (rstrip help)
    exitWith ExitSuccess

  when (cliVersion args) $ do
    putStrLn ("wildling " ++ version)
    exitWith ExitSuccess

  when (null (cliPatterns args)) $
    die "No pattern provided. Use --help for usage information."

  wildcard <- createWildling (cliPatterns args) (cliDictionaries args)

  when (cliCheck args) $ do
    putStrLn
      ( formatCheckOutput
          args
          (wildlingCount wildcard)
          (wildlingGenerators wildcard)
      )
    exitWith ExitSuccess

  if not (null (cliSelects args)) || not (null (cliRanges args))
    then do
      mapM_ (printResult . wildlingGet wildcard) (cliSelects args)
      mapM_
        ( \r ->
            mapM_
              (printResult . wildlingGet wildcard)
              [rangeStart r .. rangeEnd r]
        )
        (cliRanges args)
      exitWith ExitSuccess
    else do
      let loop = do
            value <- wildlingNext wildcard
            case value of
              WildlingFalse -> pure ()
              WildlingString s -> putStrLn s >> loop
      loop
      exitWith ExitSuccess

rstrip :: String -> String
rstrip = reverse . dropWhile (`elem` (" \t\r\n" :: String)) . reverse
