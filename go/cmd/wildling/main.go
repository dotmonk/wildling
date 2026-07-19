package main

import (
	"os"

	"github.com/dotmonk/wildling/go/wildling"
)

func main() {
	os.Exit(wildling.RunCLI(os.Args[1:]))
}
