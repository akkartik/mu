# Editor widget: takes a string and screen coordinates, and returns a new string.

recipe main [
  1:address:array:character <- new [abcdef]
  switch-to-display
  edit 1:address:array:character, 0:literal/screen, 5:literal/top, 5:literal/left, 10:literal/bottom, 10:literal/right, 0:literal/keyboard
  wait-for-key-from-keyboard
  return-to-console
]

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
  # no clipping of bounds
  top:number <- next-ingredient
  left:number <- next-ingredient
  bottom:number <- next-ingredient
  bottom:number <- subtract bottom:number, 1:literal
  right:number <- next-ingredient
  right:number <- subtract right:number, 1:literal
  keyboard:address <- next-ingredient
  # traversing inside s
  len:number <- length s:address:array:character/deref
  i:number <- copy 0:literal
  # traversing inside screen
  row:number <- copy top:number
  column:number <- copy left:number
  move-cursor screen:address, row:number, column:number
  {
    +next-character
    done?:boolean <- greater-or-equal i:number, len:number
    break-if done?:boolean
    off-screen?:boolean <- greater-than row:number, bottom:number
    break-if off-screen?:boolean
    c:character <- index s:address:array:character/deref, i:number
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c:character, 10:literal/newline
      break-unless newline?:boolean
      row:number <- add row:number, 1:literal
      column:number <- copy left:number
      move-cursor screen:address, row:number, column:number
      i:number <- add i:number, 1:literal
      loop +next-character:label
    }
    {
      # at right? more than one letter left in the line? wrap
      at-right?:boolean <- equal column:number, right:number
      break-unless at-right?:boolean
      next-index:number <- add i:number, 1:literal
      next-at-end?:boolean <- greater-or-equal next-index:number, len:number
      break-if next-at-end?:boolean
      next:character <- index s:address:array:character/deref, next-index:number
      next-character-is-newline?:boolean <- equal next:character, 10:literal/newline
      break-if next-character-is-newline?:boolean
      # wrap
      print-character screen:address, 8617:literal/loop-back-to-left, 245:literal/grey
      column:number <- copy left:number
      row:number <- add row:number, 1:literal
      move-cursor screen:address, row:number, column:number
      # don't increment i
      loop +next-character:label
    }
    print-character screen:address, c:character
    i:number <- add i:number, 1:literal
    column:number <- add column:number, 1:literal
    loop
  }
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

scenario edit-prints-multiple-lines-at-offset [
  assume-screen 5:literal/width, 3:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc
def]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 10:literal/bottom, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    . abc .
    . def .
    .     .
  ]
]

scenario edit-wraps-long-lines [
  assume-screen 5:literal/width, 3:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc def]
    s2:address:array:character, screen:address, keyboard:address <- edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/bottom, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    .abc ↩.
    .def  .
    .     .
  ]
  screen-should-contain-in-color, 245:literal/grey [
    .    ↩.
    .     .
    .     .
  ]
]
