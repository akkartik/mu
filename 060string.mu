# Some useful helpers for dealing with strings.

recipe string-equal [
  local-scope
  a:address:array:character <- next-ingredient
  a-len:number <- length *a
  b:address:array:character <- next-ingredient
  b-len:number <- length *b
  # compare lengths
  {
    trace [string-equal], [comparing lengths]
    length-equal?:boolean <- equal a-len, b-len
    break-if length-equal?
    reply 0
  }
  # compare each corresponding character
  trace [string-equal], [comparing characters]
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, a-len
    break-if done?
    a2:character <- index *a, i
    b2:character <- index *b, i
    {
      chars-match?:boolean <- equal a2, b2
      break-if chars-match?
      reply 0
    }
    i <- add i, 1
    loop
  }
  reply 1
]

scenario string-equal-reflexive [
  run [
    default-space:address:array:location <- new location:type, 30
    x:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x, x
  ]
  memory-should-contain [
    3 <- 1  # x == x for all x
  ]
]

scenario string-equal-identical [
  run [
    default-space:address:array:location <- new location:type, 30
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x, y
  ]
  memory-should-contain [
    3 <- 1  # abc == abc
  ]
]

scenario string-equal-distinct-lengths [
  run [
    default-space:address:array:location <- new location:type, 30
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x, y
  ]
  memory-should-contain [
    3 <- 0  # abc != abcd
  ]
  trace-should-contain [
    string-equal: comparing lengths
  ]
  trace-should-not-contain [
    string-equal: comparing characters
  ]
]

scenario string-equal-with-empty [
  run [
    default-space:address:array:location <- new location:type, 30
    x:address:array:character <- new []
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x, y
  ]
  memory-should-contain [
    3 <- 0  # "" != abcd
  ]
]

scenario string-equal-common-lengths-but-distinct [
  run [
    default-space:address:array:location <- new location:type, 30
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abd]
    3:boolean/raw <- string-equal x, y
  ]
  memory-should-contain [
    3 <- 0  # abc != abd
  ]
]

# A new type to help incrementally construct strings.
container buffer [
  length:number
  data:address:array:character
]

recipe new-buffer [
  local-scope
#?   $print default-space:address:array:location, 10/newline
  result:address:buffer <- new buffer:type
  len:address:number <- get-address *result, length:offset
  *len:address:number <- copy 0
  s:address:address:array:character <- get-address *result, data:offset
  capacity:number, found?:boolean <- next-ingredient
  assert found?, [new-buffer must get a capacity argument]
  *s <- new character:type, capacity
#?   $print *s, 10/newline
  reply result
]

recipe grow-buffer [
  local-scope
  in:address:buffer <- next-ingredient
  # double buffer size
  x:address:address:array:character <- get-address *in, data:offset
  oldlen:number <- length **x
  newlen:number <- multiply oldlen, 2
  olddata:address:array:character <- copy *x
  *x <- new character:type, newlen
  # copy old contents
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, oldlen
    break-if done?
    src:character <- index *olddata, i
    dest:address:character <- index-address **x, i
    *dest <- copy src
    i <- add i, 1
    loop
  }
  reply in
]

recipe buffer-full? [
  local-scope
  in:address:buffer <- next-ingredient
  len:number <- get *in, length:offset
  s:address:array:character <- get *in, data:offset
  capacity:number <- length *s
  result:boolean <- greater-or-equal len, capacity
  reply result
]

# in:address:buffer <- buffer-append in:address:buffer, c:character
recipe buffer-append [
  local-scope
  in:address:buffer <- next-ingredient
  c:character <- next-ingredient
  len:address:number <- get-address *in, length:offset
  {
    # backspace? just drop last character if it exists and return
    backspace?:boolean <- equal c, 8/backspace
    break-unless backspace?
    empty?:boolean <- lesser-or-equal *len, 0
    reply-if empty?, in/same-as-ingredient:0
    *len <- subtract *len, 1
    reply in/same-as-ingredient:0
  }
  {
    # grow buffer if necessary
    full?:boolean <- buffer-full? in
    break-unless full?
    in <- grow-buffer in
  }
  s:address:array:character <- get *in, data:offset
#?   $print [array underlying buf: ], s, 10/newline
#?   $print [index: ], *len, 10/newline
  dest:address:character <- index-address *s, *len
#?   $print [storing ], c, [ in ], dest, 10/newline
  *dest <- copy c
  *len <- add *len, 1
  reply in/same-as-ingredient:0
]

