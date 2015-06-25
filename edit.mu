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
  # doubly linked list of characters (head contains a special marker)
  data:address:duplex-list
  # location of top-left of screen inside data (scrolling)
  top-of-screen:address:duplex-list
  # location before cursor inside data
  before-cursor:address:duplex-list

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
  d:address:address:duplex-list <- get-address result:address:editor-data/deref, data:offset
  d:address:address:duplex-list/deref <- push-duplex 167:literal/§, 0:literal/tail
#?   $print d:address:address:duplex-list/deref, [ 
#? ] #? 1
  # initialize screen-related fields
  sc:address:address:screen <- get-address result:address:editor-data/deref, screen:offset
  sc:address:address:screen/deref <- copy screen:address
  x:address:number <- get-address result:address:editor-data/deref, top:offset
  x:address:number/deref <- copy top:number
  x:address:number <- get-address result:address:editor-data/deref, left:offset
  x:address:number/deref <- copy left:number
  x:address:number <- get-address result:address:editor-data/deref, right:offset
  x:address:number/deref <- copy right:number
  # bottom = top (in case of early exit)
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
  init:address:address:duplex-list/deref <- copy d:address:address:duplex-list/deref
  curr:address:duplex-list <- copy init:address:address:duplex-list/deref
  # now we can start appending the rest, character by character
  {
#?     $print idx:number, [ vs ], len:number, [ 
#? ] #? 1
#?     $print [append to ], curr:address:duplex-list, [ 
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
  y:address:address:duplex-list <- get-address result:address:editor-data/deref, before-cursor:offset
  y:address:address:duplex-list/deref <- copy init:address:address:duplex-list/deref
  # perform initial rendering to screen
  bottom:address:number <- get-address result:address:editor-data/deref, bottom:offset
  result:address:editor-data <- render result:address:editor-data
  reply result:address:editor-data
]

