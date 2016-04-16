# new type to help incrementally read texts (arrays of characters)
container stream [
  index:number
  data:address:shared:array:character
]

def new-stream s:address:shared:array:character -> result:address:shared:stream [
  local-scope
  load-ingredients
  result <- new stream:type
  *result <- put *result, index:offset, 0
  *result <- put *result, data:offset, s
]

def rewind-stream in:address:shared:stream -> in:address:shared:stream [
  local-scope
  load-ingredients
  *in <- put *in, index:offset, 0
]

def read-line in:address:shared:stream -> result:address:shared:array:character, in:address:shared:stream [
  local-scope
  load-ingredients
  idx:number <- get *in, index:offset
  s:address:shared:array:character <- get *in, data:offset
  next-idx:number <- find-next s, 10/newline, idx
  result <- copy-range s, idx, next-idx
  idx <- add next-idx, 1  # skip newline
  # write back
  *in <- put *in, index:offset, idx
]

def end-of-stream? in:address:shared:stream -> result:boolean [
  local-scope
  load-ingredients
  idx:number <- get *in, index:offset
  s:address:shared:array:character <- get *in, data:offset
  len:number <- length *s
  result <- greater-or-equal idx, len
]
