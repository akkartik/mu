# Some useful helpers for dealing with strings.

recipe string-equal [
  default-space:address:space <- new location:type, 30:literal
  a:address:array:character <- next-ingredient
  a-len:integer <- length a:address:array:character/deref
  b:address:array:character <- next-ingredient
  b-len:integer <- length b:address:array:character/deref
  # compare lengths
  {
    trace [string-equal], [comparing lengths]
    length-equal?:boolean <- equal a-len:integer, b-len:integer
    break-if length-equal?:boolean
    reply 0:literal
  }
  # compare each corresponding character
  trace [string-equal], [comparing characters]
  i:integer <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:integer, a-len:integer
    break-if done?:boolean
    a2:character <- index a:address:array:character/deref, i:integer
    b2:character <- index b:address:array:character/deref, i:integer
    {
      chars-match?:boolean <- equal a2:character, b2:character
      break-if chars-match?:boolean
      reply 0:literal
    }
    i:integer <- add i:integer, 1:literal
    loop
  }
  reply 1:literal
]

scenario string-equal-reflexive [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x:address:array:character, x:address:array:character
  ]
  memory should contain [
    3 <- 1  # x == x for all x
  ]
]

scenario string-equal-identical [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abc]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory should contain [
    3 <- 1  # abc == abc
  ]
]

scenario string-equal-distinct-lengths [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory should contain [
    3 <- 0  # abc != abcd
  ]
  trace should contain [
    string-equal: comparing lengths
  ]
  trace should not contain [
    string-equal: comparing characters
  ]
]

scenario string-equal-with-empty [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:array:character <- new []
    y:address:array:character <- new [abcd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory should contain [
    3 <- 0  # "" != abcd
  ]
]

scenario string-equal-common-lengths-but-distinct [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:array:character <- new [abc]
    y:address:array:character <- new [abd]
    3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
  ]
  memory should contain [
    3 <- 0  # abc != abd
  ]
]

# A new type to help incrementally construct strings.
container buffer [
  length:integer
  data:address:array:character
]

recipe init-buffer [
  default-space:address:space <- new location:type, 30:literal
#?   $print default-space:address:space
#?   $print [
#? ]
  result:address:buffer <- new buffer:type
  len:address:integer <- get-address result:address:buffer/deref, length:offset
  len:address:integer/deref <- copy 0:literal
  s:address:address:array:character <- get-address result:address:buffer/deref, data:offset
  capacity:integer <- next-ingredient
  s:address:address:array:character/deref <- new character:type, capacity:integer
#?   $print s:address:address:array:character/deref
#?   $print [
#? ]
  reply result:address:buffer
]

recipe grow-buffer [
  default-space:address:space <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  # double buffer size
  x:address:address:array:character <- get-address in:address:buffer/deref, data:offset
  oldlen:integer <- length x:address:address:array:character/deref/deref
  newlen:integer <- multiply oldlen:integer, 2:literal
  olddata:address:array:character <- copy x:address:address:array:character/deref
  x:address:address:array:character/deref <- new character:type, newlen:integer
  # copy old contents
  i:integer <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:integer, oldlen:integer
    break-if done?:boolean
    src:character <- index olddata:address:array:character/deref, i:integer
    dest:address:character <- index-address x:address:address:array:character/deref/deref, i:integer
    dest:address:character/deref <- copy src:character
    i:integer <- add i:integer, 1:literal
    loop
  }
  reply in:address:buffer
]

recipe buffer-full? [
  default-space:address:space <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  len:integer <- get in:address:buffer/deref, length:offset
  s:address:array:character <- get in:address:buffer/deref, data:offset
  capacity:integer <- length s:address:array:character/deref
  result:boolean <- greater-or-equal len:integer, capacity:integer
  reply result:boolean
]

# in:address:buffer <- buffer-append in:address:buffer, c:character
recipe buffer-append [
  default-space:address:space <- new location:type, 30:literal
  in:address:buffer <- next-ingredient
  c:character <- next-ingredient
  {
    # grow buffer if necessary
    full?:boolean <- buffer-full? in:address:buffer
    break-unless full?:boolean
    in:address:buffer <- grow-buffer in:address:buffer
  }
  len:address:integer <- get-address in:address:buffer/deref, length:offset
  s:address:array:character <- get in:address:buffer/deref, data:offset
  dest:address:character <- index-address s:address:array:character/deref, len:address:integer/deref
  dest:address:character/deref <- copy c:character
  len:address:integer/deref <- add len:address:integer/deref, 1:literal
  reply in:address:buffer/same-as-arg:0
]

