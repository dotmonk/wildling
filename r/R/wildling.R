WILDLING_VERSION <- "2.0.4"

create_wildling <- function(patterns, dictionaries = NULL) {
  if (is.null(dictionaries)) {
    dictionaries <- list()
  }

  generators <- lapply(patterns, function(pattern) {
    create_generator(pattern, dictionaries)
  })

  pattern_count <- 0L
  for (gen in generators) {
    pattern_count <- pattern_count + gen$count()
  }

  state <- new.env(parent = emptyenv())
  state$internal_index <- 0L

  get_fn <- function(index) {
    if (index > pattern_count - 1L || index < 0L) {
      return(FALSE)
    }

    segment_index <- 0L
    for (gen in generators) {
      pattern_index <- index - segment_index
      gen_count <- gen$count()
      if (pattern_index < gen_count) {
        return(gen$get(pattern_index))
      }
      segment_index <- segment_index + gen_count
    }
    FALSE
  }

  list(
    index = function() state$internal_index,
    count = function() pattern_count,
    reset = function() {
      state$internal_index <- 0L
    },
    `next` = function() {
      if (state$internal_index == pattern_count) {
        return(FALSE)
      }
      state$internal_index <- state$internal_index + 1L
      get_fn(state$internal_index - 1L)
    },
    generators = function() generators,
    get = get_fn
  )
}

createWildling <- create_wildling
