## the basic editor data structure, and how it displays text to the screen

# temporary main for this layer: just render the given text at the given
# screen dimensions, then stop
def! main text:address:shared:array:character [
  local-scope
  load-ingredients
  open-console
  hide-screen 0/screen
  new-editor text, 0/screen, 0/left, 5/right
  show-screen 0/screen
  wait-for-event 0/console
  close-console
]

scenario editor-initially-prints-text-to-screen [
  assume-screen 10/width, 5/height
  run [
    1:address:shared:array:character <- new [abc]
    new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  ]
  screen-should-contain [
    # top line of screen reserved for menu
    .          .
    .abc       .
    .          .
  ]
]

container editor-data [
  # editable text: doubly linked list of characters (head contains a special sentinel)
  data:address:shared:duplex-list:character
  top-of-screen:address:shared:duplex-list:character
  bottom-of-screen:address:shared:duplex-list:character
  # location before cursor inside data
  before-cursor:address:shared:duplex-list:character

  # raw bounds of display area on screen
  # always displays from row 1 (leaving row 0 for a menu) and at most until bottom of screen
  left:number
  right:number
  bottom:number
  # raw screen coordinates of cursor
  cursor-row:number
  cursor-column:number
]

# creates a new editor widget and renders its initial appearance to screen
#   top/left/right constrain the screen area available to the new editor
#   right is exclusive
def new-editor s:address:shared:array:character, screen:address:shared:screen, left:number, right:number -> result:address:shared:editor-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  # no clipping of bounds
  right <- subtract right, 1
  result <- new editor-data:type
  # initialize screen-related fields
  *result <- put *result, left:offset, left
  *result <- put *result, right:offset, right
  # initialize cursor coordinates
  *result <- put *result, cursor-row:offset, 1/top
  *result <- put *result, cursor-column:offset, left
  # initialize empty contents
  init:address:shared:duplex-list:character <- push 167/§, 0/tail
  *result <- put *result, data:offset, init
  *result <- put *result, top-of-screen:offset, init
  *result <- put *result, before-cursor:offset, init
  result <- insert-text result, s
  # initial render to screen, just for some old tests
  _, _, screen, result <- render screen, result
  <editor-initialization>
]

def insert-text editor:address:shared:editor-data, text:address:shared:array:character -> editor:address:shared:editor-data [
  local-scope
  load-ingredients
  # early exit if text is empty
  return-unless text, editor/same-as-ingredient:0
  len:number <- length *text
  return-unless len, editor/same-as-ingredient:0
  idx:number <- copy 0
  # now we can start appending the rest, character by character
  curr:address:shared:duplex-list:character <- get *editor, data:offset
  {
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    c:character <- index *text, idx
    insert c, curr
    # next iter
    curr <- next curr
    idx <- add idx, 1
    loop
  }
  return editor/same-as-ingredient:0
]

