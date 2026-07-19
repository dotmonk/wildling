WILDLING_LIB_DIR <- normalizePath(
  Sys.getenv("WILDLING_LIB_DIR", unset = file.path(dirname(sys.frames()[[1]]$ofile %||% "."), "..")),
  mustWork = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

load_wildling_module <- function(name) {
  path <- file.path(WILDLING_LIB_DIR, "wildling", paste0(name, ".R"))
  if (!file.exists(path)) {
    path <- file.path(dirname(WILDLING_LIB_DIR), "lib", "wildling", paste0(name, ".R"))
  }
  sys.source(path, envir = globalenv())
}

if (!exists("create_token", mode = "function")) {
  WILDLING_LIB_DIR <- normalizePath(file.path(getwd(), "lib"), mustWork = FALSE)
  if (file.exists(file.path(WILDLING_LIB_DIR, "wildling", "token.R"))) {
    load_wildling_module("token")
    load_wildling_module("parse_pattern")
    load_wildling_module("generator")
    load_wildling_module("wildling")
    load_wildling_module("json")
    load_wildling_module("cli")
  }
}
