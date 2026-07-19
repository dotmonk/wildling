create_generator <- function(input_pattern, dictionaries) {
  tokens <- parse_pattern(input_pattern, dictionaries)
  count_val <- 1L
  for (token in tokens) {
    count_val <- count_val * token$count()
  }

  list(
    source = input_pattern,
    count = function() count_val,
    tokens = function() tokens,
    get = function(index) {
      if (index > count_val - 1L || index < 0L) {
        return("")
      }

      parts <- character(length(tokens))
      index_with_offset <- as.integer(index)
      for (i in seq_along(tokens)) {
        token <- tokens[[i]]
        token_count <- token$count()
        parts[i] <- token$get(index_with_offset %% token_count)
        index_with_offset <- index_with_offset %/% token_count
      }
      paste0(parts, collapse = "")
    }
  )
}
