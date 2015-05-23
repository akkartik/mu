# Some useful helpers for dealing with strings.

recipe string-equal [
  default-space:address:array:location <- new location:type, 30:literal
  a:address:array:character <- next-ingredient
  a-len:number <- length a:address:array:character/deref
  b:address:array:character <- next-ingredient
  b-len:number <- length b:address:array:character/deref
  # compare lengths
  {
    trace [string-equal], [comparing lengths]
    length-equal?:boolean <- equal a-len:number, b-len:number
    break-if length-equal?:boolean
    reply 0:literal
  }
  # compare each corresponding character
  trace [string-equal], [comparing characters]
  i:number <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:number, a-len:number
    break-if done?:boolean
    a2:character <- index a:address:array:character/deref, i:number
    b2:character <- index b:address:array:character/deref, i:number
    {
      chars-match?:boolean <- equal a2:character, b2:character
      break-if chars-match?:boolean
      reply 0:literal
    }
    i:number <- add i:number, 1:literal
    loop
  }
  reply 1:literal
]

scenario string-equal-reflexive [
  run [
    default-space:address:array:location <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x:address:array:character, x:address:array:character
  ]
  memory-should-contain [
    3 <- 1  # x == x for all x
  ]
]

scenario string-equal-identical [
  run [
    default-space:address:array:location <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory-should-contain [
    3 <- 1  # abc == abc
  ]
]

scenario string-equal-distinct-lengths [
  run [
    default-space:address:array:location <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
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
    default-space:address:array:location <- new location:type, 30:literal
    x:address:array:character <- new []
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory-should-contain [
    3 <- 0  # "" != abcd
  ]
]

scenario string-equal-common-lengths-but-distinct [
  run [
    default-space:address:array:location <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
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

recipe init-buffer [
  default-space:address:array:location <- new location:type, 30:literal
#?   $print default-space:address:array:location, [
#? ]
  result:address:buffer <- new buffer:type
  len:address:number <- get-address result:address:buffer/deref, length:offset
  len:address:number/deref <- copy 0:literal
  s:address:address:array:character <- get-address result:address:buffer/deref, data:offset
  capacity:number <- next-ingredient
  s:address:address:array:character/deref <- new character:type, capacity:number
#?   $print s:address:address:array:character/deref, [
#? ]
  reply result:address:buffer
]

recipe grow-buffer [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  # double buffer size
  x:address:address:array:character <- get-address in:address:buffer/deref, data:offset
  oldlen:number <- length x:address:address:array:character/deref/deref
  newlen:number <- multiply oldlen:number, 2:literal
  olddata:address:array:character <- copy x:address:address:array:character/deref
  x:address:address:array:character/deref <- new character:type, newlen:number
  # copy old contents
  i:number <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:number, oldlen:number
    break-if done?:boolean
    src:character <- index olddata:address:array:character/deref, i:number
    dest:address:character <- index-address x:address:address:array:character/deref/deref, i:number
    dest:address:character/deref <- copy src:character
    i:number <- add i:number, 1:literal
    loop
  }
  reply in:address:buffer
]

recipe buffer-full? [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  len:number <- get in:address:buffer/deref, length:offset
  s:address:array:character <- get in:address:buffer/deref, data:offset
  capacity:number <- length s:address:array:character/deref
  result:boolean <- greater-or-equal len:number, capacity:number
  reply result:boolean
]

# in:address:buffer <- buffer-append in:address:buffer, c:character
recipe buffer-append [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  c:character <- next-ingredient
  {
    # grow buffer if necessary
    full?:boolean <- buffer-full? in:address:buffer
    break-unless full?:boolean
    in:address:buffer <- grow-buffer in:address:buffer
  }
  len:address:number <- get-address in:address:buffer/deref, length:offset
  s:address:array:character <- get in:address:buffer/deref, data:offset
  dest:address:character <- index-address s:address:array:character/deref, len:address:number/deref
  dest:address:character/deref <- copy c:character
  len:address:number/deref <- add len:address:number/deref, 1:literal
  reply in:address:buffer/same-as-ingredient:0
]

scenario buffer-append-works [
  run [
    default-space:address:array:location <- new location:type, 30:literal
    x:address:buffer <- init-buffer 3:literal
    s1:address:array:character <- get x:address:buffer/deref, data:offset
    x:address:buffer <- buffer-append x:address:buffer, 97:literal  # 'a'
    x:address:buffer <- buffer-append x:address:buffer, 98:literal  # 'b'
    x:address:buffer <- buffer-append x:address:buffer, 99:literal  # 'c'
    s2:address:array:character <- get x:address:buffer/deref, data:offset
    1:boolean/raw <- equal s1:address:array:character, s2:address:array:character
#?     $print s2:address:array:character, [
#? ]
#?     $print 1060:number/raw, [
#? ]
#?     $print 1061:number/raw, [
#? ]
#?     $print 1062:number/raw, [
#? ]
#?     $print 1063:number/raw, [
#? ]
#?     $print 1064:number/raw, [
#? ]
#?     $print 1065:number/raw, [
#? ]
    2:array:character/raw <- copy s2:address:array:character/deref
    +buffer-filled
    x:address:buffer <- buffer-append x:address:buffer, 100:literal  # 'd'
    s3:address:array:character <- get x:address:buffer/deref, data:offset
    10:boolean/raw <- equal s1:address:array:character, s3:address:array:character
    11:number/raw <- get x:address:buffer/deref, length:offset
    12:array:character/raw <- copy s3:address:array:character/deref
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

# result:address:array:character <- integer-to-decimal-string n:number
recipe integer-to-decimal-string [
  default-space:address:array:location <- new location:type, 30:literal
  n:number <- next-ingredient
  # is it zero?
  {
    break-if n:number
    result:address:array:character <- new [0]
    reply result:address:array:character
  }
  # save sign
  negate-result:boolean <- copy 0:literal
  {
    negative?:boolean <- lesser-than n:number, 0:literal
    break-unless negative?:boolean
    negate-result:boolean <- copy 1:literal
    n:number <- multiply n:number, -1:literal
  }
  # add digits from right to left into intermediate buffer
  tmp:address:buffer <- init-buffer 30:literal
  digit-base:number <- copy 48:literal  # '0'
  {
    done?:boolean <- equal n:number, 0:literal
    break-if done?:boolean
    n:number, digit:number <- divide-with-remainder n:number, 10:literal
    c:character <- add digit-base:number, digit:number
    tmp:address:buffer <- buffer-append tmp:address:buffer, c:character
    loop
  }
  # add sign
  {
    break-unless negate-result:boolean
    tmp:address:buffer <- buffer-append tmp:address:buffer, 45:literal  # '-'
  }
  # reverse buffer into string result
  len:number <- get tmp:address:buffer/deref, length:offset
  buf:address:array:character <- get tmp:address:buffer/deref, data:offset
  result:address:array:character <- new character:type, len:number
  i:number <- subtract len:number, 1:literal
  j:number <- copy 0:literal
  {
    # while i >= 0
    done?:boolean <- lesser-than i:number, 0:literal
    break-if done?:boolean
    # result[j] = tmp[i]
    src:character <- index buf:address:array:character/deref, i:number
    dest:address:character <- index-address result:address:array:character/deref, j:number
    dest:address:character/deref <- copy src:character
    # ++i
    i:number <- subtract i:number, 1:literal
    # --j
    j:number <- add j:number, 1:literal
    loop
  }
  reply result:address:array:character
]

scenario integer-to-decimal-digit-zero [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 0:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory-should-contain [
    2:string <- [0]
  ]
]

scenario integer-to-decimal-digit-positive [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 234:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory-should-contain [
    2:string <- [234]
  ]
]

scenario integer-to-decimal-digit-negative [
  run [
    1:address:array:character/raw <- integer-to-decimal-string -1:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory-should-contain [
    2 <- 2
    3 <- 45  # '-'
    4 <- 49  # '1'
  ]
]

recipe string-append [
  default-space:address:array:location <- new location:type, 30:literal
  # result = new string[a.length + b.length]
  a:address:array:character <- next-ingredient
  a-len:number <- length a:address:array:character/deref
  b:address:array:character <- next-ingredient
  b-len:number <- length b:address:array:character/deref
  result-len:number <- add a-len:number, b-len:number
  result:address:array:character <- new character:type, result-len:number
  # copy a into result
  result-idx:number <- copy 0:literal
  i:number <- copy 0:literal
  {
    # while i < a.length
    a-done?:boolean <- greater-or-equal i:number, a-len:number
    break-if a-done?:boolean
    # result[result-idx] = a[i]
    out:address:character <- index-address result:address:array:character/deref, result-idx:number
    in:character <- index a:address:array:character/deref, i:number
    out:address:character/deref <- copy in:character
    # ++i
    i:number <- add i:number, 1:literal
    # ++result-idx
    result-idx:number <- add result-idx:number, 1:literal
    loop
  }
  # copy b into result
  i:number <- copy 0:literal
  {
    # while i < b.length
    b-done?:boolean <- greater-or-equal i:number, b-len:number
    break-if b-done?:boolean
    # result[result-idx] = a[i]
    out:address:character <- index-address result:address:array:character/deref, result-idx:number
    in:character <- index b:address:array:character/deref, i:number
    out:address:character/deref <- copy in:character
    # ++i
    i:number <- add i:number, 1:literal
    # ++result-idx
    result-idx:number <- add result-idx:number, 1:literal
    loop
  }
  reply result:address:array:character
]

scenario string-append-1 [
  run [
    1:address:array:character/raw <- new [hello,]
    2:address:array:character/raw <- new [ world!]
    3:address:array:character/raw <- string-append 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy 3:address:array:character/raw/deref
  ]
  memory-should-contain [
    4:string <- [hello, world!]
  ]
]

# replace underscores in first with remaining args
# result:address:array:character <- interpolate template:address:array:character, ...
recipe interpolate [
  default-space:array:address:location <- new location:type, 60:literal
  template:address:array:character <- next-ingredient
  # compute result-len, space to allocate for result
  tem-len:number <- length template:address:array:character/deref
  result-len:number <- copy tem-len:number
  {
    # while arg received
    a:address:array:character, arg-received?:boolean <- next-ingredient
    break-unless arg-received?:boolean
    # result-len = result-len + arg.length - 1 for the 'underscore' being replaced
    a-len:number <- length a:address:array:character/deref
    result-len:number <- add result-len:number, a-len:number
    result-len:number <- subtract result-len:number, 1:literal
    loop
  }
#?   $print tem-len:number, [ ], $result-len:number, [ 
#? ] #? 1
  rewind-ingredients
  _ <- next-ingredient  # skip template
  # result = new array:character[result-len]
  result:address:array:character <- new character:type, result-len:number
  # repeatedly copy sections of template and 'holes' into result
  result-idx:number <- copy 0:literal
  i:number <- copy 0:literal
  {
    # while arg received
    a:address:array:character, arg-received?:boolean <- next-ingredient
    break-unless arg-received?:boolean
    # copy template into result until '_'
    {
      # while i < template.length
      tem-done?:boolean <- greater-or-equal i:number, tem-len:number
      break-if tem-done?:boolean, +done:label
      # while template[i] != '_'
      in:character <- index template:address:array:character/deref, i:number
      underscore?:boolean <- equal in:character, 95:literal  # '_'
      break-if underscore?:boolean
      # result[result-idx] = template[i]
      out:address:character <- index-address result:address:array:character/deref, result-idx:number
      out:address:character/deref <- copy in:character
      # ++i
      i:number <- add i:number, 1:literal
      # ++result-idx
      result-idx:number <- add result-idx:number, 1:literal
      loop
    }
    # copy 'a' into result
    j:number <- copy 0:literal
    {
      # while j < a.length
      arg-done?:boolean <- greater-or-equal j:number, a-len:number
      break-if arg-done?:boolean
      # result[result-idx] = a[j]
      in:character <- index a:address:array:character/deref, j:number
      out:address:character <- index-address result:address:array:character/deref, result-idx:number
      out:address:character/deref <- copy in:character
      # ++j
      j:number <- add j:number, 1:literal
      # ++result-idx
      result-idx:number <- add result-idx:number, 1:literal
      loop
    }
    # skip '_' in template
    i:number <- add i:number, 1:literal
    loop  # interpolate next arg
  }
  +done
  # done with holes; copy rest of template directly into result
  {
    # while i < template.length
    tem-done?:boolean <- greater-or-equal i:number, tem-len:number
    break-if tem-done?:boolean
    # result[result-idx] = template[i]
    in:character <- index template:address:array:character/deref, i:number
    out:address:character <- index-address result:address:array:character/deref, result-idx:number
    out:address:character/deref <- copy in:character
    # ++i
    i:number <- add i:number, 1:literal
    # ++result-idx
    result-idx:number <- add result-idx:number, 1:literal
    loop
  }
  reply result:address:array:character
]

scenario interpolate-works [
#?   dump run #? 1
  run [
    1:address:array:character/raw <- new [abc _]
    2:address:array:character/raw <- new [def]
    3:address:array:character/raw <- interpolate 1:address:array:character/raw, 2:address:array:character/raw
    4:array:character/raw <- copy 3:address:array:character/raw/deref
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
    4:array:character/raw <- copy 3:address:array:character/raw/deref
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
    4:array:character/raw <- copy 3:address:array:character/raw/deref
  ]
  memory-should-contain [
    4:string <- [hello, abc]
  ]
]

recipe trim [
  default-space:array:address:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  len:number <- length s:address:array:character/deref
  # left trim: compute start
  start:number <- copy 0:literal
  {
    {
      at-end?:boolean <- greater-or-equal start:number, len:number
      break-unless at-end?:boolean
      result:address:array:character <- new character:type, 0:literal
      reply result:address:array:character
    }
    curr:character <- index s:address:array:character/deref, start:number
    whitespace?:boolean <- equal curr:character, 32:literal/space
    break-unless whitespace?:boolean
    start:number <- add start:number, 1:literal
    loop
  }
  # right trim: compute end
  end:number <- subtract len:number, 1:literal
  {
    not-at-start?:boolean <- greater-than end:number, start:number
    assert not-at-start?:boolean [end ran up against start]
    curr:character <- index s:address:array:character/deref, end:number
    whitespace?:boolean <- equal curr:character, 32:literal/space
    break-unless whitespace?:boolean
    end:number <- subtract end:number, 1:literal
    loop
  }
  # create result
  new-len:number <- subtract end:number, start:number, -1:literal  # end-start+1
  result:address:array:character <- new character:type, new-len:number
  # i = start, j = 0
  i:number <- copy start:number
  j:number <- copy 0:literal
  {
    # while i <= end
    done?:boolean <- greater-than i:number, end:number
    break-if done?:boolean
    # result[j] = s[i]
    src:character <- index s:address:array:character/deref, i:number
    dest:address:character <- index-address result:address:array:character/deref, j:number
    dest:address:character/deref <- copy src:character
    # ++i, ++j
    i:number <- add i:number, 1:literal
    j:number <- add j:number, 1:literal
    loop
  }
  reply result:address:array:character
]

scenario trim-unmodified [
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy 2:address:array:character/deref
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-left [
  run [
    1:address:array:character <- new [  abc]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy 2:address:array:character/deref
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-right [
  run [
    1:address:array:character <- new [abc  ]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy 2:address:array:character/deref
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]

scenario trim-left-right [
  run [
    1:address:array:character <- new [  abc   ]
    2:address:array:character <- trim 1:address:array:character
    3:array:character <- copy 2:address:array:character/deref
  ]
  memory-should-contain [
    3:string <- [abc]
  ]
]
