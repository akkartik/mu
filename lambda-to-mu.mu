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

container cell [
  first:address:cell-value
  rest:address:cell
]

exclusive-container cell-value [
  atom:address:array:character
  cell:address:cell
]

def new-atom name:address:array:character -> result:address:cell [
  local-scope
  load-ingredients
  cv:address:cell-value <- new cell-value:type
  *cv <- merge 0/tag:atom, name
  result <- new cell:type
  *result <- merge cv, 0/rest
]

def new-cell a:address:cell, b:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  cv:address:cell-value <- new cell-value:type
  *cv <- merge 1/tag:cell, a
  result <- new cell:type
  *result <- merge cv/first, b/rest
]

def is-atom? x:address:cell -> result:boolean [
  reply-unless x, 0/false
  cv:address:cell-value <- get *x, first:offset
  reply-unless cv, 0/false
  _, result <- maybe-convert *cv, atom:variant
]

def is-cell? x:address:cell -> result:boolean [
  reply-unless x, 0/false
  cv:address:cell-value <- get *x, first:offset
  reply-unless cv, 0/false
  _, result <- maybe-convert *cv, atom:variant
]

def lambda-to-mu in:address:array:character -> out:address:array:character [
  local-scope
  load-ingredients
  tmp <- parse in
  out <- to-mu tmp
]
