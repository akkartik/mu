# Editor widget: takes a string and screen coordinates, modifying them in place.

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  open-console
  width:number <- display-width
  height:number <- display-height
  divider:number, _ <- divide-with-remainder width:number, 2:literal
  draw-vertical 0:literal/screen, divider:number, 0:literal/top, height:number
  in:address:array:character <- new [abcdef
def
ghi
jkl
]
  editor:address:editor-data <- new-editor in:address:array:character, 0:literal/screen, 0:literal/top, 0:literal/left, divider:number/right
  event-loop 0:literal/screen, 0:literal/events, editor:address:editor-data
  close-console
]

scenario editor-initially-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abc]
    new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

## In which we introduce the editor data structure, and show how it displays
## text to the screen.

container editor-data [
  # doubly linked list of characters
  data:address:duplex-list
  # location of top-left of screen inside data (scrolling)
  top-of-screen:address:duplex-list
  # location of cursor inside data
  cursor:address:duplex-list

  screen:address:screen
  # raw bounds of display area on screen
  top:number
  left:number
  bottom:number
  right:number
  # raw screen coordinates of cursor
  cursor-row:number
  cursor-column:number
]

# editor:address, screen:address <- new-editor s:address:array:character, screen:address, top:number, left:number, bottom:number
# creates a new editor widget and renders its initial appearance to screen.
#   top/left/right constrain the screen area available to the new editor.
#   right is exclusive.
recipe new-editor [
  default-space:address:array:location <- new location:type, 30:literal
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  # no clipping of bounds
  top:number <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  right:number <- subtract right:number, 1:literal
  result:address:editor-data <- new editor-data:type
  # initialize screen-related fields
  sc:address:address:screen <- get-address result:address:editor-data/deref, screen:offset
  sc:address:address:screen/deref <- copy screen:address
  x:address:number <- get-address result:address:editor-data/deref, top:offset
  x:address:number/deref <- copy top:number
  x:address:number <- get-address result:address:editor-data/deref, left:offset
  x:address:number/deref <- copy left:number
  x:address:number <- get-address result:address:editor-data/deref, right:offset
  x:address:number/deref <- copy right:number
  # initialize bottom to top for starters
  x:address:number <- get-address result:address:editor-data/deref, bottom:offset
  x:address:number/deref <- copy top:number
  # initialize cursor
  x:address:number <- get-address result:address:editor-data/deref, cursor-row:offset
  x:address:number/deref <- copy top:number
  x:address:number <- get-address result:address:editor-data/deref, cursor-column:offset
  x:address:number/deref <- copy left:number
  # early exit if s is empty
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
#?     $print idx:number, [ vs ], len:number, [ 
#? ] #? 1
    done?:boolean <- greater-or-equal idx:number, len:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, idx:number
#?     $print [aa: ], c:character, [ 
#? ] #? 1
    insert-duplex c:character, curr:address:duplex-list
    # next iter
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    idx:number <- add idx:number, 1:literal
    loop
  }
  # initialize cursor to top of screen
  y:address:address:duplex-list <- get-address result:address:editor-data/deref, cursor:offset
  y:address:address:duplex-list/deref <- copy init:address:address:duplex-list/deref
  # perform initial rendering to screen
  bottom:address:number <- get-address result:address:editor-data/deref, bottom:offset
  bottom:address:number/deref, screen:address <- render result:address:editor-data, screen:address, top:number, left:number, right:number
  reply result:address:editor-data
]

