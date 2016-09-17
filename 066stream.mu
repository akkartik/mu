# new type to help incrementally scan arrays
container stream:_elem [
  index:num
  data:address:array:_elem
]

def new-stream s:address:array:_elem -> result:address:stream:_elem [
  local-scope
  load-ingredients
  result <- new {(stream _elem): type}
  *result <- put *result, index:offset, 0
  *result <- put *result, data:offset, s
]

def rewind in:address:stream:_elem -> in:address:stream:_elem [
  local-scope
  load-ingredients
  *in <- put *in, index:offset, 0
]

def read in:address:stream:_elem -> result:_elem, empty?:bool, in:address:stream:_elem [
  local-scope
  load-ingredients
  empty? <- copy 0/false
  idx:num <- get *in, index:offset
  s:address:array:_elem <- get *in, data:offset
  len:num <- length *s
  at-end?:bool <- greater-or-equal idx len
  {
    break-unless at-end?
    empty-result:address:_elem <- new _elem:type
    return *empty-result, 1/true
  }
  result <- index *s, idx
  idx <- add idx, 1
  *in <- put *in, index:offset, idx
]

def peek in:address:stream:_elem -> result:_elem, empty?:bool [
  local-scope
  load-ingredients
  empty?:bool <- copy 0/false
  idx:num <- get *in, index:offset
  s:address:array:_elem <- get *in, data:offset
  len:num <- length *s
  at-end?:bool <- greater-or-equal idx len
  {
    break-unless at-end?
    empty-result:address:_elem <- new _elem:type
    return *empty-result, 1/true
  }
  result <- index *s, idx
]

def read-line in:address:stream:char -> result:text, in:address:stream:char [
  local-scope
  load-ingredients
  idx:num <- get *in, index:offset
  s:text <- get *in, data:offset
  next-idx:num <- find-next s, 10/newline, idx
  result <- copy-range s, idx, next-idx
  idx <- add next-idx, 1  # skip newline
  # write back
  *in <- put *in, index:offset, idx
]

def end-of-stream? in:address:stream:_elem -> result:bool [
  local-scope
  load-ingredients
  idx:num <- get *in, index:offset
  s:address:array:_elem <- get *in, data:offset
  len:num <- length *s
  result <- greater-or-equal idx, len
]
