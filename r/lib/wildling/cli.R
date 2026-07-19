new_cli_args <- function() {
  list(
    selects = integer(0),
    ranges = list(),
    check = FALSE,
    dictionaries = list(),
    patterns = character(0),
    help = FALSE,
    version = FALSE
  )
}

parse_range <- function(value) {
  parts <- strsplit(value, "-", fixed = TRUE)[[1]]
  if (length(parts) != 2L) {
    return(NULL)
  }
  if (!grepl("^[0-9]+$", parts[[1]]) || !grepl("^[0-9]+$", parts[[2]])) {
    return(NULL)
  }
  start <- as.integer(parts[[1]])
  end <- as.integer(parts[[2]])
  if (start <= end) {
    c(start, end)
  } else {
    NULL
  }
}

load_dictionary_file <- function(path) {
  content <- readLines(path, warn = FALSE, encoding = "UTF-8")
  trimmed <- trimws(content)
  trimmed[nchar(trimmed) > 0L]
}

apply_dictionary <- function(result, name, value) {
  if (is.list(value) && is.null(names(value))) {
    result$dictionaries[[name]] <- as.character(value)
    return(result)
  }
  if (is.character(value) && length(value) == 1L && file.exists(value)) {
    words <- tryCatch(
      load_dictionary_file(value),
      error = function(e) NULL
    )
    if (!is.null(words)) {
      result$dictionaries[[name]] <- words
    }
  }
  result
}

apply_template <- function(result, path) {
  if (!file.exists(path)) {
    cat("Template file not found: ", path, "\n", sep = "", file = stderr())
    quit(save = "no", status = 1)
  }

  template <- tryCatch(
    json_parse_object(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")),
    error = function(e) NULL
  )

  if (is.null(template)) {
    cat("Invalid JSON template: ", path, "\n", sep = "", file = stderr())
    quit(save = "no", status = 1)
  }

  if (isTRUE(template$check)) {
    result$check <- TRUE
  }

  select <- template$select
  if (is.list(select)) {
    for (val in select) {
      number <- suppressWarnings(as.integer(val))
      if (!is.na(number) && number >= 0L) {
        result$selects <- c(result$selects, number)
      }
    }
  }

  ranges <- template$range
  if (is.list(ranges)) {
    for (range_str in ranges) {
      parsed <- parse_range(as.character(range_str))
      if (!is.null(parsed)) {
        result$ranges[[length(result$ranges) + 1L]] <- parsed
      }
    }
  }

  dictionaries <- template$dictionaries
  if (is.list(dictionaries) && !is.null(names(dictionaries))) {
    for (name in names(dictionaries)) {
      value <- dictionaries[[name]]
      if (is.character(value) || (is.list(value) && is.null(names(value)))) {
        result <- apply_dictionary(result, name, value)
      }
    }
  }

  patterns <- template$patterns
  if (is.list(patterns)) {
    for (pattern in patterns) {
      result$patterns <- c(result$patterns, as.character(pattern))
    }
  }

  result
}

parse_args <- function(args) {
  result <- new_cli_args()
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]

    if (arg %in% c("--help", "-h")) {
      result$help <- TRUE
      i <- i + 1L
      next
    }

    if (arg %in% c("--version", "-v")) {
      result$version <- TRUE
      i <- i + 1L
      next
    }

    if (arg == "--check") {
      result$check <- TRUE
      i <- i + 1L
      next
    }

    if (arg == "--select") {
      i <- i + 1L
      if (i > length(args)) {
        break
      }
      val <- suppressWarnings(as.integer(args[[i]]))
      if (!is.na(val) && val >= 0L) {
        result$selects <- c(result$selects, val)
      }
      i <- i + 1L
      next
    }

    if (arg == "--range") {
      i <- i + 1L
      if (i > length(args)) {
        break
      }
      parsed <- parse_range(args[[i]])
      if (!is.null(parsed)) {
        result$ranges[[length(result$ranges) + 1L]] <- parsed
      }
      i <- i + 1L
      next
    }

    if (arg == "--dictionary") {
      i <- i + 1L
      if (i > length(args)) {
        break
      }
      spec <- args[[i]]
      colon <- regexpr(":", spec, fixed = TRUE)[1]
      if (colon > 1L && colon < nchar(spec)) {
        name <- substr(spec, 1L, colon - 1L)
        path <- substr(spec, colon + 1L, nchar(spec))
        result <- apply_dictionary(result, name, path)
      }
      i <- i + 1L
      next
    }

    if (arg == "--template") {
      i <- i + 1L
      if (i > length(args)) {
        cat("Missing path for --template\n", file = stderr())
        quit(save = "no", status = 1)
      }
      result <- apply_template(result, args[[i]])
      i <- i + 1L
      next
    }

    result$patterns <- c(result$patterns, arg)
    i <- i + 1L
  }

  result
}