scenario editor-initializes-without-data [
  assume-screen 5:literal/width, 3:literal/height
  run [
    1:address:editor-data <- new-editor 0:literal/data, screen:address, 1:literal/top, 2:literal/left, 5:literal/right
    2:editor-data <- copy 1:address:editor-data/deref
  ]
  memory-should-contain [
    2 <- 0  # data
    3 <- 0  # pointer into data to top of screen
    4 <- 0  # pointer into data to cursor
    # 5 <- screen
    6 <- 1  # top
    7 <- 2  # left
    8 <- 1  # bottom
    9 <- 4  # right  (inclusive)
    10 <- 1  # cursor row
    11 <- 2  # cursor column
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]

recipe render [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  screen-height:number <- screen-height screen:address
  right:number <- next-ingredient
  cursor:address:duplex-list <- get editor:address:editor-data/deref, cursor:offset
  # traversing editor
  curr:address:duplex-list <- get editor:address:editor-data/deref, top-of-screen:offset
  # traversing screen
  row:number <- copy top:number
  column:number <- copy left:number
  move-cursor screen:address, row:number, column:number
  {
    +next-character
#?     $print curr:address:duplex-list, [ 
#? ] #? 1
    break-unless curr:address:duplex-list
    off-screen?:boolean <- greater-or-equal row:number, screen-height:number
    break-if off-screen?:boolean
    {
      at-cursor?:boolean <- equal curr:address:duplex-list, cursor:address:duplex-list
      break-unless at-cursor?:boolean
      cursor-row:number <- copy row:number
      cursor-column:number <- copy column:number
    }
    c:character <- get curr:address:duplex-list/deref, value:offset
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c:character, 10:literal/newline
      break-unless newline?:boolean
      row:number <- add row:number, 1:literal
      column:number <- copy left:number
      move-cursor screen:address, row:number, column:number
      curr:address:duplex-list <- next-duplex curr:address:duplex-list
      loop +next-character:label
    }
    {
      # at right? more than one letter left in the line? wrap
      at-right?:boolean <- equal column:number, right:number
      break-unless at-right?:boolean
      next-node:address:duplex-list <- next-duplex curr:address:duplex-list
      break-unless next-node:address:duplex-list
      next:character <- get next-node:address:duplex-list/deref, value:offset
      next-character-is-newline?:boolean <- equal next:character, 10:literal/newline
      break-if next-character-is-newline?:boolean
      # wrap
      print-character screen:address, 8617:literal/loop-back-to-left, 245:literal/grey
      column:number <- copy left:number
      row:number <- add row:number, 1:literal
      move-cursor screen:address, row:number, column:number
      # don't increment curr
      loop +next-character:label
    }
    print-character screen:address, c:character
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    column:number <- add column:number, 1:literal
    loop
  }
  move-cursor screen:address, cursor-row:number, cursor-column:number
  reply row:number, screen:address/same-as-ingredient:1
]

scenario editor-initially-prints-multiple-lines [
  assume-screen 5:literal/width, 3:literal/height
  run [
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .abc  .
    .def  .
    .     .
  ]
]

scenario editor-initially-handles-offsets [
  assume-screen 5:literal/width, 3:literal/height
  run [
    s:address:array:character <- new [abc]
    new-editor s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 5:literal/right
  ]
  screen-should-contain [
    . abc .
    .     .
    .     .
  ]
]

scenario editor-initially-prints-multiple-lines-at-offset [
  assume-screen 5:literal/width, 3:literal/height
  run [
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 0:literal/top, 1:literal/left, 5:literal/right
  ]
  screen-should-contain [
    . abc .
    . def .
    .     .
  ]
]

scenario editor-initially-wraps-long-lines [
  assume-screen 5:literal/width, 3:literal/height
  run [
    s:address:array:character <- new [abc def]
    new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
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

## handling events from the keyboard and mouse

recipe event-loop [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  events:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  {
    +next-event
    e:event, events:address, found?:boolean, quit?:boolean <- read-event events:address
    loop-unless found?:boolean
    break-if quit?:boolean  # only in tests
    trace [app], [next-event]
    {
      m:address:mouse-event <- maybe-convert e:event, mouse:variant
      break-unless m:address:mouse-event
      editor:address:editor-data <- move-cursor-in-editor editor:address:editor-data, m:address:mouse-event
      loop +next-event:label
    }
    k:address:keyboard-event <- maybe-convert e:event, keyboard:variant
    assert k:address:keyboard-event, [event was of unknown type; neither keyboard nor mouse]
    loop
  }
]

recipe move-cursor-in-editor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  m:address:mouse-event <- next-ingredient
  row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  row:address:number/deref <- get m:address:mouse-event/deref, row:offset
  column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  column:address:number/deref <- get m:address:mouse-event/deref, column:offset
  # todo: adjust 'cursor' pointer into editor data
]

scenario editor-handles-empty-event-queue [
  assume-screen 10:literal/width, 5:literal/height
  assume-events []
  run [
    s:address:array:character <- new [abc]
    editor:address:editor-data <- new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, events:address, editor:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  assume-screen 10:literal/width, 5:literal/height
  assume-events [
    left-click 0, 1
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, events:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
  memory-should-contain [
    3 <- 0  # cursor is at row 0..
    4 <- 1  # ..and column 1
  ]
]

## helpers for drawing editor borders

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
