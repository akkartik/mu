# Editor widget: takes a string and screen coordinates, and returns a new string.

scenario edit-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 0:literal/right, 10:literal/bottom, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

recipe edit [
  default-space:address:array:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  keyboard:address <- next-ingredient
  print-string screen:address, s:address:array:character
]
