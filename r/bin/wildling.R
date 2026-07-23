#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
this_file <- if (length(file_arg) > 0L) {
  sub("^--file=", "", file_arg[[1]])
} else {
  "bin/wildling.R"
}

root <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
Sys.setenv(WILDLING_ROOT = root)

for (name in c("token", "parse_pattern", "generator", "wildling", "json", "cli")) {
  source(file.path(root, "R", paste0(name, ".R")), local = FALSE)
}

cli_main()