scenario editor-initializes-without-data [
  assume-screen 5/width, 3/height
  run [
    1:address:shared:editor-data <- new-editor 0/data, screen:address:shared:screen, 2/left, 5/right
    2:editor-data <- copy *1:address:shared:editor-data
  ]
  memory-should-contain [
    # 2 (data) <- just the § sentinel
    # 3 (top of screen) <- the § sentinel
    4 <- 0  # bottom-of-screen; null since text fits on screen
    # 5 (before cursor) <- the § sentinel
    6 <- 2  # left
    7 <- 4  # right  (inclusive)
    8 <- 1  # bottom
    9 <- 1  # cursor row
    10 <- 2  # cursor column
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]

# Assumes cursor should be at coordinates (cursor-row, cursor-column) and
# updates before-cursor to match. Might also move coordinates if they're
# outside text.
def render screen:address:shared:screen, editor:address:shared:editor-data -> last-row:number, last-column:number, screen:address:shared:screen, editor:address:shared:editor-data [
  local-scope
  load-ingredients
  return-unless editor, 1/top, 0/left, screen/same-as-ingredient:0, editor/same-as-ingredient:1
  left:number <- get *editor, left:offset
  screen-height:number <- screen-height screen
  right:number <- get *editor, right:offset
  # traversing editor
  curr:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  prev:address:shared:duplex-list:character <- copy curr  # just in case curr becomes null and we can't compute prev
  curr <- next curr
  # traversing screen
  +render-loop-initialization
  color:number <- copy 7/white
  row:number <- copy 1/top
  column:number <- copy left
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
  screen <- move-cursor screen, row, column
  {
    +next-character
    break-unless curr
    off-screen?:boolean <- greater-or-equal row, screen-height
    break-if off-screen?
    # update editor-data.before-cursor
    # Doing so at the start of each iteration ensures it stays one step behind
    # the current character.
    {
      at-cursor-row?:boolean <- equal row, cursor-row
      break-unless at-cursor-row?
      at-cursor?:boolean <- equal column, cursor-column
      break-unless at-cursor?
      before-cursor <- copy prev
    }
    c:character <- get *curr, value:offset
    <character-c-received>
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # adjust cursor if necessary
      {
        at-cursor-row?:boolean <- equal row, cursor-row
        break-unless at-cursor-row?
        left-of-cursor?:boolean <- lesser-than column, cursor-column
        break-unless left-of-cursor?
        cursor-column <- copy column
        before-cursor <- prev curr
      }
      # clear rest of line in this window
      clear-line-delimited screen, column, right
      # skip to next line
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      curr <- next curr
      prev <- next prev
      loop +next-character:label
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      wrap-icon:character <- copy 8617/loop-back-to-left
      print screen, wrap-icon, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      # don't increment curr
      loop +next-character:label
    }
    print screen, c, color
    curr <- next curr
    prev <- next prev
    column <- add column, 1
    loop
  }
  # save first character off-screen
  *editor <- put *editor, bottom-of-screen:offset, curr
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row, cursor-row
    cursor-outside-line?:boolean <- lesser-or-equal column, cursor-column
    before-cursor-on-same-line?:boolean <- and at-cursor-row?, cursor-outside-line?
    above-cursor-row?:boolean <- lesser-than row, cursor-row
    before-cursor?:boolean <- or before-cursor-on-same-line?, above-cursor-row?
    break-unless before-cursor?
    cursor-row <- copy row
    cursor-column <- copy column
    before-cursor <- copy prev
  }
  *editor <- put *editor, bottom:offset, row
  *editor <- put *editor, cursor-row:offset, cursor-row
  *editor <- put *editor, cursor-column:offset, cursor-column
  *editor <- put *editor, before-cursor:offset, before-cursor
  return row, column, screen/same-as-ingredient:0, editor/same-as-ingredient:1
]

def clear-line-delimited screen:address:shared:screen, column:number, right:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  space:character <- copy 32/space
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  {
    done?:boolean <- greater-than column, right
    break-if done?
    screen <- print screen, space, 7/white, bg-color  # foreground color is mostly unused except if the cursor shows up at this cell
    column <- add column, 1
    loop
  }
]

def clear-screen-from screen:address:shared:screen, row:number, column:number, left:number, right:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if it's the real screen, use the optimized primitive
  {
    break-if screen
    clear-display-from row, column, left, right
    return screen/same-as-ingredient:0
  }
  # if not, go the slower route
  screen <- move-cursor screen, row, column
  clear-line-delimited screen, column, right
  clear-rest-of-screen screen, row, left, right
  return screen/same-as-ingredient:0
]

def clear-rest-of-screen screen:address:shared:screen, row:number, left:number, right:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  row <- add row, 1
  screen <- move-cursor screen, row, left
  screen-height:number <- screen-height screen
  {
    at-bottom-of-screen?:boolean <- greater-or-equal row, screen-height
    break-if at-bottom-of-screen?
    screen <- move-cursor screen, row, left
    clear-line-delimited screen, left, right
    row <- add row, 1
    loop
  }
]

