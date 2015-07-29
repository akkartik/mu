# new type to help incrementally read strings
container stream [
  index:number
  data:address:array:character
]

recipe new-stream [
  local-scope
  result:address:stream <- new stream:type
  i:address:number <- get-address *result, index:offset
  *i <- copy 0
  d:address:address:array:character <- get-address *result, data:offset
  *d <- next-ingredient
  reply result
]

recipe rewind-stream [
  local-scope
  in:address:stream <- next-ingredient
  x:address:number <- get-address *in, index:offset
  *x <- copy 0
  reply in/same-as-arg:0
]

recipe read-line [
  local-scope
  in:address:stream <- next-ingredient
  idx:address:number <- get-address *in, index:offset
  s:address:array:character <- get *in, data:offset
  next-idx:number <- find-next s, 10/newline, *idx
  result:address:array:character <- string-copy s, *idx, next-idx
  *idx <- add next-idx, 1  # skip newline
  reply result
]

recipe end-of-stream? [
  local-scope
  in:address:stream <- next-ingredient
  idx:address:number <- get *in, index:offset
  s:address:array:character <- get *in, data:offset
  len:number <- length *s
  result:boolean <- greater-or-equal idx, len
  reply result
]