scenario buffer-append-works [
  run [
    local-scope
    x:address:buffer <- new-buffer 3
    s1:address:array:character <- get *x:address:buffer, data:offset
    x:address:buffer <- buffer-append x:address:buffer, 97  # 'a'
    x:address:buffer <- buffer-append x:address:buffer, 98  # 'b'
    x:address:buffer <- buffer-append x:address:buffer, 99  # 'c'
    s2:address:array:character <- get *x:address:buffer, data:offset
    1:boolean/raw <- equal s1:address:array:character, s2:address:array:character
    2:array:character/raw <- copy *s2:address:array:character
    +buffer-filled
    x:address:buffer <- buffer-append x:address:buffer, 100  # 'd'
    s3:address:array:character <- get *x:address:buffer, data:offset
    10:boolean/raw <- equal s1:address:array:character, s3:address:array:character
    11:number/raw <- get *x:address:buffer, length:offset
    12:array:character/raw <- copy *s3:address:array:character
  ]
  memory-should-contain [
    # before +buffer-filled
    1 <- 1   # no change in data pointer
    2 <- 3   # size of data
    3 <- 97  # data
    4 <- 98
    5 <- 99
    # in the end
    10 <- 0   # data pointer has grown
    11 <- 4   # final length
    12 <- 6   # but data's capacity has doubled
    13 <- 97  # data
    14 <- 98
    15 <- 99
    16 <- 100
    17 <- 0
    18 <- 0
  ]
]

scenario buffer-append-handles-backspace [
  run [
    local-scope
    x:address:buffer <- new-buffer 3
    x:address:buffer <- buffer-append x:address:buffer, 97  # 'a'
    x:address:buffer <- buffer-append x:address:buffer, 98  # 'b'
    x:address:buffer <- buffer-append x:address:buffer, 8/backspace
    s:address:array:character <- buffer-to-array x:address:buffer
    1:array:character/raw <- copy *s:address:array:character
  ]
  memory-should-contain [
    1 <- 1   # length
    2 <- 97  # contents
    3 <- 0
  ]
]

# result:address:array:character <- integer-to-decimal-string n:number
recipe integer-to-decimal-string [
  local-scope
  n:number <- next-ingredient
  # is it zero?
  {
    break-if n
    result:address:array:character <- new [0]
    reply result
  }
  # save sign
  negate-result:boolean <- copy 0
  {
    negative?:boolean <- lesser-than n, 0
    break-unless negative?
    negate-result <- copy 1
    n <- multiply n, -1
  }
  # add digits from right to left into intermediate buffer
  tmp:address:buffer <- new-buffer 30
  digit-base:number <- copy 48  # '0'
  {
    done?:boolean <- equal n, 0
    break-if done?
    n, digit:number <- divide-with-remainder n, 10
    c:character <- add digit-base, digit
    tmp:address:buffer <- buffer-append tmp, c
    loop
  }
  # add sign
  {
    break-unless negate-result:boolean
    tmp <- buffer-append tmp, 45  # '-'
  }
  # reverse buffer into string result
  len:number <- get *tmp, length:offset
  buf:address:array:character <- get *tmp, data:offset
  result:address:array:character <- new character:type, len
  i:number <- subtract len, 1  # source index, decreasing
  j:number <- copy 0  # destination index, increasing
  {
    # while i >= 0
    done?:boolean <- lesser-than i, 0
    break-if done?
    # result[j] = tmp[i]
    src:character <- index *buf, i
    dest:address:character <- index-address *result, j
    *dest <- copy src
    i <- subtract i, 1
    j <- add j, 1
    loop
  }
  reply result
]

