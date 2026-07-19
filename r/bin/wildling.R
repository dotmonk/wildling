#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
this_file <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[[1]])
} else {
  "bin/wildling.R"
}

root <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
Sys.setenv(WILDLING_LIB_DIR = file.path(root, "lib"))

source(file.path(root, "lib", "wildling", "token.R"), local = FALSE)
source(file.path(root, "lib", "wildling", "parse_pattern.R"), local = FALSE)
source(file.path(root, "lib", "wildling", "generator.R"), local = FALSE)
source(file.path(root, "lib", "wildling", "wildling.R"), local = FALSE)
source(file.path(root, "lib", "wildling", "json.R"), local = FALSE)
source(file.path(root, "lib", "wildling", "cli.R"), local = FALSE)

cli_main()
