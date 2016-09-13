# Some useful helpers for dealing with text (arrays of characters)
type text = address:array:character

def equal a:text, b:text -> result:boolean [
  local-scope
  load-ingredients
  a-len:number <- length *a
  b-len:number <- length *b
  # compare lengths
  {
    trace 99, [text-equal], [comparing lengths]
    length-equal?:boolean <- equal a-len, b-len
    break-if length-equal?
    return 0
  }
  # compare each corresponding character
  trace 99, [text-equal], [comparing characters]
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, a-len
    break-if done?
    a2:character <- index *a, i
    b2:character <- index *b, i
    {
      chars-match?:boolean <- equal a2, b2
      break-if chars-match?
      return 0
    }
    i <- add i, 1
    loop
  }
  return 1
]

scenario text-equal-reflexive [
  run [
    local-scope
    x:text <- new [abc]
    10:boolean/raw <- equal x, x
  ]
  memory-should-contain [
    10 <- 1  # x == x for all x
  ]
]

scenario text-equal-identical [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [abc]
    10:boolean/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 1  # abc == abc
  ]
]

scenario text-equal-distinct-lengths [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [abcd]
    10:boolean/raw <- equal x, y
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
  run [
    local-scope
    x:text <- new []
    y:text <- new [abcd]
    10:boolean/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 0  # "" != abcd
  ]
]

scenario text-equal-common-lengths-but-distinct [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [abd]
    10:boolean/raw <- equal x, y
  ]
  memory-should-contain [
    10 <- 0  # abc != abd
  ]
]

# A new type to help incrementally construct texts.
container buffer [
  length:number
  data:text
]

def new-buffer capacity:number -> result:address:buffer [
  local-scope
  load-ingredients
  result <- new buffer:type
  *result <- put *result, length:offset, 0
  {
    break-if capacity
    # capacity not provided
    capacity <- copy 10
  }
  data:text <- new character:type, capacity
  *result <- put *result, data:offset, data
  return result
]

def grow-buffer in:address:buffer -> in:address:buffer [
  local-scope
  load-ingredients
  # double buffer size
  olddata:text <- get *in, data:offset
  oldlen:number <- length *olddata
  newlen:number <- multiply oldlen, 2
  newdata:text <- new character:type, newlen
  *in <- put *in, data:offset, newdata
  # copy old contents
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, oldlen
    break-if done?
    src:character <- index *olddata, i
    *newdata <- put-index *newdata, i, src
    i <- add i, 1
    loop
  }
]

def buffer-full? in:address:buffer -> result:boolean [
  local-scope
  load-ingredients
  len:number <- get *in, length:offset
  s:text <- get *in, data:offset
  capacity:number <- length *s
  result <- greater-or-equal len, capacity
]

# most broadly applicable definition of append to a buffer: just call to-text
def append buf:address:buffer, x:_elem -> buf:address:buffer [
  local-scope
  load-ingredients
  text:text <- to-text x
  len:number <- length *text
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *text, i
    buf <- append buf, c
    i <- add i, 1
    loop
  }
]

def append in:address:buffer, c:character -> in:address:buffer [
  local-scope
  load-ingredients
  len:number <- get *in, length:offset
  {
    # backspace? just drop last character if it exists and return
    backspace?:boolean <- equal c, 8/backspace
    break-unless backspace?
    empty?:boolean <- lesser-or-equal len, 0
    return-if empty?
    len <- subtract len, 1
    *in <- put *in, length:offset, len
    return
  }
  {
    # grow buffer if necessary
    full?:boolean <- buffer-full? in
    break-unless full?
    in <- grow-buffer in
  }
  s:text <- get *in, data:offset
  *s <- put-index *s, len, c
  len <- add len, 1
  *in <- put *in, length:offset, len
]

