# Some useful helpers for dealing with text (arrays of characters)

def equal a:text, b:text -> result:bool [
  local-scope
  load-inputs
  an:num, bn:num <- deaddress a, b
  address-equal?:boolean <- equal an, bn
  return-if address-equal?, 1/true
  return-unless a, 0/false
  return-unless b, 0/false
  a-len:num <- length *a
  b-len:num <- length *b
  # compare lengths
  trace 99, [text-equal], [comparing lengths]
  length-equal?:bool <- equal a-len, b-len
  return-unless length-equal?, 0/false
  # compare each corresponding character
  trace 99, [text-equal], [comparing characters]
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, a-len
    break-if done?
    a2:char <- index *a, i
    b2:char <- index *b, i
    chars-match?:bool <- equal a2, b2
    return-unless chars-match?, 0/false
    i <- add i, 1
    loop
  }
  return 1/true
]

scenario text-equal-reflexive [
  local-scope
  x:text <- new [abc]
  run [
    10:bool/raw <- equal x, x
  ]
  memory-should-contain [
    10 <- 1  # x == x for all x
  ]
]

scenario text-equal-identical [
  local-scope
  x:text <- new [abc]
  y:text <- new [abc]
  run [
    10:bool/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 1  # abc == abc
  ]
]

scenario text-equal-distinct-lengths [
  local-scope
  x:text <- new [abc]
  y:text <- new [abcd]
  run [
    10:bool/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 0  # abc != abcd
  ]
  trace-should-contain [
    text-equal: comparing lengths
  ]
  trace-should-not-contain [
    text-equal: comparing characters
  ]
]

scenario text-equal-with-empty [
  local-scope
  x:text <- new []
  y:text <- new [abcd]
  run [
    10:bool/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 0  # "" != abcd
  ]
]

scenario text-equal-with-null [
  local-scope
  x:text <- new [abcd]
  y:text <- copy 0
  run [
    10:bool/raw <- equal x, 0
    11:bool/raw <- equal 0, x
    12:bool/raw <- equal x, y
    13:bool/raw <- equal y, x
    14:bool/raw <- equal y, y
  ]
  memory-should-contain [
    10 <- 0
    11 <- 0
    12 <- 0
    13 <- 0
    14 <- 1
  ]
  check-trace-count-for-label 0, [error]
]

scenario text-equal-common-lengths-but-distinct [
  local-scope
  x:text <- new [abc]
  y:text <- new [abd]
  run [
    10:bool/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 0  # abc != abd
  ]
]

# A new type to help incrementally construct texts.
container buffer:_elem [
  length:num
  data:&:@:_elem
]

def new-buffer capacity:num -> result:&:buffer:_elem [
  local-scope
  load-inputs
  result <- new {(buffer _elem): type}
  *result <- put *result, length:offset, 0
  {
    break-if capacity
    # capacity not provided
    capacity <- copy 10
  }
  data:&:@:_elem <- new _elem:type, capacity
  *result <- put *result, data:offset, data
  return result
]

def grow-buffer buf:&:buffer:_elem -> buf:&:buffer:_elem [
  local-scope
  load-inputs
  # double buffer size
  olddata:&:@:_elem <- get *buf, data:offset
  oldlen:num <- length *olddata
  newlen:num <- multiply oldlen, 2
  newdata:&:@:_elem <- new _elem:type, newlen
  *buf <- put *buf, data:offset, newdata
  # copy old contents
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, oldlen
    break-if done?
    src:_elem <- index *olddata, i
    *newdata <- put-index *newdata, i, src
    i <- add i, 1
    loop
  }
]

def buffer-full? in:&:buffer:_elem -> result:bool [
  local-scope
  load-inputs
  len:num <- get *in, length:offset
  s:&:@:_elem <- get *in, data:offset
  capacity:num <- length *s
  result <- greater-or-equal len, capacity
]

# most broadly applicable definition of append to a buffer
def append buf:&:buffer:_elem, x:_elem -> buf:&:buffer:_elem [
  local-scope
  load-inputs
  len:num <- get *buf, length:offset
  {
    # grow buffer if necessary
    full?:bool <- buffer-full? buf
    break-unless full?
    buf <- grow-buffer buf
  }
  s:&:@:_elem <- get *buf, data:offset
  *s <- put-index *s, len, x
  len <- add len, 1
  *buf <- put *buf, length:offset, len
]

