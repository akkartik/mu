scenario convert-dataflow [
  run [
    local-scope
    1:address:array:character/raw <- lambda-to-mu [(add a (multiply b c))]
    2:array:character/raw <- copy *1:address:array:character/raw
  ]
  memory-should-contain [
    2:array:character <- [t1 <- multiply b c
result <- add a t1]
  ]
]

def lambda-to-mu in:address:array:character -> out:address:array:character [
  local-scope
  load-ingredients
  out <- copy 0
  tmp:address:cell <- parse in
  out <- to-mu tmp
]

exclusive-container cell [
  atom:address:array:character
  pair:pair
]

container pair [
  first:address:cell
  rest:address:cell
]

def new-atom name:address:array:character -> result:address:cell [
  local-scope
  load-ingredients
  result <- new cell:type
  *result <- merge 0/tag:atom, name
]

def new-pair a:address:cell, b:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  result <- new cell:type
  *result <- merge 1/tag:pair, a/first, b/rest
]

def is-atom? x:address:cell -> result:boolean [
  local-scope
  load-ingredients
  reply-unless x, 0/false
  _, result <- maybe-convert *x, atom:variant
]

def is-pair? x:address:cell -> result:boolean [
  local-scope
  load-ingredients
  reply-unless x, 0/false
  _, result <- maybe-convert *x, pair:variant
]

scenario atom-is-not-pair [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  10:boolean/raw <- is-atom? x
  11:boolean/raw <- is-pair? x
  memory-should-contain [
    10 <- 1
    11 <- 0
  ]
]

scenario pair-is-not-atom [
  local-scope
  # construct (a . nil)
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  y:address:cell <- new-pair x, 0/nil
  10:boolean/raw <- is-atom? y
  11:boolean/raw <- is-pair? y
  memory-should-contain [
    10 <- 0
    11 <- 1
  ]
]

def first x:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  pair:pair, pair?:boolean <- maybe-convert *x, pair:variant
  reply-unless pair?, 0/nil
  result <- get pair, first:offset
]

def rest x:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  pair:pair, pair?:boolean <- maybe-convert *x, pair:variant
  reply-unless pair?, 0/nil
  result <- get pair, rest:offset
]

scenario cell-operations-on-atom [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  10:address:cell/raw <- first x
  11:address:cell/raw <- rest x
  memory-should-contain [
    10 <- 0  # first is nil
    11 <- 0  # rest is nil
  ]
]

scenario cell-operations-on-pair [
  local-scope
  # construct (a . nil)
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  y:address:cell <- new-pair x, 0/nil
  x2:address:cell <- first y
  10:boolean/raw <- equal x, x2
  11:address:cell/raw <- rest y
  memory-should-contain [
    10 <- 1  # first is correct
    11 <- 0  # rest is nil
  ]
]

def parse in:address:array:character -> out:address:cell [
  local-scope
  load-ingredients
  s:address:stream <- new-stream in
  out, s <- parse s
]

def parse in:address:stream -> out:address:cell, in:address:stream [
  local-scope
  load-ingredients
  b:address:buffer <- new-buffer 30
  {
    done?:boolean <- end-of-stream? in
    break-if done?
    c:character, in <- read in
    b <- append b, c
    loop
  }
  s:address:array:character <- buffer-to-array b
  out <- new-atom s
]

scenario parse-single-letter-atom [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- parse s
  s2:address:array:character, 10:boolean/raw <- maybe-convert *x, atom:variant
  11:array:character/raw <- copy *s2
  memory-should-contain [
    10 <- 1  # parse result is an atom
    11:array:character <- [a]
  ]
]

scenario parse-atom [
  local-scope
  s:address:array:character <- new [abc]
  x:address:cell <- parse s
  s2:address:array:character, 10:boolean/raw <- maybe-convert *x, atom:variant
  11:array:character/raw <- copy *s2
  memory-should-contain [
    10 <- 1  # parse result is an atom
    11:array:character <- [abc]
  ]
]
