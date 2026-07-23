json_parse <- function(text) {
  pos <- 1L
  n <- nchar(text)

  skip_whitespace <- function() {
    while (pos <= n) {
      c <- substr(text, pos, pos)
      if (c %in% c(" ", "\n", "\r", "\t")) {
        pos <<- pos + 1L
      } else {
        return(invisible(NULL))
      }
    }
  }

  peek <- function(expected) {
    pos <= n && substr(text, pos, pos) == expected
  }

  expect <- function(expected) {
    skip_whitespace()
    if (!peek(expected)) {
      stop("Expected '", expected, "' at ", pos, call. = FALSE)
    }
    pos <<- pos + 1L
  }

  parse_string <- function() {
    expect('"')
    parts <- character(0)
    while (pos <= n) {
      c <- substr(text, pos, pos)
      pos <<- pos + 1L
      if (c == '"') {
        return(paste0(parts, collapse = ""))
      }
      if (c == "\\") {
        if (pos > n) {
          stop("Unterminated escape", call. = FALSE)
        }
        esc <- substr(text, pos, pos)
        pos <<- pos + 1L
        parts <- c(
          parts,
          switch(esc,
            '"' = '"',
            "\\" = "\\",
            "/" = "/",
            "b" = "\b",
            "f" = "\f",
            "n" = "\n",
            "r" = "\r",
            "t" = "\t",
            "u" = {
              if (pos + 3L > n) {
                stop("Invalid unicode escape", call. = FALSE)
              }
              code <- substr(text, pos, pos + 3L)
              pos <<- pos + 4L
              int_val <- strtoi(paste0("0x", code), base = 16L)
              if (is.na(int_val)) {
                stop("Invalid unicode escape", call. = FALSE)
              }
              intToUtf8(int_val)
            },
            stop("Invalid escape \\", esc, call. = FALSE)
          )
        )
      } else {
        parts <- c(parts, c)
      }
    }
    stop("Unterminated string", call. = FALSE)
  }

  parse_number <- function() {
    start <- pos
    if (peek("-")) {
      pos <<- pos + 1L
    }
    while (pos <= n && grepl("[0-9]", substr(text, pos, pos))) {
      pos <<- pos + 1L
    }
    is_double <- FALSE
    if (peek(".")) {
      is_double <- TRUE
      pos <<- pos + 1L
      while (pos <= n && grepl("[0-9]", substr(text, pos, pos))) {
        pos <<- pos + 1L
      }
    }
    if (pos <= n) {
      c <- substr(text, pos, pos)
      if (c %in% c("e", "E")) {
        is_double <- TRUE
        pos <<- pos + 1L
        if (peek("+") || peek("-")) {
          pos <<- pos + 1L
        }
        while (pos <= n && grepl("[0-9]", substr(text, pos, pos))) {
          pos <<- pos + 1L
        }
      }
    }
    raw <- substr(text, start, pos - 1L)
    if (is_double) {
      as.numeric(raw)
    } else {
      as.numeric(raw)
    }
  }

  parse_boolean <- function() {
    if (substr(text, pos, pos + 3L) == "true") {
      pos <<- pos + 4L
      return(TRUE)
    }
    if (substr(text, pos, pos + 4L) == "false") {
      pos <<- pos + 5L
      return(FALSE)
    }
    stop("Invalid boolean at ", pos, call. = FALSE)
  }

  parse_null <- function() {
    if (substr(text, pos, pos + 3L) == "null") {
      pos <<- pos + 4L
      return(NULL)
    }
    stop("Invalid null at ", pos, call. = FALSE)
  }

  parse_array <- function() {
    expect("[")
    array <- list()
    skip_whitespace()
    if (peek("]")) {
      pos <<- pos + 1L
      return(array)
    }
    repeat {
      array[[length(array) + 1L]] <- parse_value()
      skip_whitespace()
      if (peek("]")) {
        pos <<- pos + 1L
        return(array)
      }
      expect(",")
    }
  }

  parse_object <- function() {
    expect("{")
    obj <- list()
    skip_whitespace()
    if (peek("}")) {
      pos <<- pos + 1L
      return(obj)
    }
    repeat {
      skip_whitespace()
      key <- parse_string()
      skip_whitespace()
      expect(":")
      obj[[key]] <- parse_value()
      skip_whitespace()
      if (peek("}")) {
        pos <<- pos + 1L
        return(obj)
      }
      expect(",")
    }
  }

  parse_value <- function() {
    skip_whitespace()
    if (pos > n) {
      stop("Unexpected end of JSON", call. = FALSE)
    }
    c <- substr(text, pos, pos)
    if (c == "{") {
      return(parse_object())
    }
    if (c == "[") {
      return(parse_array())
    }
    if (c == '"') {
      return(parse_string())
    }
    if (c %in% c("t", "f")) {
      return(parse_boolean())
    }
    if (c == "n") {
      return(parse_null())
    }
    if (c == "-" || grepl("[0-9]", c)) {
      return(parse_number())
    }
    stop("Unexpected character at ", pos, call. = FALSE)
  }

  value <- parse_value()
  skip_whitespace()
  if (pos != n + 1L) {
    stop("Unexpected trailing JSON content", call. = FALSE)
  }
  value
}

json_parse_object <- function(text) {
  value <- json_parse(text)
  if (!is.list(value) || is.null(names(value))) {
    stop("Template root must be a JSON object", call. = FALSE)
  }
  value
}
