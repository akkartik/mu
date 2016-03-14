# new type to help incrementally read texts (arrays of characters)
container stream [
  index:number
  data:address:shared:array:character
]

def new-stream s:address:shared:array:character -> result:address:shared:stream [
  local-scope
  load-ingredients
  result <- new stream:type
  i:address:number <- get-address *result, index:offset
  *i <- copy 0
  d:address:address:shared:array:character <- get-address *result, data:offset
  *d <- copy s
]

def rewind-stream in:address:shared:stream -> in:address:shared:stream [
  local-scope
  load-ingredients
  x:address:number <- get-address *in, index:offset
  *x <- copy 0
]

def read-line in:address:shared:stream -> result:address:shared:array:character, in:address:shared:stream [
  local-scope
  load-ingredients
  idx:address:number <- get-address *in, index:offset
  s:address:shared:array:character <- get *in, data:offset
  next-idx:number <- find-next s, 10/newline, *idx
  result <- copy-range s, *idx, next-idx
  *idx <- add next-idx, 1  # skip newline
]

def end-of-stream? in:address:shared:stream -> result:boolean [
  local-scope
  load-ingredients
  idx:number <- get *in, index:offset
  s:address:shared:array:character <- get *in, data:offset
  len:number <- length *s
  result <- greater-or-equal idx, len
]
