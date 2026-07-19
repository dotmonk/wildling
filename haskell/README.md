# wildling (Haskell)

Haskell library and CLI for pattern-based string generation. **Zero Cabal/Hackage third-party packages** (GHC boot libraries only; hand-rolled JSON for templates). Targets GHC 9.0+.

## Install

From this repository:

```bash
cd haskell
./build.sh
./bin/wildling "foo#"
```

Produces `dist/wildling` plus `dist/help.txt`.

```haskell
import qualified Data.Map.Strict as Map
import Wildling (createWildling, wildlingNext, WildlingResult(..))

main :: IO ()
main = do
  w <- createWildling ["foo#"] Map.empty
  let loop = do
        value <- wildlingNext w
        case value of
          WildlingFalse -> pure ()
          WildlingString s -> putStrLn s >> loop
  loop
```

## CLI

```bash
./bin/wildling "foo#"
./bin/wildling --dictionary planets:../dictionaries/planets.txt "%{'planets'}"
./bin/wildling --template ./config.json
```

Help text and `--check` output follow [`docs/cli.md`](../docs/cli.md) / [`docs/help.txt`](../docs/help.txt). Out-of-range `--select` / `--range` write `out of range: <index>` on stderr and exit `1`.

## Build

```bash
./build.sh   # Docker (gcc:14-bookworm): fetch GHC into .ghc (or apt fallback), ghc → dist/wildling
```

Project tests live in `../tests/` and are run with `../test.sh`.