recipe buffer-to-array [
  local-scope
  in:address:buffer <- next-ingredient
  {
    # propagate null buffer
    break-if in
    reply 0
  }
  len:number <- get *in, length:offset
#?   $print [size ], len, 10/newline
  s:address:array:character <- get *in, data:offset
  # we can't just return s because it is usually the wrong length
  result:address:array:character <- new character:type, len
  i:number <- copy 0
  {
#?     $print i #? 1
    done?:boolean <- greater-or-equal i, len
    break-if done?
    src:character <- index *s, i
    dest:address:character <- index-address *result, i
    *dest <- copy src
    i <- add i, 1
    loop
  }
  reply result
]

scenario integer-to-decimal-digit-zero [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 0
    2:array:character/raw <- copy *1:address:array:character/raw
  ]
  memory-should-contain [
    2:string <- [0]
  ]
]

scenario integer-to-decimal-digit-positive [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 234
    2:array:character/raw <- copy *1:address:array:character/raw
  ]
  memory-should-contain [
    2:string <- [234]
  ]
]

scenario integer-to-decimal-digit-negative [
  run [
    1:address:array:character/raw <- integer-to-decimal-string -1
    2:array:character/raw <- copy *1:address:array:character/raw
  ]
  memory-should-contain [
    2 <- 2
    3 <- 45  # '-'
    4 <- 49  # '1'
  ]
]

