# new type to help incrementally read texts (arrays of characters)
container stream [
  index:number
  data:address:array:character
]

recipe new-stream s:address:array:character -> result:address:stream [
  local-scope
  load-ingredients
  result <- new stream:type
  i:address:number <- get-address *result, index:offset
  *i <- copy 0
  d:address:address:array:character <- get-address *result, data:offset
  *d <- copy s
]

recipe rewind-stream in:address:stream -> in:address:stream [
  local-scope
  load-ingredients
  x:address:number <- get-address *in, index:offset
  *x <- copy 0
]

recipe read-line in:address:stream -> result:address:array:character, in:address:stream [
  local-scope
  load-ingredients
  idx:address:number <- get-address *in, index:offset
  s:address:array:character <- get *in, data:offset
  next-idx:number <- find-next s, 10/newline, *idx
  result <- copy-range s, *idx, next-idx
  *idx <- add next-idx, 1  # skip newline
]

recipe end-of-stream? in:address:stream -> result:boolean [
  local-scope
  load-ingredients
  idx:number <- get *in, index:offset
  s:address:array:character <- get *in, data:offset
  len:number <- length *s
  result <- greater-or-equal idx, len
]
