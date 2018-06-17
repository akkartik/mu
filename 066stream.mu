# new type to help incrementally scan arrays
container stream:_elem [
  index:num
  data:&:@:_elem
]

def new-stream s:&:@:_elem -> result:&:stream:_elem [
  local-scope
  load-inputs
  return-unless s, 0/null
  result <- new {(stream _elem): type}
  *result <- put *result, index:offset, 0
  *result <- put *result, data:offset, s
]

def rewind in:&:stream:_elem -> in:&:stream:_elem [
  local-scope
  load-inputs
  return-unless in
  *in <- put *in, index:offset, 0
]

def read in:&:stream:_elem -> result:_elem, empty?:bool, in:&:stream:_elem [
  local-scope
  load-inputs
  assert in, [cannot read; stream has no data]
  empty? <- copy false
  idx:num <- get *in, index:offset
  s:&:@:_elem <- get *in, data:offset
  len:num <- length *s
  at-end?:bool <- greater-or-equal idx len
  {
    break-unless at-end?
    empty-result:&:_elem <- new _elem:type
    return *empty-result, true
  }
  result <- index *s, idx
  idx <- add idx, 1
  *in <- put *in, index:offset, idx
]

def peek in:&:stream:_elem -> result:_elem, empty?:bool [
  local-scope
  load-inputs
  assert in, [cannot peek; stream has no data]
  empty?:bool <- copy false
  idx:num <- get *in, index:offset
  s:&:@:_elem <- get *in, data:offset
  len:num <- length *s
  at-end?:bool <- greater-or-equal idx len
  {
    break-unless at-end?
    empty-result:&:_elem <- new _elem:type
    return *empty-result, true
  }
  result <- index *s, idx
]

def read-line in:&:stream:char -> result:text, in:&:stream:char [
  local-scope
  load-inputs
  assert in, [cannot read-line; stream has no data]
  idx:num <- get *in, index:offset
  s:text <- get *in, data:offset
  next-idx:num <- find-next s, 10/newline, idx
  result <- copy-range s, idx, next-idx
  idx <- add next-idx, 1  # skip newline
  # write back
  *in <- put *in, index:offset, idx
]

def end-of-stream? in:&:stream:_elem -> result:bool [
  local-scope
  load-inputs
  assert in, [cannot check end-of-stream?; stream has no data]
  idx:num <- get *in, index:offset
  s:&:@:_elem <- get *in, data:offset
  len:num <- length *s
  result <- greater-or-equal idx, len
]