# result:address:array:character <- string-append a:address:array:character, b:address:array:character
recipe string-append [
  local-scope
  # result = new character[a.length + b.length]
  a:address:array:character <- next-ingredient
  a-len:number <- length *a
  b:address:array:character <- next-ingredient
  b-len:number <- length *b
  result-len:number <- add a-len, b-len
  result:address:array:character <- new character:type, result-len
  # copy a into result
  result-idx:number <- copy 0
  i:number <- copy 0
  {
    # while i < a.length
    a-done?:boolean <- greater-or-equal i, a-len
    break-if a-done?
    # result[result-idx] = a[i]
    out:address:character <- index-address *result, result-idx
    in:character <- index *a, i
    *out <- copy in
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
    out:address:character <- index-address *result, result-idx
    in:character <- index *b, i
    *out <- copy in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
  reply result
]

scenario string-append-1 [
  run [
    1:address:array:character/raw <- new [hello,]
    2:address:array:character/raw <- new [ world!]
    3:address:array:character/raw <- string-append 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy *3:address:array:character/raw
  ]
  memory-should-contain [
    4:string <- [hello, world!]
  ]
]

# replace underscores in first with remaining args
# result:address:array:character <- interpolate template:address:array:character, ...
recipe interpolate [
  local-scope
  template:address:array:character <- next-ingredient
  # compute result-len, space to allocate for result
  tem-len:number <- length *template
  result-len:number <- copy tem-len
  {
    # while arg received
    a:address:array:character, arg-received?:boolean <- next-ingredient
    break-unless arg-received?
    # result-len = result-len + arg.length - 1 (for the 'underscore' being replaced)
    a-len:number <- length *a
    result-len <- add result-len, a-len
    result-len <- subtract result-len, 1
    loop
  }
#?   $print tem-len, [ ], $result-len, 10/newline
  rewind-ingredients
  _ <- next-ingredient  # skip template
  result:address:array:character <- new character:type, result-len
  # repeatedly copy sections of template and 'holes' into result
  result-idx:number <- copy 0
  i:number <- copy 0
  {
    # while arg received
    a:address:array:character, arg-received?:boolean <- next-ingredient
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
      out:address:character <- index-address *result, result-idx
      *out <- copy in
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
      out:address:character <- index-address *result, result-idx
      *out <- copy in
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
    out:address:character <- index-address *result, result-idx:number
    *out <- copy in
    i <- add i, 1
    result-idx <- add result-idx, 1
    loop
  }
  reply result
]

scenario interpolate-works [
#?   dump run #? 1
  run [
    1:address:array:character/raw <- new [abc _]
    2:address:array:character/raw <- new [def]
    3:address:array:character/raw <- interpolate 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy *3:address:array:character/raw
  ]
  memory-should-contain [
    4:string <- [abc def]
  ]
]

scenario interpolate-at-start [
  run [
    1:address:array:character/raw <- new [_, hello!]
    2:address:array:character/raw <- new [abc]
    3:address:array:character/raw <- interpolate 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy *3:address:array:character/raw
  ]
  memory-should-contain [
    4:string <- [abc, hello!]
    16 <- 0  # out of bounds
  ]
]

scenario interpolate-at-end [
  run [
    1:address:array:character/raw <- new [hello, _]
    2:address:array:character/raw <- new [abc]
    3:address:array:character/raw <- interpolate 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy *3:address:array:character/raw
  ]
  memory-should-contain [
    4:string <- [hello, abc]
  ]
]

# result:boolean <- space? c:character
recipe space? [
  local-scope
  c:character <- next-ingredient
  # most common case first
  result:boolean <- equal c, 32/space
  jump-if result +reply:label
  result <- equal c, 10/newline
  jump-if result, +reply:label
  result <- equal c, 9/tab
  jump-if result, +reply:label
  result <- equal c, 13/carriage-return
  jump-if result, +reply:label
  # remaining uncommon cases in sorted order
  # http://unicode.org code-points in unicode-set Z and Pattern_White_Space
  result <- equal c, 11/ctrl-k
  jump-if result, +reply:label
  result <- equal c, 12/ctrl-l
  jump-if result, +reply:label
  result <- equal c, 133/ctrl-0085
  jump-if result, +reply:label
  result <- equal c, 160/no-break-space
  jump-if result, +reply:label
  result <- equal c, 5760/ogham-space-mark
  jump-if result, +reply:label
  result <- equal c, 8192/en-quad
  jump-if result, +reply:label
  result <- equal c, 8193/em-quad
  jump-if result, +reply:label
  result <- equal c, 8194/en-space
  jump-if result, +reply:label
  result <- equal c, 8195/em-space
  jump-if result, +reply:label
  result <- equal c, 8196/three-per-em-space
  jump-if result, +reply:label
  result <- equal c, 8197/four-per-em-space
  jump-if result, +reply:label
  result <- equal c, 8198/six-per-em-space
  jump-if result, +reply:label
  result <- equal c, 8199/figure-space
  jump-if result, +reply:label
  result <- equal c, 8200/punctuation-space
  jump-if result, +reply:label
  result <- equal c, 8201/thin-space
  jump-if result, +reply:label
  result <- equal c, 8202/hair-space
  jump-if result, +reply:label
  result <- equal c, 8206/left-to-right
  jump-if result, +reply:label
  result <- equal c, 8207/right-to-left
  jump-if result, +reply:label
  result <- equal c, 8232/line-separator
  jump-if result, +reply:label
  result <- equal c, 8233/paragraph-separator
  jump-if result, +reply:label
  result <- equal c, 8239/narrow-no-break-space
  jump-if result, +reply:label
  result <- equal c, 8287/medium-mathematical-space
  jump-if result, +reply:label
  result <- equal c, 12288/ideographic-space
  jump-if result, +reply:label
  +reply
  reply result
]

# result:address:array:character <- trim s:address:array:character
recipe trim [
  local-scope
  s:address:array:character <- next-ingredient
  len:number <- length *s
  # left trim: compute start
  start:number <- copy 0
  {
    {
      at-end?:boolean <- greater-or-equal start, len
      break-unless at-end?
      result:address:array:character <- new character:type, 0
      reply result
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
  result:address:array:character <- new character:type, new-len
  # i = start, j = 0
  i:number <- copy start
  j:number <- copy 0
  {
    # while i <= end
    done?:boolean <- greater-than i, end
    break-if done?
    # result[j] = s[i]
    src:character <- index *s, i
    dest:address:character <- index-address *result, j
    *dest <- copy src
    i <- add i, 1
    j <- add j, 1
    loop
  }
  reply result
]

scenario trim-unmodified [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-left [
  run [
    1:address:array:character <- new [  abc]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-right [
  run [
    1:address:array:character <- new [abc  ]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-left-right [
  run [
    1:address:array:character <- new [  abc   ]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-newline-tab [
  run [
    1:address:array:character <- new [	abc
]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

# next-index:number <- find-next text:address:array:character, pattern:character, idx:number
recipe find-next [
  local-scope
  text:address:array:character <- next-ingredient
  pattern:character <- next-ingredient
  idx:number <- next-ingredient
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
  reply idx
]

scenario string-find-next [
  run [
    1:address:array:character <- new [a/b]
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 1
  ]
]

scenario string-find-next-empty [
  run [
    1:address:array:character <- new []
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 0
  ]
]

scenario string-find-next-initial [
  run [
    1:address:array:character <- new [/abc]
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 0  # prefix match
  ]
]

scenario string-find-next-final [
  run [
    1:address:array:character <- new [abc/]
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 3  # suffix match
  ]
]

scenario string-find-next-missing [
  run [
    1:address:array:character <- new [abc]
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 3  # no match
  ]
]

scenario string-find-next-invalid-index [
  run [
    1:address:array:character <- new [abc]
    2:number <- find-next 1:address:array:character, 47/slash, 4/start-index
  ]
  memory-should-contain [
    2 <- 4  # no change
  ]
]

scenario string-find-next-first [
  run [
    1:address:array:character <- new [ab/c/]
    2:number <- find-next 1:address:array:character, 47/slash, 0/start-index
  ]
  memory-should-contain [
    2 <- 2  # first '/' of multiple
  ]
]

scenario string-find-next-second [
  run [
    1:address:array:character <- new [ab/c/]
    2:number <- find-next 1:address:array:character, 47/slash, 3/start-index
  ]
  memory-should-contain [
    2 <- 4  # second '/' of multiple
  ]
]

# idx:number <- find-substring text:address:array:character, pattern:address:array:character, idx:number
# like find-next, but searches for multiple characters
# fairly dumb algorithm
recipe find-substring [
  local-scope
  text:address:array:character <- next-ingredient
  pattern:address:array:character <- next-ingredient
  idx:number <- next-ingredient
  first:character <- index *pattern, 0
  # repeatedly check for match at current idx
  len:number <- length *text
  {
    # does some unnecessary work checking for substrings even when there isn't enough of text left
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    found?:boolean <- match-at text, pattern, idx
    break-if found?
    idx <- add idx, 1
    # optimization: skip past indices that definitely won't match
    idx <- find-next text, first, idx
    loop
  }
  reply idx
]

scenario find-substring-1 [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [bc]
    3:number <- find-substring 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 1
  ]
]

scenario find-substring-2 [
  run [
    1:address:array:character <- new [abcd]
    2:address:array:character <- new [bc]
    3:number <- find-substring 1:address:array:character, 2:address:array:character, 1
  ]
  memory-should-contain [
    3 <- 1
  ]
]

scenario find-substring-no-match [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [bd]
    3:number <- find-substring 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 3  # not found
  ]
]

scenario find-substring-suffix-match [
  run [
    1:address:array:character <- new [abcd]
    2:address:array:character <- new [cd]
    3:number <- find-substring 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 2
  ]
]

scenario find-substring-suffix-match-2 [
  run [
    1:address:array:character <- new [abcd]
    2:address:array:character <- new [cde]
    3:number <- find-substring 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 4  # not found
  ]
]

# result:boolean <- match-at text:address:array:character, pattern:address:array:character, idx:number
# checks if substring matches at index 'idx'
recipe match-at [
  local-scope
  text:address:array:character <- next-ingredient
  pattern:address:array:character <- next-ingredient
  idx:number <- next-ingredient
  pattern-len:number <- length *pattern
  # check that there's space left for the pattern
  {
    x:number <- length *text
    x <- subtract x, pattern-len
    enough-room?:boolean <- lesser-or-equal idx, x
    break-if enough-room?
    reply 0/not-found
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
      reply 0/not-found
    }
    idx <- add idx, 1
    pattern-idx <- add pattern-idx, 1
    loop
  }
  reply 1/found
]

scenario match-at-checks-substring-at-index [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [ab]
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 1  # match found
  ]
]

scenario match-at-reflexive [
  run [
    1:address:array:character <- new [abc]
    3:boolean <- match-at 1:address:array:character, 1:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 1  # match found
  ]
]

scenario match-at-outside-bounds [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [a]
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 4
  ]
  memory-should-contain [
    3 <- 0  # never matches
  ]
]

scenario match-at-empty-pattern [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new []
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 1  # always matches empty pattern given a valid index
  ]
]

scenario match-at-empty-pattern-outside-bound [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new []
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 4
  ]
  memory-should-contain [
    3 <- 0  # no match
  ]
]

scenario match-at-empty-text [
  run [
    1:address:array:character <- new []
    2:address:array:character <- new [abc]
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 0  # no match
  ]
]

scenario match-at-empty-against-empty [
  run [
    1:address:array:character <- new []
    3:boolean <- match-at 1:address:array:character, 1:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 1  # matches because pattern is also empty
  ]
]

scenario match-at-inside-bounds [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [bc]
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 1
  ]
  memory-should-contain [
    3 <- 1  # matches inner substring
  ]
]

scenario match-at-inside-bounds-2 [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [bc]
    3:boolean <- match-at 1:address:array:character, 2:address:array:character, 0
  ]
  memory-should-contain [
    3 <- 0  # no match
  ]
]

# result:address:array:address:array:character <- split s:address:array:character, delim:character
recipe split [
  local-scope
  s:address:array:character <- next-ingredient
  delim:character <- next-ingredient
  # empty string? return empty array
  len:number <- length *s
  {
    empty?:boolean <- equal len, 0
    break-unless empty?
    result:address:array:address:array:character <- new location:type, 0
    reply result
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
  result:address:array:address:array:character <- new location:type, count
  # repeatedly copy slices start..end until delimiter into result[curr-result]
  curr-result:number <- copy 0
  start:number <- copy 0
  {
    # while next delim exists
    done?:boolean <- greater-or-equal start, len
    break-if done?
    end:number <- find-next s, delim, start
    # copy start..end into result[curr-result]
    dest:address:address:array:character <- index-address *result, curr-result
    *dest <- string-copy s, start, end
    # slide over to next slice
    start <- add end, 1
    curr-result <- add curr-result, 1
    loop
  }
  reply result
]

scenario string-split-1 [
  run [
    1:address:array:character <- new [a/b]
    2:address:array:address:array:character <- split 1:address:array:character, 47/slash
    3:number <- length *2:address:array:address:array:character
    4:address:array:character <- index *2:address:array:address:array:character, 0
    5:address:array:character <- index *2:address:array:address:array:character, 1
    10:array:character <- copy *4:address:array:character
    20:array:character <- copy *5:address:array:character
  ]
  memory-should-contain [
    3 <- 2  # length of result
    10:string <- [a]
    20:string <- [b]
  ]
]

scenario string-split-2 [
  run [
    1:address:array:character <- new [a/b/c]
    2:address:array:address:array:character <- split 1:address:array:character, 47/slash
    3:number <- length *2:address:array:address:array:character
    4:address:array:character <- index *2:address:array:address:array:character, 0
    5:address:array:character <- index *2:address:array:address:array:character, 1
    6:address:array:character <- index *2:address:array:address:array:character, 2
    10:array:character <- copy *4:address:array:character
    20:array:character <- copy *5:address:array:character
    30:array:character <- copy *6:address:array:character
  ]
  memory-should-contain [
    3 <- 3  # length of result
    10:string <- [a]
    20:string <- [b]
    30:string <- [c]
  ]
]

scenario string-split-missing [
  run [
    1:address:array:character <- new [abc]
    2:address:array:address:array:character <- split 1:address:array:character, 47/slash
    3:number <- length *2:address:array:address:array:character
    4:address:array:character <- index *2:address:array:address:array:character, 0
    10:array:character <- copy *4:address:array:character
  ]
  memory-should-contain [
    3 <- 1  # length of result
    10:string <- [abc]
  ]
]

scenario string-split-empty [
  run [
    1:address:array:character <- new []
    2:address:array:address:array:character <- split 1:address:array:character, 47/slash
    3:number <- length *2:address:array:address:array:character
  ]
  memory-should-contain [
    3 <- 0  # empty result
  ]
]

scenario string-split-empty-piece [
  run [
    1:address:array:character <- new [a/b//c]
    2:address:array:address:array:character <- split 1:address:array:character, 47/slash
    3:number <- length *2:address:array:address:array:character
    4:address:array:character <- index *2:address:array:address:array:character, 0
    5:address:array:character <- index *2:address:array:address:array:character, 1
    6:address:array:character <- index *2:address:array:address:array:character, 2
    7:address:array:character <- index *2:address:array:address:array:character, 3
    10:array:character <- copy *4:address:array:character
    20:array:character <- copy *5:address:array:character
    30:array:character <- copy *6:address:array:character
    40:array:character <- copy *7:address:array:character
  ]
  memory-should-contain [
    3 <- 4  # length of result
    10:string <- [a]
    20:string <- [b]
    30:string <- []
    40:string <- [c]
  ]
]

# x:address:array:character, y:address:array:character <- split-first text:address:array:character, delim:character
recipe split-first [
  local-scope
  text:address:array:character <- next-ingredient
  delim:character <- next-ingredient
  # empty string? return empty strings
  len:number <- length *text
  {
    empty?:boolean <- equal len, 0
    break-unless empty?
    x:address:array:character <- new []
    y:address:array:character <- new []
    reply x, y
  }
  idx:number <- find-next text, delim, 0
  x:address:array:character <- string-copy text, 0, idx
  idx <- add idx, 1
  y:address:array:character <- string-copy text, idx, len
  reply x, y
]

scenario string-split-first [
  run [
    1:address:array:character <- new [a/b]
    2:address:array:character, 3:address:array:character <- split-first 1:address:array:character, 47/slash
    10:array:character <- copy *2:address:array:character
    20:array:character <- copy *3:address:array:character
  ]
  memory-should-contain [
    10:string <- [a]
    20:string <- [b]
  ]
]

# result:address:array:character <- string-copy buf:address:array:character, start:number, end:number
# todo: make this generic
recipe string-copy [
  local-scope
  buf:address:array:character <- next-ingredient
  start:number <- next-ingredient
  end:number <- next-ingredient
  # if end is out of bounds, trim it
  len:number <- length *buf
  end:number <- min len, end
  # allocate space for result
  len <- subtract end, start
  result:address:array:character <- new character:type, len
  # copy start..end into result[curr-result]
  src-idx:number <- copy start
  dest-idx:number <- copy 0
  {
    done?:boolean <- greater-or-equal src-idx, end
    break-if done?
    src:character <- index *buf, src-idx
    dest:address:character <- index-address *result, dest-idx
    *dest <- copy src
    src-idx <- add src-idx, 1
    dest-idx <- add dest-idx, 1
    loop
  }
  reply result
]

scenario string-copy-copies-substring [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- string-copy 1:address:array:character, 1, 3
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [bc]
  ]
]

scenario string-copy-out-of-bounds [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- string-copy 1:address:array:character, 2, 4
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- [c]
  ]
]

scenario string-copy-out-of-bounds-2 [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- string-copy 1:address:array:character, 3, 3
    3:array:character <- copy *2:address:array:character
  ]
  memory-should-contain [
    3:string <- []
  ]
]

recipe min [
  local-scope
  x:number <- next-ingredient
  y:number <- next-ingredient
  {
    return-x?:boolean <- lesser-than x, y
    break-if return-x?
    reply y
  }
  reply x
]

recipe max [
  local-scope
  x:number <- next-ingredient
  y:number <- next-ingredient
  {
    return-x?:boolean <- greater-than x, y
    break-if return-x?
    reply y
  }
  reply x
]
