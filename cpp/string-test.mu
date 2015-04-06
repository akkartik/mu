recipe main [
  default-space:address:space <- new location:type, 30:literal
  x:address:array:character <- new [abcd]
  y:address:array:character <- new [abc]
  3:boolean/raw <- string-equal x:address:array:character, y:address:array:character
]
