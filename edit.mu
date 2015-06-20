# Editor widget: takes a string and screen coordinates, modifying them in place.

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  switch-to-display
  width:number <- display-width
  height:number <- display-height
  divider:number, _ <- divide-with-remainder width:number, 2:literal
  draw-vertical 0:literal/screen, divider:number, 0:literal/top, height:number
  in:address:array:character <- new [abc
def
ghi
jkl
]
  bottom:number <- edit in:address:array:character, 0:literal/screen, 0:literal/top, 0:literal/left, 5:literal/bottom, divider:number/right, 0:literal/keyboard
  # shorten bottom border and darken to make it seem thinner
  border-left:number <- multiply divider:number, 0.2
  border-right:number <- multiply divider:number, 0.8
  draw-horizontal 0:literal/screen, bottom:number/row, border-left:number, border-right:number, 241:literal/grey
  wait-for-key-from-keyboard
  return-to-console
]

scenario edit-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc]
    edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right, keyboard:address
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

container editor-data [
  data:address:duplex-list  # doubly linked list of characters
  top-of-screen:address:duplex-list  # pointer to character at top-left
]

recipe new-editor-data [
  default-space:address:array:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  # early exit if s is empty
  result:address:editor-data <- new editor-data:type
  reply-unless s:address:array:character, result:address:editor-data
  len:number <- length s:address:array:character/deref
  reply-unless len:number, result:address:editor-data
  idx:number <- copy 0:literal
  # s is guaranteed to have at least one character, so initialize result's
  # duplex-list
  init:address:address:duplex-list <- get-address result:address:editor-data/deref, top-of-screen:offset
  init:address:address:duplex-list/deref <- copy 0:literal
  c:character <- index s:address:array:character/deref, idx:number
  idx:number <- add idx:number, 1:literal
  init:address:address:duplex-list/deref <- push c:character, init:address:address:duplex-list/deref
  curr:address:duplex-list <- copy init:address:address:duplex-list/deref
  # now we can start appending the rest, character by character
  {
    done?:boolean <- greater-or-equal idx:number, len:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, idx:number
    insert-duplex c:character, curr:address:duplex-list
    # next iter
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    idx:number <- add idx:number, 1:literal
  }
  reply result:address:editor-data
]

recipe edit [
  default-space:address:array:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  # no clipping of bounds
  top:number <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  right:number <- subtract right:number, 1:literal
  keyboard:address <- next-ingredient
  edit:address:editor-data <- new-editor-data s:address:array:character, screen:address
  bottom:number, screen:address <- render s:address:array:character, screen:address, top:number, left:number, right:number
  reply bottom:number, edit:address:editor-data
]

recipe render [
  default-space:address:array:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  screen-height:number <- screen-height screen:address
  right:number <- next-ingredient
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
    off-screen?:boolean <- greater-or-equal row:number, screen-height:number
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
  reply row:number, screen:address/same-as-ingredient:1
]

scenario edit-prints-multiple-lines [
  assume-screen 5:literal/width, 3:literal/height
  assume-keyboard []
  run [
    s:address:array:character <- new [abc
def]
    edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right, keyboard:address
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
    edit s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 5:literal/right, keyboard:address
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
    edit s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 5:literal/right, keyboard:address
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
    edit s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right, keyboard:address
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

recipe draw-box [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  # top border
  draw-horizontal screen:address, top:number, left:number, right:number, color:number
  draw-horizontal screen:address, bottom:number, left:number, right:number, color:number
  draw-vertical screen:address, left:number, top:number, bottom:number, color:number
  draw-vertical screen:address, right:number, top:number, bottom:number, color:number
  draw-top-left screen:address, top:number, left:number, color:number
  draw-top-right screen:address, top:number, right:number, color:number
  draw-bottom-left screen:address, bottom:number, left:number, color:number
  draw-bottom-right screen:address, bottom:number, right:number, color:number
  # position cursor inside box
  move-cursor screen:address, top:number, left:number
  cursor-down screen:address
  cursor-right screen:address
]

recipe draw-horizontal [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  row:number <- next-ingredient
  x:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  move-cursor screen:address, row:number, x:number
  {
    continue?:boolean <- lesser-than x:number, right:number
    break-unless continue?:boolean
    print-character screen:address, 9472:literal/horizontal, color:number
    x:number <- add x:number, 1:literal
    loop
  }
]

recipe draw-vertical [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  col:number <- next-ingredient
  x:number <- next-ingredient
  bottom:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  {
    continue?:boolean <- lesser-than x:number, bottom:number
    break-unless continue?:boolean
    move-cursor screen:address, x:number, col:number
    print-character screen:address, 9474:literal/vertical, color:number
    x:number <- add x:number, 1:literal
    loop
  }
]

recipe draw-top-left [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  move-cursor screen:address, top:number, left:number
  print-character screen:address, 9484:literal/down-right, color:number
]

recipe draw-top-right [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  top:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  move-cursor screen:address, top:number, right:number
  print-character screen:address, 9488:literal/down-left, color:number
]

recipe draw-bottom-left [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  bottom:number <- next-ingredient
  left:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  move-cursor screen:address, bottom:number, left:number
  print-character screen:address, 9492:literal/up-right, color:number
]

recipe draw-bottom-right [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  move-cursor screen:address, bottom:number, right:number
  print-character screen:address, 9496:literal/up-left, color:number
]