scenario buffer-append-works [
  run [
    local-scope
    x:address:buffer <- new-buffer 3
    s1:text <- get *x, data:offset
    c:character <- copy 97/a
    x <- append x, c
    c:character <- copy 98/b
    x <- append x, c
    c:character <- copy 99/c
    x <- append x, c
    s2:text <- get *x, data:offset
    10:boolean/raw <- equal s1, s2
    11:array:character/raw <- copy *s2
    +buffer-filled
    c:character <- copy 100/d
    x <- append x, c
    s3:text <- get *x, data:offset
    20:boolean/raw <- equal s1, s3
    21:number/raw <- get *x, length:offset
    30:array:character/raw <- copy *s3
  ]
  memory-should-contain [
    # before +buffer-filled
    10 <- 1   # no change in data pointer
    11 <- 3   # size of data
    12 <- 97  # data
    13 <- 98
    14 <- 99
    # in the end
    20 <- 0   # data pointer has grown
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

scenario buffer-append-to-empty [
  run [
    local-scope
    x:address:buffer <- new-buffer
    c:character <- copy 97/a
    x <- append x, c
  ]
]

scenario buffer-append-handles-backspace [
  run [
    local-scope
    x:address:buffer <- new-buffer 3
    c:character <- copy 97/a
    x <- append x, c
    c:character <- copy 98/b
    x <- append x, c
    c:character <- copy 8/backspace
    x <- append x, c
    s:text <- buffer-to-array x
    10:array:character/raw <- copy *s
  ]
  memory-should-contain [
    10 <- 1   # length
    11 <- 97  # contents
    12 <- 0
  ]
]

def buffer-to-array in:address:buffer -> result:text [
  local-scope
  load-ingredients
  {
    # propagate null buffer
    break-if in
    return 0
  }
  len:number <- get *in, length:offset
  s:text <- get *in, data:offset
  # we can't just return s because it is usually the wrong length
  result <- new character:type, len
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    src:character <- index *s, i
    *result <- put-index *result, i, src
    i <- add i, 1
    loop
  }
]

def append a:text, b:text -> result:text [
  local-scope
  load-ingredients
  # handle null addresses
  return-unless a, b
  return-unless b, a
  # result = new character[a.length + b.length]
  a-len:number <- length *a
  b-len:number <- length *b
  result-len:number <- add a-len, b-len
  result <- new character:type, result-len
  # copy a into result
  result-idx:number <- copy 0
  i:number <- copy 0
  {
    # while i < a.length
    a-done?:boolean <- greater-or-equal i, a-len
    break-if a-done?
    # result[result-idx] = a[i]
    in:character <- index *a, i
    *result <- put-index *result, result-idx, in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
  # copy b into result
  i <- copy 0
  {
    # while i < b.length
    b-done?:boolean <- greater-or-equal i, b-len
    break-if b-done?
    # result[result-idx] = a[i]
    in:character <- index *b, i
    *result <- put-index *result, result-idx, in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
]

scenario text-append-1 [
  run [
    local-scope
    x:text <- new [hello,]
    y:text <- new [ world!]
    z:text <- append x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello, world!]
  ]
]

scenario text-append-null [
  run [
    local-scope
    x:text <- copy 0
    y:text <- new [ world!]
    z:text <- append x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [ world!]
  ]
]

scenario text-append-null-2 [
  run [
    local-scope
    x:text <- new [hello,]
    y:text <- copy 0
    z:text <- append x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello,]
  ]
]

scenario replace-character-in-text [
  run [
    local-scope
    x:text <- new [abc]
    x <- replace x, 98/b, 122/z
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [azc]
  ]
]

def replace s:text, oldc:character, newc:character, from:number/optional -> s:text [
  local-scope
  load-ingredients
  len:number <- length *s
  i:number <- find-next s, oldc, from
  done?:boolean <- greater-or-equal i, len
  return-if done?, s/same-as-ingredient:0
  *s <- put-index *s, i, newc
  i <- add i, 1
  s <- replace s, oldc, newc, i
]

scenario replace-character-at-start [
  run [
    local-scope
    x:text <- new [abc]
    x <- replace x, 97/a, 122/z
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [zbc]
  ]
]

scenario replace-character-at-end [
  run [
    local-scope
    x:text <- new [abc]
    x <- replace x, 99/c, 122/z
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [abz]
  ]
]

scenario replace-character-missing [
  run [
    local-scope
    x:text <- new [abc]
    x <- replace x, 100/d, 122/z
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [abc]
  ]
]

scenario replace-all-characters [
  run [
    local-scope
    x:text <- new [banana]
    x <- replace x, 97/a, 122/z
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10:array:character <- [bznznz]
  ]
]

# replace underscores in first with remaining args
def interpolate template:text -> result:text [
  local-scope
  load-ingredients  # consume just the template
  # compute result-len, space to allocate for result
  tem-len:number <- length *template
  result-len:number <- copy tem-len
  {
    # while ingredients remain
    a:text, arg-received?:boolean <- next-ingredient
    break-unless arg-received?
    # result-len = result-len + arg.length - 1 (for the 'underscore' being replaced)
    a-len:number <- length *a
    result-len <- add result-len, a-len
    result-len <- subtract result-len, 1
    loop
  }
  rewind-ingredients
  _ <- next-ingredient  # skip template
  result <- new character:type, result-len
  # repeatedly copy sections of template and 'holes' into result
  result-idx:number <- copy 0
  i:number <- copy 0
  {
    # while arg received
    a:text, arg-received?:boolean <- next-ingredient
    break-unless arg-received?
    # copy template into result until '_'
    {
      # while i < template.length
      tem-done?:boolean <- greater-or-equal i, tem-len
      break-if tem-done?, +done:label
      # while template[i] != '_'
      in:character <- index *template, i
      underscore?:boolean <- equal in, 95/_
      break-if underscore?
      # result[result-idx] = template[i]
      *result <- put-index *result, result-idx, in
      i <- add i, 1
      result-idx <- add result-idx, 1
      loop
    }
    # copy 'a' into result
    j:number <- copy 0
    {
      # while j < a.length
      arg-done?:boolean <- greater-or-equal j, a-len
      break-if arg-done?
      # result[result-idx] = a[j]
      in:character <- index *a, j
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
    tem-done?:boolean <- greater-or-equal i, tem-len
    break-if tem-done?
    # result[result-idx] = template[i]
    in:character <- index *template, i
    *result <- put-index *result, result-idx, in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
]

scenario interpolate-works [
  run [
    local-scope
    x:text <- new [abc_ghi]
    y:text <- new [def]
    z:text <- interpolate x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [abcdefghi]
  ]
]

scenario interpolate-at-start [
  run [
    local-scope
    x:text <- new [_, hello!]
    y:text <- new [abc]
    z:text <- interpolate x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [abc, hello!]
    22 <- 0  # out of bounds
  ]
]

scenario interpolate-at-end [
  run [
    x:text <- new [hello, _]
    y:text <- new [abc]
    z:text <- interpolate x, y
    10:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [hello, abc]
  ]
]

# result:boolean <- space? c:character
def space? c:character -> result:boolean [
  local-scope
  load-ingredients
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
  load-ingredients
  len:number <- length *s
  # left trim: compute start
  start:number <- copy 0
  {
    {
      at-end?:boolean <- greater-or-equal start, len
      break-unless at-end?
      result <- new character:type, 0
      return
    }
    curr:character <- index *s, start
    whitespace?:boolean <- space? curr
    break-unless whitespace?
    start <- add start, 1
    loop
  }
  # right trim: compute end
  end:number <- subtract len, 1
  {
    not-at-start?:boolean <- greater-than end, start
    assert not-at-start?, [end ran up against start]
    curr:character <- index *s, end
    whitespace?:boolean <- space? curr
    break-unless whitespace?
    end <- subtract end, 1
    loop
  }
  # result = new character[end+1 - start]
  new-len:number <- subtract end, start, -1
  result:text <- new character:type, new-len
  # copy the untrimmed parts between start and end
  i:number <- copy start
  j:number <- copy 0
  {
    # while i <= end
    done?:boolean <- greater-than i, end
    break-if done?
    # result[j] = s[i]
    src:character <- index *s, i
    *result <- put-index *result, j, src
    i <- add i, 1
    j <- add j, 1
    loop
  }
]

scenario trim-unmodified [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- trim x
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-left [
  run [
    local-scope
    x:text <- new [  abc]
    y:text <- trim x
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-right [
  run [
    local-scope
    x:text <- new [abc  ]
    y:text <- trim x
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-left-right [
  run [
    local-scope
    x:text <- new [  abc   ]
    y:text <- trim x
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario trim-newline-tab [
  run [
    local-scope
    x:text <- new [	abc
]
    y:text <- trim x
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

def find-next text:text, pattern:character, idx:number -> next-index:number [
  local-scope
  load-ingredients
  len:number <- length *text
  {
    eof?:boolean <- greater-or-equal idx, len
    break-if eof?
    curr:character <- index *text, idx
    found?:boolean <- equal curr, pattern
    break-if found?
    idx <- add idx, 1
    loop
  }
  return idx
]

scenario text-find-next [
  run [
    local-scope
    x:text <- new [a/b]
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario text-find-next-empty [
  run [
    local-scope
    x:text <- new []
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 0
  ]
]

scenario text-find-next-initial [
  run [
    local-scope
    x:text <- new [/abc]
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 0  # prefix match
  ]
]

scenario text-find-next-final [
  run [
    local-scope
    x:text <- new [abc/]
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 3  # suffix match
  ]
]

scenario text-find-next-missing [
  run [
    local-scope
    x:text <- new [abcd]
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 4  # no match
  ]
]

scenario text-find-next-invalid-index [
  run [
    local-scope
    x:text <- new [abc]
    10:number/raw <- find-next x, 47/slash, 4/start-index
  ]
  memory-should-contain [
    10 <- 4  # no change
  ]
]

scenario text-find-next-first [
  run [
    local-scope
    x:text <- new [ab/c/]
    10:number/raw <- find-next x, 47/slash, 0/start-index
  ]
  memory-should-contain [
    10 <- 2  # first '/' of multiple
  ]
]

scenario text-find-next-second [
  run [
    local-scope
    x:text <- new [ab/c/]
    10:number/raw <- find-next x, 47/slash, 3/start-index
  ]
  memory-should-contain [
    10 <- 4  # second '/' of multiple
  ]
]

# search for a pattern of multiple characters
# fairly dumb algorithm
def find-next text:text, pattern:text, idx:number -> next-index:number [
  local-scope
  load-ingredients
  first:character <- index *pattern, 0
  # repeatedly check for match at current idx
  len:number <- length *text
  {
    # does some unnecessary work checking even when there isn't enough of text left
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    found?:boolean <- match-at text, pattern, idx
    break-if found?
    idx <- add idx, 1
    # optimization: skip past indices that definitely won't match
    idx <- find-next text, first, idx
    loop
  }
  return idx
]

scenario find-next-text-1 [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [bc]
    10:number/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario find-next-text-2 [
  run [
    local-scope
    x:text <- new [abcd]
    y:text <- new [bc]
    10:number/raw <- find-next x, y, 1
  ]
  memory-should-contain [
    10 <- 1
  ]
]

scenario find-next-no-match [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [bd]
    10:number/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 3  # not found
  ]
]

scenario find-next-suffix-match [
  run [
    local-scope
    x:text <- new [abcd]
    y:text <- new [cd]
    10:number/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 2
  ]
]

scenario find-next-suffix-match-2 [
  run [
    local-scope
    x:text <- new [abcd]
    y:text <- new [cde]
    10:number/raw <- find-next x, y, 0
  ]
  memory-should-contain [
    10 <- 4  # not found
  ]
]

# checks if pattern matches at index 'idx'
def match-at text:text, pattern:text, idx:number -> result:boolean [
  local-scope
  load-ingredients
  pattern-len:number <- length *pattern
  # check that there's space left for the pattern
  {
    x:number <- length *text
    x <- subtract x, pattern-len
    enough-room?:boolean <- lesser-or-equal idx, x
    break-if enough-room?
    return 0/not-found
  }
  # check each character of pattern
  pattern-idx:number <- copy 0
  {
    done?:boolean <- greater-or-equal pattern-idx, pattern-len
    break-if done?
    c:character <- index *text, idx
    exp:character <- index *pattern, pattern-idx
    {
      match?:boolean <- equal c, exp
      break-if match?
      return 0/not-found
    }
    idx <- add idx, 1
    pattern-idx <- add pattern-idx, 1
    loop
  }
  return 1/found
]

scenario match-at-checks-pattern-at-index [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [ab]
    10:boolean/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 1  # match found
  ]
]

scenario match-at-reflexive [
  run [
    local-scope
    x:text <- new [abc]
    10:boolean/raw <- match-at x, x, 0
  ]
  memory-should-contain [
    10 <- 1  # match found
  ]
]

scenario match-at-outside-bounds [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [a]
    10:boolean/raw <- match-at x, y, 4
  ]
  memory-should-contain [
    10 <- 0  # never matches
  ]
]

scenario match-at-empty-pattern [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new []
    10:boolean/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 1  # always matches empty pattern given a valid index
  ]
]

scenario match-at-empty-pattern-outside-bound [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new []
    10:boolean/raw <- match-at x, y, 4
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

scenario match-at-empty-text [
  run [
    local-scope
    x:text <- new []
    y:text <- new [abc]
    10:boolean/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

scenario match-at-empty-against-empty [
  run [
    local-scope
    x:text <- new []
    10:boolean/raw <- match-at x, x, 0
  ]
  memory-should-contain [
    10 <- 1  # matches because pattern is also empty
  ]
]

scenario match-at-inside-bounds [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [bc]
    10:boolean/raw <- match-at x, y, 1
  ]
  memory-should-contain [
    10 <- 1  # match
  ]
]

scenario match-at-inside-bounds-2 [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- new [bc]
    10:boolean/raw <- match-at x, y, 0
  ]
  memory-should-contain [
    10 <- 0  # no match
  ]
]

def split s:text, delim:character -> result:address:array:text [
  local-scope
  load-ingredients
  # empty text? return empty array
  len:number <- length *s
  {
    empty?:boolean <- equal len, 0
    break-unless empty?
    result <- new {(address array character): type}, 0
    return
  }
  # count #pieces we need room for
  count:number <- copy 1  # n delimiters = n+1 pieces
  idx:number <- copy 0
  {
    idx <- find-next s, delim, idx
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    idx <- add idx, 1
    count <- add count, 1
    loop
  }
  # allocate space
  result <- new {(address array character): type}, count
  # repeatedly copy slices start..end until delimiter into result[curr-result]
  curr-result:number <- copy 0
  start:number <- copy 0
  {
    # while next delim exists
    done?:boolean <- greater-or-equal start, len
    break-if done?
    end:number <- find-next s, delim, start
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
  run [
    local-scope
    x:text <- new [a/b]
    y:address:array:text <- split x, 47/slash
    10:number/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    20:array:character/raw <- copy *a
    30:array:character/raw <- copy *b
  ]
  memory-should-contain [
    10 <- 2  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
  ]
]

scenario text-split-2 [
  run [
    local-scope
    x:text <- new [a/b/c]
    y:address:array:text <- split x, 47/slash
    10:number/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    c:text <- index *y, 2
    20:array:character/raw <- copy *a
    30:array:character/raw <- copy *b
    40:array:character/raw <- copy *c
  ]
  memory-should-contain [
    10 <- 3  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
    40:array:character <- [c]
  ]
]

scenario text-split-missing [
  run [
    local-scope
    x:text <- new [abc]
    y:address:array:text <- split x, 47/slash
    10:number/raw <- length *y
    a:text <- index *y, 0
    20:array:character/raw <- copy *a
  ]
  memory-should-contain [
    10 <- 1  # length of result
    20:array:character <- [abc]
  ]
]

scenario text-split-empty [
  run [
    local-scope
    x:text <- new []
    y:address:array:text <- split x, 47/slash
    10:number/raw <- length *y
  ]
  memory-should-contain [
    10 <- 0  # empty result
  ]
]

scenario text-split-empty-piece [
  run [
    local-scope
    x:text <- new [a/b//c]
    y:address:array:text <- split x:text, 47/slash
    10:number/raw <- length *y
    a:text <- index *y, 0
    b:text <- index *y, 1
    c:text <- index *y, 2
    d:text <- index *y, 3
    20:array:character/raw <- copy *a
    30:array:character/raw <- copy *b
    40:array:character/raw <- copy *c
    50:array:character/raw <- copy *d
  ]
  memory-should-contain [
    10 <- 4  # length of result
    20:array:character <- [a]
    30:array:character <- [b]
    40:array:character <- []
    50:array:character <- [c]
  ]
]

def split-first text:text, delim:character -> x:text, y:text [
  local-scope
  load-ingredients
  # empty text? return empty texts
  len:number <- length *text
  {
    empty?:boolean <- equal len, 0
    break-unless empty?
    x:text <- new []
    y:text <- new []
    return
  }
  idx:number <- find-next text, delim, 0
  x:text <- copy-range text, 0, idx
  idx <- add idx, 1
  y:text <- copy-range text, idx, len
]

scenario text-split-first [
  run [
    local-scope
    x:text <- new [a/b]
    y:text, z:text <- split-first x, 47/slash
    10:array:character/raw <- copy *y
    20:array:character/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [a]
    20:array:character <- [b]
  ]
]

def copy-range buf:text, start:number, end:number -> result:text [
  local-scope
  load-ingredients
  # if end is out of bounds, trim it
  len:number <- length *buf
  end:number <- min len, end
  # allocate space for result
  len <- subtract end, start
  result:text <- new character:type, len
  # copy start..end into result[curr-result]
  src-idx:number <- copy start
  dest-idx:number <- copy 0
  {
    done?:boolean <- greater-or-equal src-idx, end
    break-if done?
    src:character <- index *buf, src-idx
    *result <- put-index *result, dest-idx, src
    src-idx <- add src-idx, 1
    dest-idx <- add dest-idx, 1
    loop
  }
]

scenario text-copy-copies-partial-text [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- copy-range x, 1, 3
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [bc]
  ]
]

scenario text-copy-out-of-bounds [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- copy-range x, 2, 4
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- [c]
  ]
]

scenario text-copy-out-of-bounds-2 [
  run [
    local-scope
    x:text <- new [abc]
    y:text <- copy-range x, 3, 3
    1:array:character/raw <- copy *y
  ]
  memory-should-contain [
    1:array:character <- []
  ]
]
