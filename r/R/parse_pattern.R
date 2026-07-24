SPECIAL_CHARS <- c("#", "@", "$", "*", "&", "?", "!", "-", "%")

is_special <- function(c) {
  c %in% SPECIAL_CHARS
}

chars_as_variants <- function(s) {
  if (nchar(s) == 0L) {
    return(character(0))
  }
  strsplit(s, "", fixed = TRUE)[[1]]
}

split_keeping_delimiters <- function(input) {
  if (nchar(input) == 0L) {
    return(character(0))
  }

  parts <- character(0)
  i <- 1L
  literal_start <- 1L
  len <- nchar(input)

  while (i <= len) {
    c <- substr(input, i, i)

    if (c == "\\" && i + 1L <= len && is_special(substr(input, i + 1L, i + 1L))) {
      if (i > literal_start) {
        parts <- c(parts, substr(input, literal_start, i - 1L))
      }
      parts <- c(parts, substr(input, i, i + 1L))
      i <- i + 2L
      literal_start <- i
    } else if (is_special(c) && i + 1L <= len && substr(input, i + 1L, i + 1L) == "{") {
      if (i > literal_start) {
        parts <- c(parts, substr(input, literal_start, i - 1L))
      }
      j <- i + 2L
      while (j <= len && substr(input, j, j) != "}") {
        j <- j + 1L
      }
      if (j <= len && substr(input, j, j) == "}") {
        parts <- c(parts, substr(input, i, j))
        i <- j + 1L
        literal_start <- i
      } else {
        if (i > literal_start) {
          parts <- c(parts, substr(input, literal_start, i - 1L))
        }
        parts <- c(parts, c)
        i <- i + 1L
        literal_start <- i
      }
    } else if (is_special(c)) {
      if (i > literal_start) {
        parts <- c(parts, substr(input, literal_start, i - 1L))
      }
      parts <- c(parts, c)
      i <- i + 1L
      literal_start <- i
    } else {
      i <- i + 1L
    }
  }

  if (literal_start <= len) {
    parts <- c(parts, substr(input, literal_start, len))
  }

  parts
}

parse_length_with_variants <- function(part, variants) {
  start_length <- 1L
  end_length <- 1L

  open <- regexpr("{", part, fixed = TRUE)[1]
  if (open > 0L) {
    close <- regexpr("}", part, fixed = TRUE)[1]
    if (close > open) {
      inner <- substr(part, open + 1L, close - 1L)
      dash <- regexpr("-", inner, fixed = TRUE)[1]
      if (dash > 0L) {
        s <- suppressWarnings(as.integer(substr(inner, 1L, dash - 1L)))
        e <- suppressWarnings(as.integer(substr(inner, dash + 1L, nchar(inner))))
        if (!is.na(s) && !is.na(e)) {
          start_length <- s
          end_length <- e
        }
      } else {
        n <- suppressWarnings(as.integer(inner))
        if (!is.na(n)) {
          start_length <- n
          end_length <- n
        }
      }
    }
  }

  list(
    variants = variants,
    startLength = start_length,
    endLength = end_length,
    src = part
  )
}

