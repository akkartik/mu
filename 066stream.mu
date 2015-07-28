# new type to help incrementally read strings
container stream [
  index:number
  data:address:array:character
]

recipe new-stream [
  local-scope
  result:address:stream <- new stream:type
  i:address:number <- get-address result:address:stream/lookup, index:offset
  i:address:number/lookup <- copy 0
  d:address:address:array:character <- get-address result:address:stream/lookup, data:offset
  d:address:address:array:character/lookup <- next-ingredient
  reply result:address:stream
]

recipe rewind-stream [
  local-scope
  in:address:stream <- next-ingredient
  x:address:number <- get-address in:address:stream/lookup, index:offset
  x:address:number/lookup <- copy 0
  reply in:address:stream/same-as-arg:0
]

recipe read-line [
  local-scope
  in:address:stream <- next-ingredient
  idx:address:number <- get-address in:address:stream/lookup, index:offset
  s:address:array:character <- get in:address:stream/lookup, data:offset
  next-idx:number <- find-next s:address:array:character, 10/newline, idx:address:number/lookup
  result:address:array:character <- string-copy s:address:array:character, idx:address:number/lookup, next-idx:number
  idx:address:number/lookup <- add next-idx:number, 1  # skip newline
  reply result:address:array:character
]

recipe end-of-stream? [
  local-scope
  in:address:stream <- next-ingredient
  idx:number <- get in:address:stream/lookup, index:offset
  s:address:array:character <- get in:address:stream/lookup, data:offset
  len:number <- length s:address:array:character/lookup
  result:boolean <- greater-or-equal idx:number, len:number
  reply result:boolean
]
