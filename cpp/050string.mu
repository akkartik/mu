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