load_help_text <- function() {
  lib_dir <- Sys.getenv("WILDLING_LIB_DIR", unset = "")
  candidates <- c(
    file.path(lib_dir, "wildling", "help.txt"),
    file.path(lib_dir, "..", "..", "docs", "help.txt")
  )
  for (path in candidates) {
    if (nzchar(path) && file.exists(path)) {
      return(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
    }
  }
  "wildling - pattern based string generator\n\nHelp text unavailable.\n"
}

format_list <- function(values) {
  if (length(values) == 0L) {
    return("")
  }
  paste0(" ", paste(values, collapse = " "))
}

format_check_output <- function(args, total, generators) {
  range_strings <- vapply(args$ranges, function(r) paste0(r[[1]], "-", r[[2]]), character(1))
  lines <- c(
    paste0("patterns:", format_list(args$patterns)),
    paste0("dictionaries:", format_list(names(args$dictionaries))),
    paste0("select:", format_list(args$selects)),
    paste0("range:", format_list(range_strings)),
    paste0("total: ", total)
  )
  for (gen in generators) {
    lines <- c(lines, paste0("generator: ", gen$source, " ", gen$count()))
  }
  paste(lines, collapse = "\n")
}

cli_main <- function(argv = NULL) {
  args <- parse_args(if (is.null(argv)) commandArgs(trailingOnly = TRUE) else argv)

  if (isTRUE(args$help)) {
    cat(trimws(load_help_text(), which = "right"), "\n", sep = "")
    quit(save = "no", status = 0)
  }

  if (isTRUE(args$version)) {
    cat("wildling ", WILDLING_VERSION, "\n", sep = "")
    quit(save = "no", status = 0)
  }

  if (length(args$patterns) == 0L) {
    cat("No pattern provided. Use --help for usage information.\n", file = stderr())
    quit(save = "no", status = 1)
  }

  wildcard <- create_wildling(args$patterns, args$dictionaries)

  if (isTRUE(args$check)) {
    cat(format_check_output(args, wildcard$count(), wildcard$generators()), "\n", sep = "")
    quit(save = "no", status = 0)
  }

  if (length(args$selects) > 0L || length(args$ranges) > 0L) {
    oor <- FALSE
    for (index in args$selects) {
      value <- wildcard$get(index)
      if (isFALSE(value)) {
        cat("out of range: ", index, "\n", sep = "", file = stderr())
        oor <- TRUE
      } else {
        cat(value, "\n", sep = "")
      }
    }
    for (range in args$ranges) {
      for (index in range[[1]]:range[[2]]) {
        value <- wildcard$get(index)
        if (isFALSE(value)) {
          cat("out of range: ", index, "\n", sep = "", file = stderr())
          oor <- TRUE
        } else {
          cat(value, "\n", sep = "")
        }
      }
    }
    quit(save = "no", status = if (oor) 1L else 0L)
  }

  value <- wildcard$`next`()
  while (!isFALSE(value)) {
    cat(value, "\n", sep = "")
    value <- wildcard$`next`()
  }
}
