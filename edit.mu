# Editor widget: takes a string and screen coordinates, and returns a new string.

scenario edit-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/bottom, 5:literal/right, keyboard:address
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
  move-cursor screen:address, top:number, left:number
  print-string screen:address, s:address:array:character
]

scenario edit-prints-multiple-lines [
  assume-screen 5:literal/width, 3:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc
def]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/bottom, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    .abc  .
    .def  .
    .     .
  ]
]

scenario edit-handles-offsets [
  assume-screen 5:literal/width, 3:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 10:literal/bottom, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    . abc .
    .     .
    .     .
  ]
]