# most broadly applicable definition of append to a buffer of characters: just
# call to-text
def append buf:&:buffer:char, x:_elem -> buf:&:buffer:char [
  local-scope
  load-inputs
  text:text <- to-text x
  buf <- append buf, text
]

# specialization for characters that is backspace-aware
def append buf:&:buffer:char, c:char -> buf:&:buffer:char [
  local-scope
  load-inputs
  len:num <- get *buf, length:offset
  {
    # backspace? just drop last character if it exists and return
    backspace?:bool <- equal c, 8/backspace
    break-unless backspace?
    empty?:bool <- lesser-or-equal len, 0
    return-if empty?
    len <- subtract len, 1
    *buf <- put *buf, length:offset, len
    return
  }
  {
    # grow buffer if necessary
    full?:bool <- buffer-full? buf
    break-unless full?
    buf <- grow-buffer buf
  }
  s:text <- get *buf, data:offset
  *s <- put-index *s, len, c
  len <- add len, 1
  *buf <- put *buf, length:offset, len
]

def append buf:&:buffer:_elem, t:&:@:_elem -> buf:&:buffer:_elem [
  local-scope
  load-inputs
  len:num <- length *t
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    x:_elem <- index *t, i
    buf <- append buf, x
    i <- add i, 1
    loop
  }
]

scenario append-to-empty-buffer [
  local-scope
  x:&:buffer:char <- new-buffer
  run [
    c:char <- copy 97/a
    x <- append x, c
    10:num/raw <- get *x, length:offset
    s:text <- get *x, data:offset
    11:char/raw <- index *s, 0
    12:char/raw <- index *s, 1
  ]
  memory-should-contain [
    10 <- 1  # buffer length
    11 <- 97  # a
    12 <- 0  # rest of buffer is empty
  ]
]

scenario append-to-buffer [
  local-scope
  x:&:buffer:char <- new-buffer
  c:char <- copy 97/a
  x <- append x, c
  run [
    c <- copy 98/b
    x <- append x, c
    10:num/raw <- get *x, length:offset
    s:text <- get *x, data:offset
    11:char/raw <- index *s, 0
    12:char/raw <- index *s, 1
    13:char/raw <- index *s, 2
  ]
  memory-should-contain [
    10 <- 2  # buffer length
    11 <- 97  # a
    12 <- 98  # b
    13 <- 0  # rest of buffer is empty
  ]
]

scenario append-grows-buffer [
  local-scope
  x:&:buffer:char <- new-buffer 3
  s1:text <- get *x, data:offset
  x <- append x, [abc]  # buffer is now full
  s2:text <- get *x, data:offset
  run [
    10:bool/raw <- equal s1, s2
    11:@:char/raw <- copy *s2
    +buffer-filled
    c:char <- copy 100/d
    x <- append x, c
    s3:text <- get *x, data:offset
    20:bool/raw <- equal s1, s3
    21:num/raw <- get *x, length:offset
    30:@:char/raw <- copy *s3
  ]
  memory-should-contain [
    # before +buffer-filled
    10 <- 1   # no change in data pointer after original append
    11 <- 3   # size of data
    12 <- 97  # data
    13 <- 98
    14 <- 99
    # in the end
    20 <- 0   # data pointer has grown after second append
    21 <- 4   # final length
    30 <- 6   # but data's capacity has doubled
    31 <- 97  # data
    32 <- 98
    33 <- 99
    34 <- 100
    35 <- 0
    36 <- 0
  ]
]

scenario buffer-append-handles-backspace [
  local-scope
  x:&:buffer:char <- new-buffer
  x <- append x, [ab]
  run [
    c:char <- copy 8/backspace
    x <- append x, c
    s:text <- buffer-to-array x
    10:@:char/raw <- copy *s
  ]
  memory-should-contain [
    10 <- 1   # length
    11 <- 97  # contents
    12 <- 0
  ]
]

scenario append-to-buffer-of-non-characters [
  local-scope
  x:&:buffer:text <- new-buffer 1/capacity
  # no errors
]

def buffer-to-array in:&:buffer:_elem -> result:&:@:_elem [
  local-scope
  load-inputs
  # propagate null buffer
  return-unless in, 0
  len:num <- get *in, length:offset
  s:&:@:_elem <- get *in, data:offset
  # we can't just return s because it is usually the wrong length
  result <- new _elem:type, len
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    src:_elem <- index *s, i
    *result <- put-index *result, i, src
    i <- add i, 1
    loop
  }
]