scenario editor-initially-prints-multiple-lines [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abc
def]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
  ]
  screen-should-contain [
    .     .
    .abc  .
    .def  .
    .     .
  ]
]

scenario editor-initially-handles-offsets [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abc]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 1/left, 5/right
  ]
  screen-should-contain [
    .     .
    . abc .
    .     .
  ]
]

scenario editor-initially-prints-multiple-lines-at-offset [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abc
def]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 1/left, 5/right
  ]
  screen-should-contain [
    .     .
    . abc .
    . def .
    .     .
  ]
]

scenario editor-initially-wraps-long-lines [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abc def]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
  ]
  screen-should-contain [
    .     .
    .abc ↩.
    .def  .
    .     .
  ]
  screen-should-contain-in-color 245/grey [
    .     .
    .    ↩.
    .     .
    .     .
  ]
]

scenario editor-initially-wraps-barely-long-lines [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abcde]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
  ]
  # still wrap, even though the line would fit. We need room to click on the
  # end of the line
  screen-should-contain [
    .     .
    .abcd↩.
    .e    .
    .     .
  ]
  screen-should-contain-in-color 245/grey [
    .     .
    .    ↩.
    .     .
    .     .
  ]
]

scenario editor-initializes-empty-text [
  assume-screen 5/width, 5/height
  run [
    1:address:shared:array:character <- new []
    2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 0  # cursor column
  ]
]

# just a little color for mu code

scenario render-colors-comments [
  assume-screen 5/width, 5/height
  run [
    s:address:shared:array:character <- new [abc
# de
f]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
  ]
  screen-should-contain [
    .     .
    .abc  .
    .# de .
    .f    .
    .     .
  ]
  screen-should-contain-in-color 12/lightblue, [
    .     .
    .     .
    .# de .
    .     .
    .     .
  ]
  screen-should-contain-in-color 7/white, [
    .     .
    .abc  .
    .     .
    .f    .
    .     .
  ]
]

after <character-c-received> [
  color <- get-color color, c
]

# so far the previous color is all the information we need; that may change
def get-color color:number, c:character -> color:number [
  local-scope
  load-ingredients
  color-is-white?:boolean <- equal color, 7/white
  # if color is white and next character is '#', switch color to blue
  {
    break-unless color-is-white?
    starting-comment?:boolean <- equal c, 35/#
    break-unless starting-comment?
    trace 90, [app], [switch color back to blue]
    color <- copy 12/lightblue
    jump +exit:label
  }
  # if color is blue and next character is newline, switch color to white
  {
    color-is-blue?:boolean <- equal color, 12/lightblue
    break-unless color-is-blue?
    ending-comment?:boolean <- equal c, 10/newline
    break-unless ending-comment?
    trace 90, [app], [switch color back to white]
    color <- copy 7/white
    jump +exit:label
  }
  # if color is white (no comments) and next character is '<', switch color to red
  {
    break-unless color-is-white?
    starting-assignment?:boolean <- equal c, 60/<
    break-unless starting-assignment?
    color <- copy 1/red
    jump +exit:label
  }
  # if color is red and next character is space, switch color to white
  {
    color-is-red?:boolean <- equal color, 1/red
    break-unless color-is-red?
    ending-assignment?:boolean <- equal c, 32/space
    break-unless ending-assignment?
    color <- copy 7/white
    jump +exit:label
  }
  # otherwise no change
  +exit
  return color
]

scenario render-colors-assignment [
  assume-screen 8/width, 5/height
  run [
    s:address:shared:array:character <- new [abc
d <- e
f]
    new-editor s:address:shared:array:character, screen:address:shared:screen, 0/left, 8/right
  ]
  screen-should-contain [
    .        .
    .abc     .
    .d <- e  .
    .f       .
    .        .
  ]
  screen-should-contain-in-color 1/red, [
    .        .
    .        .
    .  <-    .
    .        .
    .        .
  ]
]