scenario editor-initializes-without-data [
  assume-screen 5:literal/width, 3:literal/height
  run [
    1:address:editor-data <- new-editor 0:literal/data, screen:address, 1:literal/top, 2:literal/left, 5:literal/right
    2:editor-data <- copy 1:address:editor-data/deref
  ]
  memory-should-contain [
    # 2 <- just the § marker
    3 <- 0  # pointer into data to top of screen
    # 4 (before cursor) <- the § marker
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
#?   $print [=== render
#? ] #? 1
  screen:address <- get editor:address:editor-data/deref, screen:offset
  top:number <- get editor:address:editor-data/deref, top:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  screen-height:number <- screen-height screen:address
  right:number <- get editor:address:editor-data/deref, right:offset
  # traversing editor
  curr:address:duplex-list <- get editor:address:editor-data/deref, top-of-screen:offset
  curr:address:duplex-list <- next-duplex curr:address:duplex-list
  # traversing screen
  row:number <- copy top:number
  column:number <- copy left:number
  cursor-row:number <- get editor:address:editor-data/deref, cursor-row:offset
  cursor-column:number <- get editor:address:editor-data/deref, cursor-column:offset
  move-cursor screen:address, row:number, column:number
  {
    +next-character
#?     $print curr:address:duplex-list, [ 
#? ] #? 1
    break-unless curr:address:duplex-list
    off-screen?:boolean <- greater-or-equal row:number, screen-height:number
    break-if off-screen?:boolean
    # update editor-data.before-cursor
    # Doing so at the start of each iteration ensures it stays one step behind
    # the current character.
    {
      at-cursor-row?:boolean <- equal row:number, cursor-row:number
      break-unless at-cursor-row?:boolean
      at-cursor?:boolean <- equal column:number, cursor-column:number
      break-unless at-cursor?:boolean
      before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
      before-cursor:address:address:duplex-list/deref <- prev-duplex curr:address:duplex-list
    }
    c:character <- get curr:address:duplex-list/deref, value:offset
#?     $print [rendering ], c:character, [ 
#? ] #? 1
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c:character, 10:literal/newline
      break-unless newline?:boolean
      row:number <- add row:number, 1:literal
      column:number <- copy left:number
      clear-line screen:address
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
  # bottom = row
  bottom:address:number <- get-address editor:address:editor-data/deref, bottom:offset
  bottom:address:number/deref <- copy row:number
  # update cursor
  cursor-row:number <- get editor:address:editor-data/deref, cursor-row:offset
  cursor-column:number <- get editor:address:editor-data/deref, cursor-column:offset
  move-cursor screen:address, cursor-row:number, cursor-column:number
  reply editor:address:editor-data/same-as-ingredient:0
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
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  {
    +next-event
    e:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
    loop-unless found?:boolean
    break-if quit?:boolean  # only in tests
    trace [app], [next-event]
    # mouse clicks
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t:address:touch-event
      editor:address:editor-data <- move-cursor-in-editor editor:address:editor-data, t:address:touch-event/deref
      loop +next-event:label
    }
    # typing regular characters
    {
      c:address:character <- maybe-convert e:event, text:variant
      break-unless c:address:character
      editor:address:editor-data <- insert-at-cursor editor:address:editor-data, c:address:character/deref
      loop +next-event:label
    }
    # otherwise it's a special key to control the editor
    k:address:number <- maybe-convert e:event, keycode:variant
    assert k:address:number, [event was of unknown type; neither keyboard nor mouse]
    before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
    cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
    cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
    # arrows; update cursor-row and cursor-column, leave before-cursor to 'render'
    {
      next-character?:boolean <- equal k:address:number/deref, 65514:literal/right-arrow
      break-unless next-character?:boolean
      next:address:duplex-list <- next-duplex before-cursor:address:address:duplex-list/deref
      break-unless next:address:duplex-list
      before-cursor:address:address:duplex-list/deref <- copy next:address:duplex-list
      nextc:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset
      # if it's a newline
      {
        at-newline?:boolean <- equal nextc:character, 10:literal/newline
        break-unless at-newline?:boolean
        cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
        cursor-column:address:number/deref <- copy 0:literal
        break +render:label
      }
      # otherwise
      cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
    }
    +render
    render editor:address:editor-data
    loop
  }
]

recipe move-cursor-in-editor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  t:touch-event <- next-ingredient
  # update cursor
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-row:address:number/deref <- get t:touch-event, row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- get t:touch-event, column:offset
  render editor:address:editor-data
  reply editor:address:editor-data/same-as-ingredient:0
]

recipe insert-at-cursor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  c:character <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
#?   $print before-cursor:address:address:duplex-list/deref, [ ], d:address:duplex-list, [ 
#? ] #? 1
#?   $print [inserting ], c:character, [ 
#? ] #? 1
  insert-duplex c:character, before-cursor:address:address:duplex-list/deref
  # update cursor: if newline, move cursor to start of next line
  # todo: bottom of screen
  {
    newline?:boolean <- equal c:character, 10:literal/newline
    break-unless newline?:boolean
    cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
    cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
    cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
    cursor-column:address:number/deref <- copy 0:literal
    break +render:label
  }
  # otherwise move cursor right
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
  +render
  render editor:address:editor-data
  reply editor:address:editor-data/same-as-ingredient:0
]

scenario editor-handles-empty-event-queue [
  assume-screen 10:literal/width, 5:literal/height
  assume-console []
  run [
    s:address:array:character <- new [abc]
    editor:address:editor-data <- new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, editor:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    left-click 0, 1
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
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

scenario editor-inserts-characters-at-cursor [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    type [0]
    left-click 0, 2
    type [d]
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .0adbc     .
    .          .
  ]
]

scenario editor-moves-cursor-after-inserting-characters [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    type [01]
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .01abc     .
    .          .
  ]
]

scenario editor-moves-cursor-down-after-inserting-newline [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    type [0
1]
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .0         .
    .1abc      .
    .          .
  ]
]

scenario editor-moves-cursor-right-with-key [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    press 65514  # right arrow
    type [0]
  ]
  run [
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .a0bc      .
    .          .
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow [
  assume-screen 10:literal/width, 5:literal/height
  assume-console [
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    1:address:array:character <- new [abc
d]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .0d        .
    .          .
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
