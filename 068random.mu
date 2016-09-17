def random generator:address:stream:num -> result:num, fail?:bool, generator:address:stream:num [
  local-scope
  load-ingredients
  {
    break-if generator
    # generator is 0? use real random-number generator
    result <- real-random
    reply result, 0/false
  }
  result, fail?, generator <- read generator
]

# helper for tests
def assume-random-numbers -> result:address:stream:num [
  local-scope
  load-ingredients
  # compute result-len, space to allocate in result
  result-len:num <- copy 0
  {
    _, arg-received?:bool <- next-ingredient
    break-unless arg-received?
    result-len <- add result-len, 1
    loop
  }
  rewind-ingredients
  result-data:address:array:num <- new number:type, result-len
  idx:num <- copy 0
  {
    curr:num, arg-received?:bool <- next-ingredient
    break-unless arg-received?
    *result-data <- put-index *result-data, idx, curr
    idx <- add idx, 1
    loop
  }
  result <- new-stream result-data
]

scenario random-numbers-in-scenario [
  local-scope
  source:address:stream:num <- assume-random-numbers 34, 35, 37
  1:num/raw, 2:bool/raw <- random source
  3:num/raw, 4:bool/raw <- random source
  5:num/raw, 6:bool/raw <- random source
  7:num/raw, 8:bool/raw <- random source
  memory-should-contain [
    1 <- 34
    2 <- 0  # everything went well
    3 <- 35
    4 <- 0  # everything went well
    5 <- 37
    6 <- 0  # everything went well
    7 <- 0  # empty result
    8 <- 1  # end of stream
  ]
]
