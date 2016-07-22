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

def new-cell a:address:cell, b:address:cell -> result:address:cell [
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

def is-cell? x:address:cell -> result:boolean [
  local-scope
  load-ingredients
  reply-unless x, 0/false
  _, result <- maybe-convert *x, pair:variant
]

scenario atom-operations [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  10:boolean/raw <- is-atom? x
  memory-should-contain [
    10 <- 1
  ]
]
