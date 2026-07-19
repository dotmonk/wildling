default_integer <- function(option, fallback) {
  if (!is.null(option) && is.numeric(option) && option >= 0 &&
      option == as.integer(option)) {
    as.integer(option)
  } else {
    as.integer(fallback)
  }
}

create_token <- function(options) {
  src <- if (is.null(options$src)) "" else options$src
  start_length <- default_integer(options$startLength, 1L)
  end_length <- default_integer(options$endLength, 1L)
  variants <- if (is.null(options$variants)) character(0) else options$variants

  count_val <- 0L
  variant_count <- length(variants)
  if (variant_count > 0L) {
    for (length in start_length:end_length) {
      count_val <- count_val + variant_count^length
    }
  }

  list(
    src = src,
    count = function() count_val,
    get = function(index) {
      if (index > count_val - 1L || index < 0L) {
        return("")
      }
      if (index == 0L && start_length == 0L) {
        return("")
      }

      index_with_offset <- as.integer(index)
      string_length <- start_length
      for (length in start_length:end_length) {
        string_length <- length
        offset_count <- variant_count^length
        if (index_with_offset < offset_count) {
          break
        }
        index_with_offset <- index_with_offset - offset_count
      }

      parts <- character(string_length)
      for (i in seq_len(string_length)) {
        variant_index <- index_with_offset %% variant_count
        index_with_offset <- index_with_offset %/% variant_count
        parts[i] <- variants[variant_index + 1L]
      }
      paste0(parts, collapse = "")
    }
  )
}
