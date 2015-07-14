# new type to help incrementally read strings
container stream [
  index:number
  data:address:array:character
]

recipe new-stream [
  new-default-space
  result:address:stream <- new stream:type
  i:address:number <- get-address result:address:stream/deref, index:offset
  i:address:number/deref <- copy 0:literal
  d:address:address:array:character <- get-address result:address:stream/deref, data:offset
  d:address:address:array:character/deref <- next-ingredient
  reply result:address:stream
]

recipe rewind-stream [
  new-default-space
  in:address:stream <- next-ingredient
  x:address:number <- get-address in:address:stream/deref, index:offset
  x:address:number/deref <- copy 0:literal
  reply in:address:stream/same-as-arg:0
]

recipe read-line [
  new-default-space
  in:address:stream <- next-ingredient
  idx:address:number <- get-address in:address:stream/deref, index:offset
  s:address:array:character <- get in:address:stream/deref, data:offset
  next-idx:number <- find-next s:address:array:character, 10:literal/newline, idx:address:number/deref
  result:address:array:character <- string-copy s:address:array:character, idx:address:number/deref, next-idx:number
  idx:address:number/deref <- add next-idx:number, 1:literal  # skip newline
  reply result:address:array:character
]

recipe end-of-stream? [
  new-default-space
  in:address:stream <- next-ingredient
  idx:number <- get in:address:stream/deref, index:offset
  s:address:array:character <- get in:address:stream/deref, data:offset
  len:number <- length s:address:array:character/deref
  result:boolean <- greater-or-equal idx:number, len:number
  reply result:boolean
]