scenario buffer-append-works [
  run [
    default-space:address:space <- new location:type, 30:literal
    x:address:buffer <- init-buffer 3:literal
    s1:address:array:character <- get x:address:buffer/deref, data:offset
    x:address:buffer <- buffer-append x:address:buffer, 97:literal  # 'a'
    x:address:buffer <- buffer-append x:address:buffer, 98:literal  # 'b'
    x:address:buffer <- buffer-append x:address:buffer, 99:literal  # 'c'
    s2:address:array:character <- get x:address:buffer/deref, data:offset
    1:boolean/raw <- equal s1:address:array:character, s2:address:array:character
#?     $print s2:address:array:character
#?     $print [
#? ]
#?     $print 1060:integer/raw
#?     $print [
#? ]
#?     $print 1061:integer/raw
#?     $print [
#? ]
#?     $print 1062:integer/raw
#?     $print [
#? ]
#?     $print 1063:integer/raw
#?     $print [
#? ]
#?     $print 1064:integer/raw
#?     $print [
#? ]
#?     $print 1065:integer/raw
#?     $print [
#? ]
    2:array:character/raw <- copy s2:address:array:character/deref
    +buffer-filled
    x:address:buffer <- buffer-append x:address:buffer, 100:literal  # 'd'
    s3:address:array:character <- get x:address:buffer/deref, data:offset
    10:boolean/raw <- equal s1:address:array:character, s3:address:array:character
    11:integer/raw <- get x:address:buffer/deref, length:offset
    12:array:character/raw <- copy s3:address:array:character/deref
  ]
  memory should contain [
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

# result:address:array:character <- integer-to-decimal-string n:integer
recipe integer-to-decimal-string [
  default-space:address:space <- new location:type, 30:literal
  n:integer <- next-ingredient
  # is it zero?
  {
    break-if n:integer
    result:address:array:character <- new [0]
    reply result:address:array:character
  }
  # save sign
  negate-result:boolean <- copy 0:literal
  {
    negative?:boolean <- less-than n:integer, 0:literal
    break-unless negative?:boolean
    negate-result:boolean <- copy 1:literal
    n:integer <- multiply n:integer -1:literal
  }
  # add digits from right to left into intermediate buffer
  tmp:address:buffer <- init-buffer 30:literal
  digit-base:integer <- copy 48:literal  # '0'
  {
    done?:boolean <- equal n:integer, 0:literal
    break-if done?:boolean
    n:integer, digit:integer <- divide-with-remainder n:integer, 10:literal
    c:character <- add digit-base:integer, digit:integer
    tmp:address:buffer <- buffer-append tmp:address:buffer, c:character
    loop
  }
  # add sign
  {
    break-unless negate-result:boolean
    tmp:address:buffer <- buffer-append tmp:address:buffer, 45:literal  # '-'
  }
  # reverse buffer into string result
  len:integer <- get tmp:address:buffer/deref, length:offset
  buf:address:array:character <- get tmp:address:buffer/deref data:offset
  result:address:array:character <- new character:type, len:integer
  i:integer <- subtract len:integer, 1:literal
  j:integer <- copy 0:literal
  {
    # while i >= 0
    done?:boolean <- less-than i:integer, 0:literal
    break-if done?:boolean
    # result[j] = tmp[i]
    src:character <- index buf:address:array:character/deref, i:integer
    dest:address:character <- index-address result:address:array:character/deref, j:integer
    dest:address:character/deref <- copy src:character
    # ++i
    i:integer <- subtract i:integer, 1:literal
    # --j
    j:integer <- add j:integer, 1:literal
    loop
  }
  reply result:address:array:character
]

scenario integer-to-decimal-digit-zero [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 0:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory should contain [
    2 <- 1
    3 <- 48  # '0'
  ]
]

scenario integer-to-decimal-digit-positive [
  run [
    1:address:array:character/raw <- integer-to-decimal-string 234:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory should contain [
    2 <- 3
    3 <- 50  # '2'
    4 <- 51  # '3'
    5 <- 52  # '4'
  ]
]

scenario integer-to-decimal-digit-negative [
  run [
    1:address:array:character/raw <- integer-to-decimal-string -1:literal
    2:array:character/raw <- copy 1:address:array:character/deref/raw
  ]
  memory should contain [
    2 <- 2
    3 <- 45  # '-'
    4 <- 49  # '1'
  ]
]