def blank? x:&:@:_elem -> result:bool [
  local-scope
  load-inputs
  return-unless x, 1/true
  len:num <- length *x
  result <- equal len, 0
]

# Append any number of texts together.
# A later layer also translates calls to this to implicitly call to-text, so
# append to string becomes effectively dynamically typed.
#
# Beware though: this hack restricts how much 'append' can be overridden. Any
# new variants that match:
#   append _:text, ___
# will never ever get used.
def append first:text -> result:text [
  local-scope
  load-inputs
  buf:&:buffer:char <- new-buffer 30
  # append first input
  {
    break-unless first
    buf <- append buf, first
  }
  # append remaining inputs
  {
    arg:text, arg-found?:bool <- next-input
    break-unless arg-found?
    loop-unless arg
    buf <- append buf, arg
    loop
  }
  result <- buffer-to-array buf
]

scenario text-append-1 [
  local-scope
  x:text <- new [hello,]
  y:text <- new [ world!]
  run [
    z:text <- append x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello, world!]
  ]
]

scenario text-append-null [
  local-scope
  x:text <- copy 0
  y:text <- new [ world!]
  run [
    z:text <- append x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [ world!]
  ]
]

scenario text-append-null-2 [
  local-scope
  x:text <- new [hello,]
  y:text <- copy 0
  run [
    z:text <- append x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello,]
  ]
]

scenario text-append-multiary [
  local-scope
  x:text <- new [hello, ]
  y:text <- new [world]
  z:text <- new [!]
  run [
    z:text <- append x, y, z
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello, world!]
  ]
]

scenario replace-character-in-text [
  local-scope
  x:text <- new [abc]
  run [
    x <- replace x, 98/b, 122/z
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [azc]
  ]
]

def replace s:text, oldc:char, newc:char, from:num/optional -> s:text [
  local-scope
  load-inputs
  len:num <- length *s
  i:num <- find-next s, oldc, from
  done?:bool <- greater-or-equal i, len
  return-if done?
  *s <- put-index *s, i, newc
  i <- add i, 1
  s <- replace s, oldc, newc, i
]

scenario replace-character-at-start [
  local-scope
  x:text <- new [abc]
  run [
    x <- replace x, 97/a, 122/z
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [zbc]
  ]
]

scenario replace-character-at-end [
  local-scope
  x:text <- new [abc]
  run [
    x <- replace x, 99/c, 122/z
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [abz]
  ]
]

scenario replace-character-missing [
  local-scope
  x:text <- new [abc]
  run [
    x <- replace x, 100/d, 122/z
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [abc]
  ]
]

scenario replace-all-characters [
  local-scope
  x:text <- new [banana]
  run [
    x <- replace x, 97/a, 122/z
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [bznznz]
  ]
]

# replace underscores in first with remaining args
def interpolate template:text -> result:text [
  local-scope
  load-inputs  # consume just the template
  # compute result-len, space to allocate for result
  tem-len:num <- length *template
  result-len:num <- copy tem-len
  {
    # while inputs remain
    a:text, arg-received?:bool <- next-input
    break-unless arg-received?
    # result-len = result-len + arg.length - 1 (for the 'underscore' being replaced)
    a-len:num <- length *a
    result-len <- add result-len, a-len
    result-len <- subtract result-len, 1
    loop
  }
  rewind-inputs
  _ <- next-input  # skip template
  result <- new character:type, result-len
  # repeatedly copy sections of template and 'holes' into result
  result-idx:num <- copy 0
  i:num <- copy 0
  {
    # while arg received
    a:text, arg-received?:bool <- next-input
    break-unless arg-received?
    # copy template into result until '_'
    {
      # while i < template.length
      tem-done?:bool <- greater-or-equal i, tem-len
      break-if tem-done?, +done
      # while template[i] != '_'
      in:char <- index *template, i
      underscore?:bool <- equal in, 95/_
      break-if underscore?
      # result[result-idx] = template[i]
      *result <- put-index *result, result-idx, in
      i <- add i, 1
      result-idx <- add result-idx, 1
      loop
    }
    # copy 'a' into result
    j:num <- copy 0
    {
      # while j < a.length
      arg-done?:bool <- greater-or-equal j, a-len
      break-if arg-done?
      # result[result-idx] = a[j]
      in:char <- index *a, j
      *result <- put-index *result, result-idx, in
      j <- add j, 1
      result-idx <- add result-idx, 1
      loop
    }
    # skip '_' in template
    i <- add i, 1
    loop  # interpolate next arg
  }
  +done
  # done with holes; copy rest of template directly into result
  {
    # while i < template.length
    tem-done?:bool <- greater-or-equal i, tem-len
    break-if tem-done?
    # result[result-idx] = template[i]
    in:char <- index *template, i
    *result <- put-index *result, result-idx, in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
]

scenario interpolate-works [
  local-scope
  x:text <- new [abc_ghi]
  y:text <- new [def]
  run [
    z:text <- interpolate x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [abcdefghi]
  ]
]

scenario interpolate-at-start [
  local-scope
  x:text <- new [_, hello!]
  y:text <- new [abc]
  run [
    z:text <- interpolate x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [abc, hello!]
    22 <- 0  # out of bounds
  ]
]

scenario interpolate-at-end [
  local-scope
  x:text <- new [hello, _]
  y:text <- new [abc]
  run [
    z:text <- interpolate x, y
    10:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello, abc]
  ]
]