parse_length_with_string <- function(part) {
  open <- regexpr("{'", part, fixed = TRUE)[1]
  if (open <= 0L) {
    return(FALSE)
  }

  after_open <- open + 2L
  rest <- substr(part, after_open, nchar(part))
  close_quote <- 0L
  for (idx in seq(nchar(rest), 1L, by = -1L)) {
    if (substr(rest, idx, idx) == "'") {
      close_quote <- idx
      break
    }
  }
  if (close_quote == 0L) {
    return(FALSE)
  }

  content <- substr(rest, 1L, close_quote - 1L)
  after_quote <- substr(rest, close_quote + 1L, nchar(rest))

  if (!startsWith(after_quote, "}") && !startsWith(after_quote, ",")) {
    if (regexpr("}", after_quote, fixed = TRUE)[1] <= 0L) {
      return(FALSE)
    }
  }

  start_length <- 1L
  end_length <- 1L

  if (startsWith(after_quote, ",")) {
    stripped <- substr(after_quote, 2L, nchar(after_quote))
    if (endsWith(stripped, "}")) {
      stripped <- substr(stripped, 1L, nchar(stripped) - 1L)
    }
    dash <- regexpr("-", stripped, fixed = TRUE)[1]
    if (dash > 0L) {
      s <- suppressWarnings(as.integer(substr(stripped, 1L, dash - 1L)))
      e <- suppressWarnings(as.integer(substr(stripped, dash + 1L, nchar(stripped))))
      if (!is.na(s) && !is.na(e)) {
        start_length <- s
        end_length <- e
      }
    } else {
      n <- suppressWarnings(as.integer(stripped))
      if (!is.na(n)) {
        start_length <- n
        end_length <- n
      }
    }
  } else if (!startsWith(after_quote, "}")) {
    return(FALSE)
  }

  list(
    string = content,
    startLength = start_length,
    endLength = end_length,
    src = part
  )
}

simple_tokenizer <- function(variants_string) {
  variants <- chars_as_variants(variants_string)
  function(part) {
    create_token(parse_length_with_variants(part, variants))
  }
}

dictionary_tokenizer <- function(part, dictionaries) {
  options <- parse_length_with_string(part)
  if (isFALSE(options) ||
      (!is.null(options$string) && options$string != "" &&
       is.null(dictionaries[[options$string]]))) {
    options <- list(
      variants = part,
      startLength = 1L,
      endLength = 1L,
      src = part
    )
  } else {
    key <- if (is.null(options$string)) "" else options$string
    options$variants <- if (is.null(dictionaries[[key]])) character(0) else dictionaries[[key]]
  }
  create_token(options)
}

words_tokenizer <- function(part) {
  options <- parse_length_with_string(part)

  if (isFALSE(options)) {
    options <- list(
      variants = part,
      startLength = 1L,
      endLength = 1L,
      src = part
    )
  } else {
    variants <- character(0)
    work_string <- if (is.null(options$string)) "" else options$string
    index <- 1L
    while (index <= nchar(work_string)) {
      if (substr(work_string, index, index + 1L) == "\\,") {
        index <- index + 2L
      } else if (substr(work_string, index, index) == ",") {
        variants <- c(variants, substr(work_string, 1L, index - 1L))
        work_string <- substr(work_string, index + 1L, nchar(work_string))
        index <- 1L
      } else {
        index <- index + 1L
      }
    }
    variants <- c(variants, work_string)
    options$variants <- gsub("\\,", ",", variants, fixed = TRUE)
  }

  create_token(options)
}

part_to_token <- function(part, dictionaries) {
  tokenizers <- list(
    "#" = simple_tokenizer("0123456789"),
    "@" = simple_tokenizer("abcdefghijklmnopqrstuvwxyz"),
    "*" = simple_tokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
    "-" = simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
    "!" = simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    "?" = simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
    "&" = simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    "%" = function(p) dictionary_tokenizer(p, dictionaries),
    "$" = words_tokenizer
  )

  first <- if (nchar(part) > 0L) substr(part, 1L, 1L) else ""
  tokenizer <- tokenizers[[first]]
  is_escaped <- nchar(part) > 1L &&
    substr(part, 1L, 1L) == "\\" &&
    !is.null(tokenizers[[substr(part, 2L, 2L)]])

  if (!is.null(tokenizer)) {
    return(tokenizer(part))
  }
  if (is_escaped) {
    return(create_token(list(
      variants = substr(part, 2L, nchar(part)),
      src = part
    )))
  }
  create_token(list(
    variants = part,
    src = part
  ))
}

parse_pattern <- function(input_pattern, dictionaries = list()) {
  if (is.null(dictionaries)) {
    dictionaries <- list()
  }
  parts <- split_keeping_delimiters(input_pattern)
  tokens <- lapply(parts[parts != ""], function(part) part_to_token(part, dictionaries))
  tokens
}
