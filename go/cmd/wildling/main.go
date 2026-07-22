package main

import (
	"os"

	"github.com/dotmonk/wildling/go/v2/wildling"
)

func main() {
	os.Exit(wildling.RunCLI(os.Args[1:]))
}