# result:bool <- space? c:char
def space? c:char -> result:bool [
  local-scope
  load-inputs
  # most common case first
  result <- equal c, 32/space
  return-if result
  result <- equal c, 10/newline
  return-if result
  result <- equal c, 9/tab
  return-if result
  result <- equal c, 13/carriage-return
  return-if result
  # remaining uncommon cases in sorted order
  # http://unicode.org code-points in unicode-set Z and Pattern_White_Space
  result <- equal c, 11/ctrl-k
  return-if result
  result <- equal c, 12/ctrl-l
  return-if result
  result <- equal c, 133/ctrl-0085
  return-if result
  result <- equal c, 160/no-break-space
  return-if result
  result <- equal c, 5760/ogham-space-mark
  return-if result
  result <- equal c, 8192/en-quad
  return-if result
  result <- equal c, 8193/em-quad
  return-if result
  result <- equal c, 8194/en-space
  return-if result
  result <- equal c, 8195/em-space
  return-if result
  result <- equal c, 8196/three-per-em-space
  return-if result
  result <- equal c, 8197/four-per-em-space
  return-if result
  result <- equal c, 8198/six-per-em-space
  return-if result
  result <- equal c, 8199/figure-space
  return-if result
  result <- equal c, 8200/punctuation-space
  return-if result
  result <- equal c, 8201/thin-space
  return-if result
  result <- equal c, 8202/hair-space
  return-if result
  result <- equal c, 8206/left-to-right
  return-if result
  result <- equal c, 8207/right-to-left
  return-if result
  result <- equal c, 8232/line-separator
  return-if result
  result <- equal c, 8233/paragraph-separator
  return-if result
  result <- equal c, 8239/narrow-no-break-space
  return-if result
  result <- equal c, 8287/medium-mathematical-space
  return-if result
  result <- equal c, 12288/ideographic-space
]

def trim s:text -> result:text [
  local-scope
  load-inputs
  len:num <- length *s
  # left trim: compute start
  start:num <- copy 0
  {
    {
      at-end?:bool <- greater-or-equal start, len
      break-unless at-end?
      result <- new character:type, 0
      return
    }
    curr:char <- index *s, start
    whitespace?:bool <- space? curr
    break-unless whitespace?
    start <- add start, 1
    loop
  }
  # right trim: compute end
  end:num <- subtract len, 1
  {
    not-at-start?:bool <- greater-than end, start
    assert not-at-start?, [end ran up against start]
    curr:char <- index *s, end
    whitespace?:bool <- space? curr
    break-unless whitespace?
    end <- subtract end, 1
    loop
  }
  # result = new character[end+1 - start]
  new-len:num <- subtract end, start, -1
  result:text <- new character:type, new-len
  # copy the untrimmed parts between start and end
  i:num <- copy start
  j:num <- copy 0
  {
    # while i <= end
    done?:bool <- greater-than i, end
    break-if done?
    # result[j] = s[i]
    src:char <- index *s, i
    *result <- put-index *result, j, src
    i <- add i, 1
    j <- add j, 1
    loop
  }
]

