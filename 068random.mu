def random generator:address:stream:number -> result:number, fail?:boolean, generator:address:stream:number [
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
def assume-random-numbers -> result:address:stream:number [
  local-scope
  load-ingredients
  # compute result-len, space to allocate in result
  result-len:number <- copy 0
  {
    _, arg-received?:boolean <- next-ingredient
    break-unless arg-received?
    result-len <- add result-len, 1
    loop
  }
  rewind-ingredients
  result-data:address:array:number <- new number:type, result-len
  idx:number <- copy 0
  {
    curr:number, arg-received?:boolean <- next-ingredient
    break-unless arg-received?
    *result-data <- put-index *result-data, idx, curr
    idx <- add idx, 1
    loop
  }
  result <- new-stream result-data
]

scenario random-numbers-in-scenario [
  local-scope
  source:address:stream:number <- assume-random-numbers 34, 35, 37
  1:number/raw, 2:boolean/raw <- random source
  3:number/raw, 4:boolean/raw <- random source
  5:number/raw, 6:boolean/raw <- random source
  7:number/raw, 8:boolean/raw <- random source
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
