def random generator:&:stream:num -> result:num, fail?:bool, generator:&:stream:num [
  local-scope
  load-inputs
  {
    break-if generator
    # generator is 0? use real random-number generator
    result <- real-random
    return result, 0/false
  }
  result, fail?, generator <- read generator
]

# helper for tests
def assume-random-numbers -> result:&:stream:num [
  local-scope
  load-inputs
  # compute result-len, space to allocate in result
  result-len:num <- copy 0
  {
    _, arg-received?:bool <- next-input
    break-unless arg-received?
    result-len <- add result-len, 1
    loop
  }
  rewind-inputs
  result-data:&:@:num <- new number:type, result-len
  idx:num <- copy 0
  {
    curr:num, arg-received?:bool <- next-input
    break-unless arg-received?
    *result-data <- put-index *result-data, idx, curr
    idx <- add idx, 1
    loop
  }
  result <- new-stream result-data
]

scenario random-numbers-in-scenario [
  local-scope
  source:&:stream:num <- assume-random-numbers 34, 35, 37
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

# generate a random integer in the semi-open interval [start, end)
def random-in-range generator:&:stream:num, start:num, end:num -> result:num, fail?:bool, generator:&:stream:num [
  local-scope
  load-inputs
  result, fail?, generator <- random generator
  return-if fail?
  delta:num <- subtract end, start
  _, result <- divide-with-remainder result, delta
  result <- add result, start
]

scenario random-in-range [
  local-scope
  source:&:stream:num <- assume-random-numbers 91
  1:num/raw <- random-in-range source, 40, 50
  memory-should-contain [
    1 <- 41
  ]
]