scenario trim-unmodified [
  local-scope
  x:text <- new [abc]
  run [
    y:text <- trim x
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-left [
  local-scope
  x:text <- new [  abc]
  run [
    y:text <- trim x
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-right [
  local-scope
  x:text <- new [abc  ]
  run [
    y:text <- trim x
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-left-right [
  local-scope
  x:text <- new [  abc   ]
  run [
    y:text <- trim x
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-newline-tab [
  local-scope
  x:text <- new [	abc
]
  run [
    y:text <- trim x
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

def find-next text:text, pattern:char, idx:num -> next-index:num [
  local-scope
  load-inputs
  len:num <- length *text
  {
    eof?:bool <- greater-or-equal idx, len
    break-if eof?
    curr:char <- index *text, idx
    found?:bool <- equal curr, pattern
    break-if found?
    idx <- add idx, 1
    loop
  }
  return idx
]

scenario text-find-next [
  local-scope
  x:text <- new [a/b]
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario text-find-next-empty [
  local-scope
  x:text <- new []
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 0
  ]
]

scenario text-find-next-initial [
  local-scope
  x:text <- new [/abc]
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 0  # prefix match
  ]
]

scenario text-find-next-final [
  local-scope
  x:text <- new [abc/]
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 3  # suffix match
  ]
]

scenario text-find-next-missing [
  local-scope
  x:text <- new [abcd]
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 4  # no match
  ]
]

scenario text-find-next-invalid-index [
  local-scope
  x:text <- new [abc]
  run [
    10:num/raw <- find-next x, 47/slash, 4/start-index
  ]
  memory-should-contain [
    10 <- 4  # no change
  ]
]

scenario text-find-next-first [
  local-scope
  x:text <- new [ab/c/]
  run [
    10:num/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 2  # first '/' of multiple
  ]
]

scenario text-find-next-second [
  local-scope
  x:text <- new [ab/c/]
  run [
    10:num/raw <- find-next x, 47/slash, 3/start-index
  ]
  memory-should-contain [
    10 <- 4  # second '/' of multiple
  ]
]

# search for a pattern of multiple characters
# fairly dumb algorithm
def find-next text:text, pattern:text, idx:num -> next-index:num [
  local-scope
  load-inputs
  first:char <- index *pattern, 0
  # repeatedly check for match at current idx
  len:num <- length *text
  {
    # does some unnecessary work checking even when there isn't enough of text left
    done?:bool <- greater-or-equal idx, len
    break-if done?
    found?:bool <- match-at text, pattern, idx
    break-if found?
    idx <- add idx, 1
    # optimization: skip past indices that definitely won't match
    idx <- find-next text, first, idx
    loop
  }
  return idx
]

scenario find-next-text-1 [
  local-scope
  x:text <- new [abc]
  y:text <- new [bc]
  run [
    10:num/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario find-next-text-2 [
  local-scope
  x:text <- new [abcd]
  y:text <- new [bc]
  run [
    10:num/raw <- find-next x, y, 1
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario find-next-no-match [
  local-scope
  x:text <- new [abc]
  y:text <- new [bd]
  run [
    10:num/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 3  # not found
  ]
]

scenario find-next-suffix-match [
  local-scope
  x:text <- new [abcd]
  y:text <- new [cd]
  run [
    10:num/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 2
  ]
]

scenario find-next-suffix-match-2 [
  local-scope
  x:text <- new [abcd]
  y:text <- new [cde]
  run [
    10:num/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 4  # not found
  ]
]

# checks if pattern matches at index 'idx'
def match-at text:text, pattern:text, idx:num -> result:bool [
  local-scope
  load-inputs
  pattern-len:num <- length *pattern
  # check that there's space left for the pattern
  x:num <- length *text
  x <- subtract x, pattern-len
  enough-room?:bool <- lesser-or-equal idx, x
  return-unless enough-room?, 0/not-found
  # check each character of pattern
  pattern-idx:num <- copy 0
  {
    done?:bool <- greater-or-equal pattern-idx, pattern-len
    break-if done?
    c:char <- index *text, idx
    exp:char <- index *pattern, pattern-idx
    match?:bool <- equal c, exp
    return-unless match?, 0/not-found
    idx <- add idx, 1
    pattern-idx <- add pattern-idx, 1
    loop
  }
  return 1/found
]

scenario match-at-checks-pattern-at-index [
  local-scope
  x:text <- new [abc]
  y:text <- new [ab]
  run [
    10:bool/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 1  # match found
  ]
]

scenario match-at-reflexive [
  local-scope
  x:text <- new [abc]
  run [
    10:bool/raw <- match-at x, x, 0
  ]
  memory-should-contain [
    10 <- 1  # match found
  ]
]

scenario match-at-outside-bounds [
  local-scope
  x:text <- new [abc]
  y:text <- new [a]
  run [
    10:bool/raw <- match-at x, y, 4
  ]
  memory-should-contain [
    10 <- 0  # never matches
  ]
]

scenario match-at-empty-pattern [
  local-scope
  x:text <- new [abc]
  y:text <- new []
  run [
    10:bool/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 1  # always matches empty pattern given a valid index
  ]
]

scenario match-at-empty-pattern-outside-bound [
  local-scope
  x:text <- new [abc]
  y:text <- new []
  run [
    10:bool/raw <- match-at x, y, 4
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

scenario match-at-empty-text [
  local-scope
  x:text <- new []
  y:text <- new [abc]
  run [
    10:bool/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

scenario match-at-empty-against-empty [
  local-scope
  x:text <- new []
  run [
    10:bool/raw <- match-at x, x, 0
  ]
  memory-should-contain [
    10 <- 1  # matches because pattern is also empty
  ]
]

scenario match-at-inside-bounds [
  local-scope
  x:text <- new [abc]
  y:text <- new [bc]
  run [
    10:bool/raw <- match-at x, y, 1
  ]
  memory-should-contain [
    10 <- 1  # match
  ]
]

scenario match-at-inside-bounds-2 [
  local-scope
  x:text <- new [abc]
  y:text <- new [bc]
  run [
    10:bool/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

def split s:text, delim:char -> result:&:@:text [
  local-scope
  load-inputs
  # empty text? return empty array
  len:num <- length *s
  {
    empty?:bool <- equal len, 0
    break-unless empty?
    result <- new {(address array character): type}, 0
    return
  }
  # count #pieces we need room for
  count:num <- copy 1  # n delimiters = n+1 pieces
  idx:num <- copy 0
  {
    idx <- find-next s, delim, idx
    done?:bool <- greater-or-equal idx, len
    break-if done?
    idx <- add idx, 1
    count <- add count, 1
    loop
  }
  # allocate space
  result <- new {(address array character): type}, count
  # repeatedly copy slices start..end until delimiter into result[curr-result]
  curr-result:num <- copy 0
  start:num <- copy 0
  {
    # while next delim exists
    done?:bool <- greater-or-equal start, len
    break-if done?
    end:num <- find-next s, delim, start
    # copy start..end into result[curr-result]
    dest:text <- copy-range s, start, end
    *result <- put-index *result, curr-result, dest
    # slide over to next slice
    start <- add end, 1
    curr-result <- add curr-result, 1
    loop
  }
]

scenario text-split-1 [
  local-scope
  x:text <- new [a/b]
  run [
    y:&:@:text <- split x, 47/slash
    10:num/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    20:@:char/raw <- copy *a
    30:@:char/raw <- copy *b
  ]
  memory-should-contain [
    10 <- 2  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
  ]
]

scenario text-split-2 [
  local-scope
  x:text <- new [a/b/c]
  run [
    y:&:@:text <- split x, 47/slash
    10:num/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    c:text <- index *y, 2
    20:@:char/raw <- copy *a
    30:@:char/raw <- copy *b
    40:@:char/raw <- copy *c
  ]
  memory-should-contain [
    10 <- 3  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
    40:array:character <- [c]
  ]
]

scenario text-split-missing [
  local-scope
  x:text <- new [abc]
  run [
    y:&:@:text <- split x, 47/slash
    10:num/raw <- length *y
    a:text <- index *y, 0
    20:@:char/raw <- copy *a
  ]
  memory-should-contain [
    10 <- 1  # length of result
    20:array:character <- [abc]
  ]
]

scenario text-split-empty [
  local-scope
  x:text <- new []
  run [
    y:&:@:text <- split x, 47/slash
    10:num/raw <- length *y
  ]
  memory-should-contain [
    10 <- 0  # empty result
  ]
]

scenario text-split-empty-piece [
  local-scope
  x:text <- new [a/b//c]
  run [
    y:&:@:text <- split x:text, 47/slash
    10:num/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    c:text <- index *y, 2
    d:text <- index *y, 3
    20:@:char/raw <- copy *a
    30:@:char/raw <- copy *b
    40:@:char/raw <- copy *c
    50:@:char/raw <- copy *d
  ]
  memory-should-contain [
    10 <- 4  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
    40:array:character <- []
    50:array:character <- [c]
  ]
]

def split-first text:text, delim:char -> x:text, y:text [
  local-scope
  load-inputs
  # empty text? return empty texts
  len:num <- length *text
  {
    empty?:bool <- equal len, 0
    break-unless empty?
    x:text <- new []
    y:text <- new []
    return
  }
  idx:num <- find-next text, delim, 0
  x:text <- copy-range text, 0, idx
  idx <- add idx, 1
  y:text <- copy-range text, idx, len
]

scenario text-split-first [
  local-scope
  x:text <- new [a/b]
  run [
    y:text, z:text <- split-first x, 47/slash
    10:@:char/raw <- copy *y
    20:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [a]
    20:array:character <- [b]
  ]
]

def copy-range buf:text, start:num, end:num -> result:text [
  local-scope
  load-inputs
  # if end is out of bounds, trim it
  len:num <- length *buf
  end:num <- min len, end
  # allocate space for result
  len <- subtract end, start
  result:text <- new character:type, len
  # copy start..end into result[curr-result]
  src-idx:num <- copy start
  dest-idx:num <- copy 0
  {
    done?:bool <- greater-or-equal src-idx, end
    break-if done?
    src:char <- index *buf, src-idx
    *result <- put-index *result, dest-idx, src
    src-idx <- add src-idx, 1
    dest-idx <- add dest-idx, 1
    loop
  }
]

scenario copy-range-works [
  local-scope
  x:text <- new [abc]
  run [
    y:text <- copy-range x, 1, 3
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [bc]
  ]
]

scenario copy-range-out-of-bounds [
  local-scope
  x:text <- new [abc]
  run [
    y:text <- copy-range x, 2, 4
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [c]
  ]
]

scenario copy-range-out-of-bounds-2 [
  local-scope
  x:text <- new [abc]
  run [
    y:text <- copy-range x, 3, 3
    1:@:char/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- []
  ]
]

def parse-whole-number in:text -> out:num, error?:bool [
  local-scope
  load-inputs
  out <- copy 0
  result:num <- copy 0  # temporary location
  i:num <- copy 0
  len:num <- length *in
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    c:char <- index *in, i
    x:num <- character-to-code c
    digit:num, error?:bool <- character-code-to-digit x
    return-if error?
    result <- multiply result, 10
    result <- add result, digit
    i <- add i, 1
    loop
  }
  # no error; all digits were valid
  out <- copy result
]

# (contributed by Ella Couch)
recipe character-code-to-digit character-code:number -> result:number, error?:boolean [
  local-scope
  load-inputs
  result <- copy 0
  error? <- lesser-than character-code, 48  # '0'
  return-if error?
  error? <- greater-than character-code, 57  # '9'
  return-if error?
  result <- subtract character-code, 48
]

scenario character-code-to-digit-contain-only-digit [
  local-scope
  a:number <- copy 48  # character code for '0'
  run [
    10:number/raw, 11:boolean/raw <- character-code-to-digit a
  ]
  memory-should-contain [
    10 <- 0
    11 <- 0  # no error
  ]
]

scenario character-code-to-digit-contain-only-digit-2 [
  local-scope
  a:number <- copy 57  # character code for '9'
  run [
    1:number/raw, 2:boolean/raw <- character-code-to-digit a
  ]
  memory-should-contain [
    1 <- 9
    2 <- 0  # no error
  ]
]

scenario character-code-to-digit-handles-codes-lower-than-zero [
  local-scope
  a:number <- copy 47
  run [
    10:number/raw, 11:boolean/raw <- character-code-to-digit a
  ]
  memory-should-contain [
    10 <- 0
    11 <- 1  # error
  ]
]

scenario character-code-to-digit-handles-codes-larger-than-nine [
  local-scope
  a:number <- copy 58
  run [
    10:number/raw, 11:boolean/raw <- character-code-to-digit a
  ]
  memory-should-contain [
    10 <- 0
    11 <- 1  # error
  ]
]
