# Environment for learning programming using mu: http://akkartik.name/post/mu
#
# Consists of one editor on the left for recipes and one on the right for the
# sandbox.

recipe main [
  local-scope
  open-console
  initial-recipe:address:array:character <- restore [recipes.mu]
  initial-sandbox:address:array:character <- new []
  hide-screen 0/screen
  env:address:programming-environment-data <- new-programming-environment 0/screen, initial-recipe, initial-sandbox
  env <- restore-sandboxes env
  render-all 0/screen, env
  event-loop 0/screen, 0/console, env
  # never gets here
]

## the basic editor data structure, and how it displays text to the screen

scenario editor-initially-prints-string-to-screen [
  assume-screen 10/width, 5/height
  run [
    1:address:array:character <- new [abc]
    new-editor 1:address:array:character, screen:address, 0/left, 10/right
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
]

container editor-data [
  # editable text: doubly linked list of characters (head contains a special sentinel)
  data:address:duplex-list:character
  top-of-screen:address:duplex-list:character
  bottom-of-screen:address:duplex-list:character
  # location before cursor inside data
  before-cursor:address:duplex-list:character

  # raw bounds of display area on screen
  # always displays from row 1 (leaving row 0 for a menu) and at most until bottom of screen
  left:number
  right:number
  # raw screen coordinates of cursor
  cursor-row:number
  cursor-column:number
]

# editor:address, screen <- new-editor s:address:array:character, screen:address, left:number, right:number
# creates a new editor widget and renders its initial appearance to screen.
#   top/left/right constrain the screen area available to the new editor.
#   right is exclusive.
recipe new-editor [
  local-scope
  s:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  # no clipping of bounds
  left:number <- next-ingredient
  right:number <- next-ingredient
  right <- subtract right, 1
  result:address:editor-data <- new editor-data:type
  # initialize screen-related fields
  x:address:number <- get-address *result, left:offset
  *x <- copy left
  x <- get-address *result, right:offset
  *x <- copy right
  # initialize cursor
  x <- get-address *result, cursor-row:offset
  *x <- copy 1/top
  x <- get-address *result, cursor-column:offset
  *x <- copy left
  init:address:address:duplex-list <- get-address *result, data:offset
  *init <- push-duplex 167/§, 0/tail
  top-of-screen:address:address:duplex-list <- get-address *result, top-of-screen:offset
  *top-of-screen <- copy *init
  y:address:address:duplex-list <- get-address *result, before-cursor:offset
  *y <- copy *init
  result <- insert-text result, s
  # initialize cursor to top of screen
  y <- get-address *result, before-cursor:offset
  *y <- copy *init
  # initial render to screen, just for some old tests
  _, _, screen, result <- render screen, result
  +editor-initialization
  reply result
]

recipe insert-text [
  local-scope
  editor:address:editor-data <- next-ingredient
  text:address:array:character <- next-ingredient
  # early exit if text is empty
  reply-unless text, editor/same-as-ingredient:0
  len:number <- length *text
  reply-unless len, editor/same-as-ingredient:0
  idx:number <- copy 0
  # now we can start appending the rest, character by character
  curr:address:duplex-list <- get *editor, data:offset
  {
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    c:character <- index *text, idx
    insert-duplex c, curr
    # next iter
    curr <- next-duplex curr
    idx <- add idx, 1
    loop
  }
  reply editor/same-as-ingredient:0
]

scenario editor-initializes-without-data [
  assume-screen 5/width, 3/height
  run [
    1:address:editor-data <- new-editor 0/data, screen:address, 2/left, 5/right
    2:editor-data <- copy *1:address:editor-data
  ]
  memory-should-contain [
    # 2 (data) <- just the § sentinel
    # 3 (top of screen) <- the § sentinel
    4 <- 0  # bottom-of-screen; null since text fits on screen
    # 5 (before cursor) <- the § sentinel
    6 <- 2  # left
    7 <- 4  # right  (inclusive)
    8 <- 1  # cursor row
    9 <- 2  # cursor column
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]

# last-row:number, last-column:number, screen, editor <- render screen:address, editor:address:editor-data
#
# Assumes cursor should be at coordinates (cursor-row, cursor-column) and
# updates before-cursor to match. Might also move coordinates if they're
# outside text.
recipe render [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  reply-unless editor, 1/top, 0/left, screen/same-as-ingredient:0, editor/same-as-ingredient:1
  left:number <- get *editor, left:offset
  screen-height:number <- screen-height screen
  right:number <- get *editor, right:offset
  # traversing editor
  curr:address:duplex-list <- get *editor, top-of-screen:offset
  prev:address:duplex-list <- copy curr  # just in case curr becomes null and we can't compute prev-duplex
  curr <- next-duplex curr
  # traversing screen
  +render-loop-initialization
  color:number <- copy 7/white
  row:number <- copy 1/top
  column:number <- copy left
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
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
      at-cursor-row?:boolean <- equal row, *cursor-row
      break-unless at-cursor-row?
      at-cursor?:boolean <- equal column, *cursor-column
      break-unless at-cursor?
      *before-cursor <- copy prev
    }
    c:character <- get *curr, value:offset
    +character-c-received
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # adjust cursor if necessary
      {
        at-cursor-row?:boolean <- equal row, *cursor-row
        break-unless at-cursor-row?
        left-of-cursor?:boolean <- lesser-than column, *cursor-column
        break-unless left-of-cursor?
        *cursor-column <- copy column
        *before-cursor <- prev-duplex curr
      }
      # clear rest of line in this window
      clear-line-delimited screen, column, right
      # skip to next line
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      curr <- next-duplex curr
      prev <- next-duplex prev
      loop +next-character:label
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      print-character screen, 8617/loop-back-to-left, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      # don't increment curr
      loop +next-character:label
    }
    print-character screen, c, color
    curr <- next-duplex curr
    prev <- next-duplex prev
    column <- add column, 1
    loop
  }
  # save first character off-screen
  bottom-of-screen:address:address:duplex-list <- get-address *editor, bottom-of-screen:offset
  *bottom-of-screen <- copy curr
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row, *cursor-row
    cursor-outside-line?:boolean <- lesser-or-equal column, *cursor-column
    before-cursor-on-same-line?:boolean <- and at-cursor-row?, cursor-outside-line?
    above-cursor-row?:boolean <- lesser-than row, *cursor-row
    before-cursor?:boolean <- or before-cursor-on-same-line?, above-cursor-row?
    break-unless before-cursor?
    *cursor-row <- copy row
    *cursor-column <- copy column
    *before-cursor <- copy prev
  }
  reply row, column, screen/same-as-ingredient:0, editor/same-as-ingredient:1
]

# row, screen <- render-string screen:address, s:address:array:character, left:number, right:number, color:number, row:number
# move cursor at start of next line
# print a string 's' to 'editor' in 'color' starting at 'row'
# clear rest of last line, but don't move cursor to next line
recipe render-string [
  local-scope
  screen:address <- next-ingredient
  s:address:array:character <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  color:number <- next-ingredient
  row:number <- next-ingredient
  row <- add row, 1
  reply-unless s, row/same-as-ingredient:5, screen/same-as-ingredient:0
  column:number <- copy left
  screen <- move-cursor screen, row, column
  screen-height:number <- screen-height screen
  i:number <- copy 0
  len:number <- length *s
  {
    +next-character
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    c:character <- index *s, i
    {
      # at right? wrap.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      print-character screen, 8617/loop-back-to-left, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      loop +next-character:label  # retry i
    }
    i <- add i, 1
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      {
        done?:boolean <- greater-than column, right
        break-if done?
        print-character screen, 32/space
        column <- add column, 1
        loop
      }
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      loop +next-character:label
    }
    print-character screen, c, color
    column <- add column, 1
    loop
  }
  {
    # clear rest of current line
    line-done?:boolean <- greater-than column, right
    break-if line-done?
    print-character screen, 32/space
    column <- add column, 1
    loop
  }
  reply row/same-as-ingredient:5, screen/same-as-ingredient:0
]

recipe clear-line-delimited [
  local-scope
  screen:address <- next-ingredient
  column:number <- next-ingredient
  right:number <- next-ingredient
  {
    done?:boolean <- greater-than column, right
    break-if done?
    print-character screen, 32/space
    column <- add column, 1
    loop
  }
]

recipe clear-screen-from [
  local-scope
  screen:address <- next-ingredient
  row:number <- next-ingredient
  column:number <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  # if it's the real screen, use the optimized primitive
  {
    break-if screen
    clear-display-from row, column, left, right
    reply screen/same-as-ingredient:0
  }
  # if not, go the slower route
  screen <- move-cursor screen, row, column
  clear-line-delimited screen, column, right
  clear-rest-of-screen screen, row, left, right
  reply screen/same-as-ingredient:0
]

recipe clear-rest-of-screen [
  local-scope
  screen:address <- next-ingredient
  row:number <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
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
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 0/left, 5/right
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
    s:address:array:character <- new [abc]
    new-editor s:address:array:character, screen:address, 1/left, 5/right
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
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 1/left, 5/right
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
    s:address:array:character <- new [abc def]
    new-editor s:address:array:character, screen:address, 0/left, 5/right
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
    s:address:array:character <- new [abcde]
    new-editor s:address:array:character, screen:address, 0/left, 5/right
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
    1:address:array:character <- new []
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
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
    s:address:array:character <- new [abc
# de
f]
    new-editor s:address:array:character, screen:address, 0/left, 5/right
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

after +character-c-received [
  color <- get-color color, c
]

# color <- get-color color:number, c:character
# so far the previous color is all the information we need; that may change
recipe get-color [
  local-scope
  color:number <- next-ingredient
  c:character <- next-ingredient
  color-is-white?:boolean <- equal color, 7/white
#?   $print [character: ], c, 10/newline #? 1
  # if color is white and next character is '#', switch color to blue
  {
    break-unless color-is-white?
    starting-comment?:boolean <- equal c, 35/#
    break-unless starting-comment?
#?     $print [switch color back to blue], 10/newline #? 1
    color <- copy 12/lightblue
    jump +exit:label
  }
  # if color is blue and next character is newline, switch color to white
  {
    color-is-blue?:boolean <- equal color, 12/lightblue
    break-unless color-is-blue?
    ending-comment?:boolean <- equal c, 10/newline
    break-unless ending-comment?
#?     $print [switch color back to white], 10/newline #? 1
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
  reply color
]

scenario render-colors-assignment [
  assume-screen 8/width, 5/height
  run [
    s:address:array:character <- new [abc
d <- e
f]
    new-editor s:address:array:character, screen:address, 0/left, 8/right
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

## handling events from the keyboard, mouse, touch screen, ...

recipe editor-event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console:address, found?:boolean, quit?:boolean <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    # 'touch' event
    t:address:touch-event <- maybe-convert e, touch:variant
    {
      break-unless t
      +move-cursor-start
      move-cursor-in-editor screen, editor, *t
      +move-cursor-end
      loop +next-event:label
    }
    # keyboard events
    {
      break-if t
      screen, editor, go-render?:boolean <- handle-keyboard-event screen, editor, e
      {
        break-unless go-render?
        editor-render screen, editor
      }
    }
    loop
  }
]

# screen, editor, go-render?:boolean <- handle-keyboard-event screen:address, editor:address:editor-data, e:event
# Process an event 'e' and try to minimally update the screen.
# Set 'go-render?' to true to indicate the caller must perform a non-minimal update.
recipe handle-keyboard-event [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  e:event <- next-ingredient
  reply-unless editor, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  screen-width:number <- screen-width screen
  screen-height:number <- screen-height screen
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  save-row:number <- copy *cursor-row
  save-column:number <- copy *cursor-column
  # character
  {
    c:address:character <- maybe-convert e, text:variant
    break-unless c
#?     trace 10, [app], [handle-keyboard-event: special character] #? 1
    # exceptions for special characters go here
    +handle-special-character
    # ignore any other special characters
    regular-character?:boolean <- greater-or-equal *c, 32/space
    newline?:boolean <- equal *c, 10/newline
    regular-character? <- or regular-character?, newline?
    reply-unless regular-character?, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
    # otherwise type it in
    +insert-character-begin
    editor, screen, go-render?:boolean <- insert-at-cursor editor, *c, screen
    +insert-character-end
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, go-render?
  }
  # special key to modify the text or move the cursor
  k:address:number <- maybe-convert e:event, keycode:variant
  assert k, [event was of unknown type; neither keyboard nor mouse]
  # handlers for each special key will go here
  +handle-special-key
  reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
]

# process click, return if it was on current editor
# todo: ignores menu bar (for now just displays shortcuts)
recipe move-cursor-in-editor [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  t:touch-event <- next-ingredient
  reply-unless editor, 0/false
  click-column:number <- get t, column:offset
  left:number <- get *editor, left:offset
  too-far-left?:boolean <- lesser-than click-column, left
  reply-if too-far-left?, 0/false
  right:number <- get *editor, right:offset
  too-far-right?:boolean <- greater-than click-column, right
  reply-if too-far-right?, 0/false
  # position cursor
#?   trace 1, [print-character], [foo] #? 1
  click-row:number <- get t, row:offset
  click-column:number <- get t, column:offset
  editor <- snap-cursor screen, editor, click-row, click-column
#?   trace 1, [print-character], [foo done] #? 1
  # gain focus
  reply 1/true
]

# editor <- snap-cursor screen:address, editor:address:editor-data, target-row:number, target-column:number
#
# Variant of 'render' that only moves the cursor (coordinates and
# before-cursor). If it's past the end of a line, it 'slides' it left. If it's
# past the last line it positions at end of last line.
recipe snap-cursor [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  target-row:number <- next-ingredient
  target-column:number <- next-ingredient
  reply-unless editor, 1/top, editor/same-as-ingredient:1
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  screen-height:number <- screen-height screen
  # count newlines until screen row
  curr:address:duplex-list <- get *editor, top-of-screen:offset
  prev:address:duplex-list <- copy curr  # just in case curr becomes null and we can't compute prev-duplex
  curr <- next-duplex curr
  row:number <- copy 1/top
  column:number <- copy left
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  *cursor-row <- copy target-row
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  *cursor-column <- copy target-column
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  {
    +next-character
    break-unless curr
    off-screen?:boolean <- greater-or-equal row, screen-height
    break-if off-screen?
    # update editor-data.before-cursor
    # Doing so at the start of each iteration ensures it stays one step behind
    # the current character.
    {
      at-cursor-row?:boolean <- equal row, *cursor-row
      break-unless at-cursor-row?
      at-cursor?:boolean <- equal column, *cursor-column
      break-unless at-cursor?
      *before-cursor <- copy prev
    }
    c:character <- get *curr, value:offset
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # adjust cursor if necessary
      {
        at-cursor-row?:boolean <- equal row, *cursor-row
        break-unless at-cursor-row?
        left-of-cursor?:boolean <- lesser-than column, *cursor-column
        break-unless left-of-cursor?
        *cursor-column <- copy column
        *before-cursor <- copy prev
      }
      # skip to next line
      row <- add row, 1
      column <- copy left
      curr <- next-duplex curr
      prev <- next-duplex prev
      loop +next-character:label
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      column <- copy left
      row <- add row, 1
      # don't increment curr/prev
      loop +next-character:label
    }
    curr <- next-duplex curr
    prev <- next-duplex prev
    column <- add column, 1
    loop
  }
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row, *cursor-row
    cursor-outside-line?:boolean <- lesser-or-equal column, *cursor-column
    before-cursor-on-same-line?:boolean <- and at-cursor-row?, cursor-outside-line?
    above-cursor-row?:boolean <- lesser-than row, *cursor-row
    before-cursor?:boolean <- or before-cursor-on-same-line?, above-cursor-row?
    break-unless before-cursor?
    *cursor-row <- copy row
    *cursor-column <- copy column
    *before-cursor <- copy prev
  }
  reply editor/same-as-ingredient:1
]

recipe insert-at-cursor [
  local-scope
  editor:address:editor-data <- next-ingredient
  c:character <- next-ingredient
  screen:address <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  insert-duplex c, *before-cursor
  *before-cursor <- next-duplex *before-cursor
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  save-row:number <- copy *cursor-row
  save-column:number <- copy *cursor-column
  screen-width:number <- screen-width screen
  screen-height:number <- screen-height screen
  # occasionally we'll need to mess with the cursor
  +insert-character-special-case
  # but mostly we'll just move the cursor right
  *cursor-column <- add *cursor-column, 1
  next:address:duplex-list <- next-duplex *before-cursor
  {
    # at end of all text? no need to scroll? just print the character and leave
    at-end?:boolean <- equal next, 0/null
    break-unless at-end?
    bottom:number <- subtract screen-height, 1
    at-bottom?:boolean <- equal save-row, bottom
    at-right?:boolean <- equal save-column, right
    overflow?:boolean <- and at-bottom?, at-right?
    break-if overflow?
    move-cursor screen, save-row, save-column
    print-character screen, c
    reply editor/same-as-ingredient:0, screen/same-as-ingredient:2, 0/no-more-render
  }
  {
    # not at right margin? print the character and rest of line
    break-unless next
    at-right?:boolean <- greater-or-equal *cursor-column, screen-width
    break-if at-right?
    curr:address:duplex-list <- copy *before-cursor
    move-cursor screen, save-row, save-column
    curr-column:number <- copy save-column
    {
      # hit right margin? give up and let caller render
      at-right?:boolean <- greater-or-equal curr-column, screen-width
      reply-if at-right?, editor/same-as-ingredient:0, screen/same-as-ingredient:2, 1/go-render
      break-unless curr
      # newline? done.
      currc:character <- get *curr, value:offset
      at-newline?:boolean <- equal currc, 10/newline
      break-if at-newline?
      print-character screen, currc
      curr-column <- add curr-column, 1
      curr <- next-duplex curr
      loop
    }
    reply editor/same-as-ingredient:0, screen/same-as-ingredient:2, 0/no-more-render
  }
  reply editor/same-as-ingredient:0, screen/same-as-ingredient:2, 1/go-render
]

# helper for tests
recipe editor-render [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  row:number, column:number <- render screen, editor
  clear-line-delimited screen, column, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9480/horizontal-dotted
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
]

scenario editor-handles-empty-event-queue [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console []
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 1  # on the 'b'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1  # cursor is at row 0..
    4 <- 1  # ..and column 1
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-text [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # last line, to the right of text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-text-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # interior line, to the right of text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-text-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 3, 7  # below text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-column [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  # editor occupies only left half of screen
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    # click on right half of screen
    left-click 3, 8
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈     .
    .          .
  ]
  memory-should-contain [
    3 <- 1  # no change to cursor row
    4 <- 0  # ..or column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-inserts-characters-into-empty-editor [
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    type [abc]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈     .
    .          .
  ]
  check-trace-count-for-label 3, [print-character]
]

scenario editor-inserts-characters-at-cursor [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # type two letters at different places
  assume-console [
    type [0]
    left-click 1, 2
    type [d]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0adbc     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 7, [print-character]  # 4 for first letter, 3 for second
]

scenario editor-inserts-characters-at-cursor-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 5  # right of last line
    type [d]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

scenario editor-inserts-characters-at-cursor-5 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 5  # right of non-last line
    type [e]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abce      .
    .d         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

scenario editor-inserts-characters-at-cursor-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [d]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

scenario editor-inserts-characters-at-cursor-4 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [e]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .de        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

scenario editor-inserts-characters-at-cursor-6 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [ef]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]
]

scenario editor-moves-cursor-after-inserting-characters [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [ab]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [01]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .01ab      .
    .┈┈┈┈┈     .
    .          .
  ]
]

# if the cursor reaches the right margin, wrap the line

scenario editor-wraps-line-on-insert [
  assume-screen 5/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  # type a letter
  assume-console [
    type [e]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # no wrap yet
  screen-should-contain [
    .     .
    .eabc .
    .┈┈┈┈┈.
    .     .
    .     .
  ]
  # type a second letter
  assume-console [
    type [f]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # now wrap
  screen-should-contain [
    .     .
    .efab↩.
    .c    .
    .┈┈┈┈┈.
    .     .
  ]
]

after +insert-character-special-case [
  # if the line wraps at the cursor, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:number <- subtract right, 1
    at-wrap?:boolean <- greater-or-equal *cursor-column, wrap-column
    break-unless at-wrap?
    *cursor-column <- subtract *cursor-column, wrap-column
    *cursor-row <- add *cursor-row, 1
    # if we're out of the screen, scroll down
    {
      below-screen?:boolean <- greater-or-equal *cursor-row, screen-height
      break-unless below-screen?
      +scroll-down
    }
    reply editor/same-as-ingredient:0, screen/same-as-ingredient:2, 1/go-render
  }
]

scenario editor-wraps-cursor-after-inserting-characters [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  assume-console [
    left-click 1, 4  # line is full; no wrap icon yet
    type [f]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .fe        .
    .┈┈┈┈┈     .
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 1  # cursor column
  ]
]

scenario editor-wraps-cursor-after-inserting-characters-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  assume-console [
    left-click 1, 3  # right before the wrap icon
    type [f]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcf↩     .
    .de        .
    .┈┈┈┈┈     .
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 0  # cursor column
  ]
]

# if newline, move cursor to start of next line, and maybe align indent with previous line

container editor-data [
  indent:boolean
]

after +editor-initialization [
  indent:address:boolean <- get-address *result, indent:offset
  *indent <- copy 1/true
]

scenario editor-moves-cursor-down-after-inserting-newline [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0         .
    .1abc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +insert-character-special-case [
  {
    newline?:boolean <- equal c, 10/newline
    break-unless newline?
    *cursor-row <- add *cursor-row, 1
    *cursor-column <- copy left
    {
      below-screen?:boolean <- greater-or-equal *cursor-row, screen-height  # must be equal, never greater
      break-unless below-screen?
      +scroll-down
      *cursor-row <- subtract *cursor-row, 1  # bring back into screen range
    }
    # indent if necessary
    indent?:boolean <- get *editor, indent:offset
    reply-unless indent?, editor/same-as-ingredient:0, screen/same-as-ingredient:2, 1/go-render
    d:address:duplex-list <- get *editor, data:offset
    end-of-previous-line:address:duplex-list <- prev-duplex *before-cursor
    indent:number <- line-indent end-of-previous-line, d
    i:number <- copy 0
    {
      indent-done?:boolean <- greater-or-equal i, indent
      break-if indent-done?
      insert-at-cursor editor, 32/space, screen
      i <- add i, 1
      loop
    }
    reply editor/same-as-ingredient:0, screen/same-as-ingredient:2, 1/go-render
  }
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the number of spaces at the start of the line containing 'curr'.
recipe line-indent [
  local-scope
  curr:address:duplex-list <- next-ingredient
  start:address:duplex-list <- next-ingredient
  result:number <- copy 0
  reply-unless curr, result
  at-start?:boolean <- equal curr, start
  reply-if at-start?, result
  {
    curr <- prev-duplex curr
    break-unless curr
    at-start?:boolean <- equal curr, start
    break-if at-start?
    c:character <- get *curr, value:offset
    at-newline?:boolean <- equal c, 10/newline
    break-if at-newline?
    # if c is a space, increment result
    is-space?:boolean <- equal c, 32/space
    {
      break-unless is-space?
      result <- add result, 1
    }
    # if c is not a space, reset result
    {
      break-if is-space?
      result <- copy 0
    }
    loop
  }
  reply result
]

scenario editor-moves-cursor-down-after-inserting-newline-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    . 0        .
    . 1abc     .
    . ┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-clears-previous-line-completely-after-inserting-newline [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # press just a 'newline'
  assume-console [
    type [
]
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .e         .
    .          .
    .          .
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # line should be fully cleared
  screen-should-contain [
    .          .
    .          .
    .abcd↩     .
    .e         .
    .┈┈┈┈┈     .
  ]
]

scenario editor-inserts-indent-after-newline [
  assume-screen 10/width, 10/height
  1:address:array:character <- new [ab
  cd
ef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline'
  assume-console [
    left-click 2, 8
    type [
]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor should be below start of previous line
  memory-should-contain [
    3 <- 3  # cursor row
    4 <- 2  # cursor column (indented)
  ]
]

scenario editor-skips-indent-around-paste [
  assume-screen 10/width, 10/height
  1:address:array:character <- new [ab
  cd
ef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline' surrounded by paste markers
  assume-console [
    left-click 2, 8
    press 65507  # start paste
    type [
]
    press 65506  # end paste
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor should be below start of previous line
  memory-should-contain [
    3 <- 3  # cursor row
    4 <- 0  # cursor column (not indented)
  ]
]

after +handle-special-key [
  {
    paste-start?:boolean <- equal *k, 65507/paste-start
    break-unless paste-start?
    indent:address:boolean <- get-address *editor, indent:offset
    *indent <- copy 0/false
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

after +handle-special-key [
  {
    paste-end?:boolean <- equal *k, 65506/paste-end
    break-unless paste-end?
    indent:address:boolean <- get-address *editor, indent:offset
    *indent <- copy 1/true
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

## special shortcuts for manipulating the editor
# Some keys on the keyboard generate unicode characters, others generate
# terminfo key codes. We need to modify different places in the two cases.

# tab - insert two spaces

scenario editor-inserts-two-spaces-on-tab [
  assume-screen 10/width, 5/height
  # just one character in final line
  1:address:array:character <- new [ab
cd]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  assume-console [
    type [»]
  ]
  3:event/tab <- merge 0/text, 9/tab, 0/dummy, 0/dummy
  replace-in-console 187/», 3:event/tab
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .  ab      .
    .cd        .
  ]
]

after +handle-special-character [
  {
    tab?:boolean <- equal *c, 9/tab
    break-unless tab?
    insert-at-cursor editor, 32/space, screen
    insert-at-cursor editor, 32/space, screen
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# backspace - delete character before cursor

scenario editor-handles-backspace-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 1
    type [«]
  ]
  3:event/backspace <- merge 0/text, 8/backspace, 0/dummy, 0/dummy
  replace-in-console 171/«, 3:event/backspace
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .bc        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
  check-trace-count-for-label 3, [print-character]  # length of original line to overwrite
]

after +handle-special-character [
  {
    delete-previous-character?:boolean <- equal *c, 8/backspace
    break-unless delete-previous-character?
    editor, screen, go-render?:boolean <- delete-before-cursor editor, screen
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, go-render?
  }
]

recipe delete-before-cursor [
  local-scope
  editor:address:editor-data <- next-ingredient
  screen:address <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  # if at start of text (before-cursor at § sentinel), return
  prev:address:duplex-list <- prev-duplex *before-cursor
  reply-unless prev, editor/same-as-ingredient:0, screen/same-as-ingredient:1, 0/no-more-render
#?   trace 10, [app], [delete-before-cursor] #? 1
  original-row:number <- get *editor, cursor-row:offset
  editor, scroll?:boolean <- move-cursor-coordinates-left editor
  remove-duplex *before-cursor
  *before-cursor <- copy prev
  reply-if scroll?, editor/same-as-ingredient:0, 1/go-render
  screen-width:number <- screen-width screen
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  # did we just backspace over a newline?
  same-row?:boolean <- equal cursor-row, original-row
  reply-unless same-row?, editor/same-as-ingredient:0, screen/same-as-ingredient:1, 1/go-render
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  curr:address:duplex-list <- next-duplex *before-cursor
  screen <- move-cursor screen, cursor-row, cursor-column
  curr-column:number <- copy cursor-column
  {
    # hit right margin? give up and let caller render
    at-right?:boolean <- greater-or-equal curr-column, screen-width
    reply-if at-right?, editor/same-as-ingredient:0, screen/same-as-ingredient:1, 1/go-render
    break-unless curr
    # newline? done.
    currc:character <- get *curr, value:offset
    at-newline?:boolean <- equal currc, 10/newline
    break-if at-newline?
    screen <- print-character screen, currc
    curr-column <- add curr-column, 1
    curr <- next-duplex curr
    loop
  }
  # we're guaranteed not to be at the right margin
  screen <- print-character screen, 32/space
  reply editor/same-as-ingredient:0, screen/same-as-ingredient:1, 0/no-more-render
]

recipe move-cursor-coordinates-left [
  local-scope
  editor:address:editor-data <- next-ingredient
  before-cursor:address:duplex-list <- get *editor, before-cursor:offset
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  left:number <- get *editor, left:offset
  # if not at left margin, move one character left
  {
    at-left-margin?:boolean <- equal *cursor-column, left
    break-if at-left-margin?
#?     trace 10, [app], [decrementing cursor column] #? 1
    *cursor-column <- subtract *cursor-column, 1
    reply editor/same-as-ingredient:0, 0/no-more-render
  }
  # if at left margin, we must move to previous row:
  top-of-screen?:boolean <- equal *cursor-row, 1  # exclude menu bar
  go-render?:boolean <- copy 0/false
  {
    break-if top-of-screen?
    *cursor-row <- subtract *cursor-row, 1
  }
  {
    break-unless top-of-screen?
    +scroll-up
    go-render? <- copy 1/true
  }
  {
    # case 1: if previous character was newline, figure out how long the previous line is
    previous-character:character <- get *before-cursor, value:offset
    previous-character-is-newline?:boolean <- equal previous-character, 10/newline
    break-unless previous-character-is-newline?
    # compute length of previous line
#?     trace 10, [app], [switching to previous line] #? 1
    d:address:duplex-list <- get *editor, data:offset
    end-of-line:number <- previous-line-length before-cursor, d
    *cursor-column <- add left, end-of-line
    reply editor/same-as-ingredient:0, go-render?
  }
  # case 2: if previous-character was not newline, we're just at a wrapped line
#?   trace 10, [app], [wrapping to previous line] #? 1
  right:number <- get *editor, right:offset
  *cursor-column <- subtract right, 1  # leave room for wrap icon
  reply editor/same-as-ingredient:0, go-render?
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the length of the previous line before the 'curr' pointer.
recipe previous-line-length [
  local-scope
  curr:address:duplex-list <- next-ingredient
  start:address:duplex-list <- next-ingredient
  result:number <- copy 0
  reply-unless curr, result
  at-start?:boolean <- equal curr, start
  reply-if at-start?, result
  {
    curr <- prev-duplex curr
    break-unless curr
    at-start?:boolean <- equal curr, start
    break-if at-start?
    c:character <- get *curr, value:offset
    at-newline?:boolean <- equal c, 10/newline
    break-if at-newline?
    result <- add result, 1
    loop
  }
  reply result
]

scenario editor-clears-last-line-on-backspace [
  assume-screen 10/width, 5/height
  # just one character in final line
  1:address:array:character <- new [ab
cd]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  assume-console [
    left-click 2, 0  # cursor at only character in final line
    type [«]
  ]
  3:event/backspace <- merge 0/text, 8/backspace, 0/dummy, 0/dummy
  replace-in-console 171/«, 3:event/backspace
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 2
  ]
]

# delete - delete character at cursor

scenario editor-handles-delete-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    press 65522  # delete
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .bc        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]  # length of original line to overwrite
  $clear-trace
  assume-console [
    press 65522  # delete
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .c         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]  # new length to overwrite
]

after +handle-special-key [
  {
    delete-next-character?:boolean <- equal *k, 65522/delete
    break-unless delete-next-character?
    curr:address:duplex-list <- next-duplex *before-cursor
    reply-unless curr, editor/same-as-ingredient:0, screen/same-as-ingredient:1, 0/no-more-render
    currc:character <- get *curr, value:offset
    remove-duplex curr
    deleted-newline?:boolean <- equal currc, 10/newline
    reply-if deleted-newline?, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
    # wasn't a newline? render rest of line
    curr:address:duplex-list <- next-duplex *before-cursor  # refresh after remove-duplex above
    screen <- move-cursor screen, *cursor-row, *cursor-column
    curr-column:number <- copy *cursor-column
    {
      # hit right margin? give up and let caller render
      at-right?:boolean <- greater-or-equal curr-column, screen-width
      reply-if at-right?, editor/same-as-ingredient:0, screen/same-as-ingredient:1, 1/go-render
      break-unless curr
      # newline? done.
      currc:character <- get *curr, value:offset
      at-newline?:boolean <- equal currc, 10/newline
      break-if at-newline?
      screen <- print-character screen, currc
      curr-column <- add curr-column, 1
      curr <- next-duplex curr
      loop
    }
    # we're guaranteed not to be at the right margin
    screen <- print-character screen, 32/space
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  }
]

# right arrow

scenario editor-moves-cursor-right-with-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    press 65514  # right arrow
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]  # 0 and following characters
]

after +handle-special-key [
  {
    move-to-next-character?:boolean <- equal *k, 65514/right-arrow
    break-unless move-to-next-character?
    # if not at end of text
    next-cursor:address:duplex-list <- next-duplex *before-cursor
    break-unless next-cursor
    # scan to next character
    +move-cursor-start
    *before-cursor <- copy next-cursor
    editor, go-render?:boolean <- move-cursor-coordinates-right editor, screen-height
    screen <- move-cursor screen, *cursor-row, *cursor-column
    +move-cursor-end
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, go-render?
  }
]

recipe move-cursor-coordinates-right [
  local-scope
  editor:address:editor-data <- next-ingredient
  screen-height:number <- next-ingredient
  before-cursor:address:duplex-list <- get *editor before-cursor:offset
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  # if crossed a newline, move cursor to start of next row
  {
    old-cursor-character:character <- get *before-cursor, value:offset
    was-at-newline?:boolean <- equal old-cursor-character, 10/newline
    break-unless was-at-newline?
    *cursor-row <- add *cursor-row, 1
    *cursor-column <- copy left
    below-screen?:boolean <- greater-or-equal *cursor-row, screen-height  # must be equal
    reply-unless below-screen?, editor/same-as-ingredient:0, 0/no-more-render
    +scroll-down
    *cursor-row <- subtract *cursor-row, 1  # bring back into screen range
    reply editor/same-as-ingredient:0, 1/go-render
  }
  # if the line wraps, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:number <- subtract right, 1
    at-wrap?:boolean <- equal *cursor-column, wrap-column
    break-unless at-wrap?
    # and if next character isn't newline
    next:address:duplex-list <- next-duplex before-cursor
    break-unless next
    next-character:character <- get *next, value:offset
    newline?:boolean <- equal next-character, 10/newline
    break-if newline?
    *cursor-row <- add *cursor-row, 1
    *cursor-column <- copy left
    below-screen?:boolean <- greater-or-equal *cursor-row, screen-height  # must be equal
    reply-unless below-screen?, editor/same-as-ingredient:0, 0/no-more-render
    +scroll-down
    *cursor-row <- subtract *cursor-row, 1  # bring back into screen range
    reply editor/same-as-ingredient:0, 1/go-render
  }
  # otherwise move cursor one character right
  *cursor-column <- add *cursor-column, 1
  reply editor/same-as-ingredient:0, 0/no-more-render
]

scenario editor-moves-cursor-to-next-line-with-right-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # type right-arrow a few times to get to start of second line
  assume-console [
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow - next line
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  check-trace-count-for-label 0, [print-character]
  # type something and ensure it goes where it should
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0d        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]  # new length of second line
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    . abc      .
    . 0d       .
    . ┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .┈┈┈┈┈     .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-2 [
  assume-screen 10/width, 5/height
  # line just barely wrapping
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # position cursor at last character before wrap and hit right-arrow
  assume-console [
    left-click 1, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  # now hit right arrow again
  assume-console [
    press 65514
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1/left, 6/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 4
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    . abcd↩    .
    . ef       .
    . ┈┈┈┈┈    .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-at-end-of-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 3
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0d        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]
]

# left arrow

scenario editor-moves-cursor-left-with-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 2
    press 65515  # left arrow
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]
]

after +handle-special-key [
  {
    move-to-previous-character?:boolean <- equal *k, 65515/left-arrow
    break-unless move-to-previous-character?
#?     trace 10, [app], [left arrow] #? 1
    # if not at start of text (before-cursor at § sentinel)
    prev:address:duplex-list <- prev-duplex *before-cursor
    reply-unless prev, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
    +move-cursor-start
    editor, go-render? <- move-cursor-coordinates-left editor
    *before-cursor <- copy prev
    +move-cursor-end
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, go-render?
  }
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line [
  assume-screen 10/width, 5/height
  # initialize editor with two lines
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # position cursor at start of second line (so there's no previous newline)
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-2 [
  assume-screen 10/width, 5/height
  # initialize editor with three lines
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # position cursor further down (so there's a newline before the character at
  # the cursor)
  assume-console [
    left-click 3, 0
    press 65515  # left arrow
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def0      .
    .g         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  check-trace-count-for-label 1, [print-character]  # just the '0'
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # position cursor at start of text
  assume-console [
    left-click 1, 0
    press 65515  # left arrow should have no effect
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0abc      .
    .def       .
    .g         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  check-trace-count-for-label 4, [print-character]  # length of first line
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-4 [
  assume-screen 10/width, 5/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abc

d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # position cursor right after empty line
  assume-console [
    left-click 3, 0
    press 65515  # left arrow
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0         .
    .d         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  check-trace-count-for-label 1, [print-character]  # just the '0'
]

scenario editor-moves-across-screen-lines-across-wrap-with-left-arrow [
  assume-screen 10/width, 5/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .┈┈┈┈┈     .
    .          .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # previous row
    4 <- 3  # end of wrapped line
  ]
  check-trace-count-for-label 0, [print-character]
]

# up arrow

scenario editor-moves-to-previous-line-with-up-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 2, 1
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +handle-special-key [
  {
    move-to-previous-line?:boolean <- equal *k, 65517/up-arrow
    break-unless move-to-previous-line?
    already-at-top?:boolean <- lesser-or-equal *cursor-row, 1/top
    {
      # if cursor not at top, move it
      break-if already-at-top?
      # if not at newline, move to start of line (previous newline)
      # then scan back another line
      # if either step fails, give up without modifying cursor or coordinates
      curr:address:duplex-list <- copy *before-cursor
      {
        old:address:duplex-list <- copy curr
        c2:character <- get *curr, value:offset
        at-newline?:boolean <- equal c2, 10/newline
        break-if at-newline?
        curr:address:duplex-list <- before-previous-line curr, editor
        no-motion?:boolean <- equal curr, old
        reply-if no-motion?, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
      }
      {
        old <- copy curr
        curr <- before-previous-line curr, editor
        no-motion?:boolean <- equal curr, old
        reply-if no-motion?, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
      }
      *before-cursor <- copy curr
      *cursor-row <- subtract *cursor-row, 1
      # scan ahead to right column or until end of line
      target-column:number <- copy *cursor-column
      *cursor-column <- copy left
      {
        done?:boolean <- greater-or-equal *cursor-column, target-column
        break-if done?
        curr:address:duplex-list <- next-duplex *before-cursor
        break-unless curr
        currc:character <- get *curr, value:offset
        at-newline?:boolean <- equal currc, 10/newline
        break-if at-newline?
        #
        *before-cursor <- copy curr
        *cursor-column <- add *cursor-column, 1
        loop
      }
      reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
    }
    {
      # if cursor already at top, scroll up
      break-unless already-at-top?
      +scroll-up
      reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
    }
  }
]

scenario editor-adjusts-column-at-previous-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [ab
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 2, 3
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .ab0       .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-adjusts-column-at-empty-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 2, 3
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-moves-to-previous-line-from-left-margin [
  assume-screen 10/width, 5/height
  # start out with three lines
  1:address:array:character <- new [abc
def
ghi]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # click on the third line and hit up-arrow, so you end up just after a newline
  assume-console [
    left-click 3, 0
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0def      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

# down arrow

scenario editor-moves-to-next-line-with-down-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # cursor starts out at (1, 0)
  assume-console [
    press 65516  # down arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # ..and ends at (2, 0)
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0def      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +handle-special-key [
  {
    move-to-next-line?:boolean <- equal *k, 65516/down-arrow
    break-unless move-to-next-line?
    last-line:number <- subtract screen-height, 1
    already-at-bottom?:boolean <- greater-or-equal *cursor-row, last-line
    {
      # if cursor not at top, move it
      break-if already-at-bottom?
      # scan to start of next line, then to right column or until end of line
      max:number <- subtract right, left
      next-line:address:duplex-list <- before-start-of-next-line *before-cursor, max
      no-motion?:boolean <- equal next-line, *before-cursor
      reply-if no-motion?, screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
      *cursor-row <- add *cursor-row, 1
      *before-cursor <- copy next-line
      target-column:number <- copy *cursor-column
      *cursor-column <- copy left
      {
        done?:boolean <- greater-or-equal *cursor-column, target-column
        break-if done?
        curr:address:duplex-list <- next-duplex *before-cursor
        break-unless curr
        currc:character <- get *curr, value:offset
        at-newline?:boolean <- equal currc, 10/newline
        break-if at-newline?
        #
        *before-cursor <- copy curr
        *cursor-column <- add *cursor-column, 1
        loop
      }
      reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
    }
    {
      # if cursor already at top, scroll up
      break-unless already-at-bottom?
      +scroll-down
      reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
    }
  }
]

scenario editor-adjusts-column-at-next-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
de]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 3
    press 65516  # down arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .de0       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-stops-at-end-on-down-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
de]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 2, 0
    press 65516  # down arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0de       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# ctrl-a/home - move cursor to start of line

scenario editor-moves-to-start-of-line-with-ctrl-a [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on second line, press ctrl-a
  assume-console [
    left-click 2, 3
    type [a]  # ctrl-a
  ]
  3:event/ctrl-a <- merge 0/text, 1/ctrl-a, 0/dummy, 0/dummy
  replace-in-console 97/a, 3:event/ctrl-a
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 2
    5 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

after +handle-special-character [
  {
    move-to-start-of-line?:boolean <- equal *c, 1/ctrl-a
    break-unless move-to-start-of-line?
    move-to-start-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  }
]

after +handle-special-key [
  {
    move-to-start-of-line?:boolean <- equal *k, 65521/home
    break-unless move-to-start-of-line?
    move-to-start-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  }
]

recipe move-to-start-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  # update cursor column
  left:number <- get *editor, left:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  *cursor-column <- copy left
  # update before-cursor
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  init:address:duplex-list <- get *editor, data:offset
  # while not at start of line, move 
  {
    at-start-of-text?:boolean <- equal *before-cursor, init
    break-if at-start-of-text?
    prev:character <- get **before-cursor, value:offset
    at-start-of-line?:boolean <- equal prev, 10/newline
    break-if at-start-of-line?
    *before-cursor <- prev-duplex *before-cursor
    assert *before-cursor, [move-to-start-of-line tried to move before start of text]
    loop
  }
]

scenario editor-moves-to-start-of-line-with-ctrl-a-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on first line (no newline before), press ctrl-a
  assume-console [
    left-click 1, 3
    type [a]  # ctrl-a
  ]
  3:event/ctrl-a <- merge 0/text, 1/ctrl-a, 0/dummy, 0/dummy
  replace-in-console 97/a, 3:event/ctrl-a
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-start-of-line-with-home [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  $clear-trace
  # start on second line, press 'home'
  assume-console [
    left-click 2, 3
    press 65521  # 'home'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-start-of-line-with-home-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on first line (no newline before), press 'home'
  assume-console [
    left-click 1, 3
    press 65521  # 'home'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

# ctrl-e/end - move cursor to end of line

scenario editor-moves-to-end-of-line-with-ctrl-e [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on first line, press ctrl-e
  assume-console [
    left-click 1, 1
    type [e]  # ctrl-e
  ]
  3:event/ctrl-e <- merge 0/text, 5/ctrl-e, 0/dummy, 0/dummy
  replace-in-console 101/e, 3:event/ctrl-e
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    4 <- 1
    5 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
  # editor inserts future characters at cursor
  assume-console [
    type [z]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    4 <- 1
    5 <- 4
  ]
  screen-should-contain [
    .          .
    .123z      .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

after +handle-special-character [
  {
    move-to-end-of-line?:boolean <- equal *c, 5/ctrl-e
    break-unless move-to-end-of-line?
    move-to-end-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  }
]

after +handle-special-key [
  {
    move-to-end-of-line?:boolean <- equal *k, 65520/end
    break-unless move-to-end-of-line?
    move-to-end-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 0/no-more-render
  }
]

recipe move-to-end-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  # while not at start of line, move 
  {
    next:address:duplex-list <- next-duplex *before-cursor
    break-unless next  # end of text
    nextc:character <- get *next, value:offset
    at-end-of-line?:boolean <- equal nextc, 10/newline
    break-if at-end-of-line?
    *before-cursor <- copy next
    *cursor-column <- add *cursor-column, 1
    loop
  }
]

scenario editor-moves-to-end-of-line-with-ctrl-e-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on second line (no newline after), press ctrl-e
  assume-console [
    left-click 2, 1
    type [e]  # ctrl-e
  ]
  3:event/ctrl-e <- merge 0/text, 5/ctrl-e, 0/dummy, 0/dummy
  replace-in-console 101/e, 3:event/ctrl-e
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get *2:address:editor-data, cursor-row:offset
    5:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    4 <- 2
    5 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-end-of-line-with-end [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on first line, press 'end'
  assume-console [
    left-click 1, 1
    press 65520  # 'end'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-end-of-line-with-end-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # start on second line (no newline after), press 'end'
  assume-console [
    left-click 2, 1
    press 65520  # 'end'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    3 <- 2
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

# ctrl-u - delete text from start of line until (but not at) cursor

scenario editor-deletes-to-start-of-line-with-ctrl-u [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start on second line, press ctrl-u
  assume-console [
    left-click 2, 2
    type [u]  # ctrl-u
  ]
  3:event/ctrl-a <- merge 0/text, 21/ctrl-u, 0/dummy, 0/dummy
  replace-in-console 117/u, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .123       .
    .6         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +handle-special-character [
  {
    delete-to-start-of-line?:boolean <- equal *c, 21/ctrl-u
    break-unless delete-to-start-of-line?
    delete-to-start-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

recipe delete-to-start-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  # compute range to delete
  init:address:duplex-list <- get *editor, data:offset
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  start:address:duplex-list <- copy *before-cursor
  end:address:duplex-list <- next-duplex *before-cursor
  {
    at-start-of-text?:boolean <- equal start, init
    break-if at-start-of-text?
    curr:character <- get *start, value:offset
    at-start-of-line?:boolean <- equal curr, 10/newline
    break-if at-start-of-line?
    start <- prev-duplex start
    assert start, [delete-to-start-of-line tried to move before start of text]
    loop
  }
  # snip it out
  start-next:address:address:duplex-list <- get-address *start, next:offset
  *start-next <- copy end
  {
    break-unless end
    end-prev:address:address:duplex-list <- get-address *end, prev:offset
    *end-prev <- copy start
  }
  # adjust cursor
  *before-cursor <- prev-duplex end
  left:number <- get *editor, left:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  *cursor-column <- copy left
]

scenario editor-deletes-to-start-of-line-with-ctrl-u-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start on first line (no newline before), press ctrl-u
  assume-console [
    left-click 1, 2
    type [u]  # ctrl-u
  ]
  3:event/ctrl-u <- merge 0/text, 21/ctrl-u, 0/dummy, 0/dummy
  replace-in-console 117/u, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .3         .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-start-of-line-with-ctrl-u-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start past end of line, press ctrl-u
  assume-console [
    left-click 1, 3
    type [u]  # ctrl-u
  ]
  3:event/ctrl-u <- merge 0/text, 21/ctrl-u, 0/dummy, 0/dummy
  replace-in-console 117/u, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .          .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-start-of-final-line-with-ctrl-u [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start past end of final line, press ctrl-u
  assume-console [
    left-click 2, 3
    type [u]  # ctrl-u
  ]
  3:event/ctrl-u <- merge 0/text, 21/ctrl-u, 0/dummy, 0/dummy
  replace-in-console 117/u, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .123       .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# ctrl-k - delete text from cursor to end of line (but not the newline)

scenario editor-deletes-to-end-of-line-with-ctrl-k [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start on first line, press ctrl-k
  assume-console [
    left-click 1, 1
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .1         .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +handle-special-character [
  {
    delete-to-end-of-line?:boolean <- equal *c, 11/ctrl-k
    break-unless delete-to-end-of-line?
    delete-to-end-of-line editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

recipe delete-to-end-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  # compute range to delete
  start:address:duplex-list <- get *editor, before-cursor:offset
  end:address:duplex-list <- next-duplex start
  {
    at-end-of-text?:boolean <- equal end, 0/null
    break-if at-end-of-text?
    curr:character <- get *end, value:offset
    at-end-of-line?:boolean <- equal curr, 10/newline
    break-if at-end-of-line?
    end <- next-duplex end
    loop
  }
  # snip it out
  start-next:address:address:duplex-list <- get-address *start, next:offset
  *start-next <- copy end
  {
    break-unless end
    end-prev:address:address:duplex-list <- get-address *end, prev:offset
    *end-prev <- copy start
  }
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start on second line (no newline after), press ctrl-k
  assume-console [
    left-click 2, 1
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .123       .
    .4         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start at end of line
  assume-console [
    left-click 1, 2
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .12        .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-4 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start past end of line
  assume-console [
    left-click 1, 3
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .123       .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-5 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start at end of text
  assume-console [
    left-click 2, 2
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .123       .
    .45        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-6 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  # start past end of text
  assume-console [
    left-click 2, 3
    type [k]  # ctrl-k
  ]
  3:event/ctrl-k <- merge 0/text, 11/ctrl-k, 0/dummy, 0/dummy
  replace-in-console 107/k, 3:event/ctrl-k
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .123       .
    .456       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# cursor-down can scroll if necessary

scenario editor-can-scroll-down-using-arrow-keys [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen slides by one line
  screen-should-contain [
    .          .
    .b         .
    .c         .
    .d         .
  ]
]

after +scroll-down [
#?   $print [scroll down], 10/newline #? 2
  top-of-screen:address:address:duplex-list <- get-address *editor, top-of-screen:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  max:number <- subtract right, left
  *top-of-screen <- before-start-of-next-line *top-of-screen, max
]

# takes a pointer into the doubly-linked list, scans ahead at most 'max'
# positions until the next newline
# beware: never return null pointer.
recipe before-start-of-next-line [
  local-scope
  original:address:duplex-list <- next-ingredient
  max:number <- next-ingredient
  count:number <- copy 0
  curr:address:duplex-list <- copy original
  # skip the initial newline if it exists
  {
    c:character <- get *curr, value:offset
    at-newline?:boolean <- equal c, 10/newline
    break-unless at-newline?
    curr <- next-duplex curr
    count <- add count, 1
  }
  {
    reply-unless curr, original
    done?:boolean <- greater-or-equal count, max
    break-if done?
    c:character <- get *curr, value:offset
    at-newline?:boolean <- equal c, 10/newline
    break-if at-newline?
    curr <- next-duplex curr
    count <- add count, 1
    loop
  }
  reply-unless curr, original
  reply curr
]

scenario editor-scrolls-down-past-wrapped-line-using-arrow-keys [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  1:address:array:character <- new [abcdef
g
h
i]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .g         .
  ]
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .ef        .
    .g         .
    .h         .
  ]
]

scenario editor-scrolls-down-past-wrapped-line-using-arrow-keys-2 [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # editor starts with a long line wrapping twice
  1:address:array:character <- new [abcdefghij
k
l
m]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line containing a wrap icon
  screen-should-contain [
    .          .
    .efgh↩     .
    .ij        .
    .k         .
  ]
  # scroll down again
  assume-console [
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .ij        .
    .k         .
    .l         .
  ]
]

scenario editor-scrolls-down-when-line-wraps [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a long line in the third line
  1:address:array:character <- new [a
b
cdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at end, type a character
  assume-console [
    left-click 3, 4
    type [g]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .cdef↩.
    .g    .
  ]
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
]

scenario editor-scrolls-down-on-newline [
  assume-screen 5/width, 4/height
  # position cursor after last line and type newline
  1:address:array:character <- new [a
b
c]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  assume-console [
    left-click 3, 4
    type [
]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .c    .
    .     .
  ]
  memory-should-contain [
    3 <- 3
    4 <- 0
  ]
]

scenario editor-scrolls-down-on-right-arrow [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a wrapped line
  1:address:array:character <- new [a
b
cdefgh]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .cdef↩.
    .gh   .
  ]
  memory-should-contain [
    3 <- 3
    4 <- 0
  ]
]

scenario editor-scrolls-down-on-right-arrow-2 [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains more lines than can fit on screen
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .c    .
    .d    .
  ]
  memory-should-contain [
    3 <- 3
    4 <- 0
  ]
]

scenario editor-combines-page-and-line-scroll [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a few pages of lines
  1:address:array:character <- new [a
b
c
d
e
f
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # scroll down one page and one line
  assume-console [
    press 65518  # page-down
    left-click 3, 0
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen scrolls down 3 lines
  screen-should-contain [
    .          .
    .d         .
    .e         .
    .f         .
  ]
]

# cursor-up can scroll if necessary

scenario editor-can-scroll-up-using-arrow-keys [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at top of second page, then try to move up
  assume-console [
    press 65518  # page-down
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen slides by one line
  screen-should-contain [
    .          .
    .b         .
    .c         .
    .d         .
  ]
]

after +scroll-up [
#?   $print [scroll up], 10/newline #? 1
  top-of-screen:address:address:duplex-list <- get-address *editor, top-of-screen:offset
  *top-of-screen <- before-previous-line *top-of-screen, editor
]

# takes a pointer into the doubly-linked list, scans back to before start of
# previous *wrapped* line
# beware: never return null pointer
recipe before-previous-line [
  local-scope
  curr:address:duplex-list <- next-ingredient
  c:character <- get *curr, value:offset
#?   $print [curr at ], c, 10/newline #? 1
  # compute max, number of characters to skip
  #   1 + len%(width-1)
  #   except rotate second term to vary from 1 to width-1 rather than 0 to width-2
  editor:address:editor-data <- next-ingredient
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  max-line-length:number <- subtract right, left, -1/exclusive-right, 1/wrap-icon
  sentinel:address:duplex-list <- get *editor, data:offset
  len:number <- previous-line-length curr, sentinel
#?   $print [previous line: ], len, 10/newline #? 1
  {
    break-if len
    # empty line; just skip this newline
    prev:address:duplex-list <- prev-duplex curr
    reply-unless prev, curr
    reply prev
  }
  _, max:number <- divide-with-remainder len, max-line-length
  # remainder 0 => scan one width-worth
  {
    break-if max
#?     $print [remainder 0; scan one width], 10/newline #? 1
    max <- copy max-line-length
  }
  max <- add max, 1
#?   $print [skipping ], max, [ characters], 10/newline #? 1
  count:number <- copy 0
  # skip 'max' characters
  {
    done?:boolean <- greater-or-equal count, max
    break-if done?
    prev:address:duplex-list <- prev-duplex curr
    break-unless prev
    curr <- copy prev
    count <- add count, 1
    loop
  }
  reply curr
]

scenario editor-scrolls-up-past-wrapped-line-using-arrow-keys [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  1:address:array:character <- new [abcdef
g
h
i]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .g         .
  ]
  # position cursor at top of second page, just below wrapped line
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .g         .
    .h         .
    .i         .
  ]
  # now move up one line
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .ef        .
    .g         .
    .h         .
  ]
]

scenario editor-scrolls-up-past-wrapped-line-using-arrow-keys-2 [
  # screen has 1 line for menu + 4 lines
  assume-screen 10/width, 5/height
  # editor starts with a long line wrapping twice, occupying 3 of the 4 lines
  1:address:array:character <- new [abcdefghij
k
l
m]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at top of second page
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .k         .
    .l         .
    .m         .
    .┈┈┈┈┈     .
  ]
  # move up one line
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .ij        .
    .k         .
    .l         .
    .m         .
  ]
  # move up a second line
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .efgh↩     .
    .ij        .
    .k         .
    .l         .
  ]
  # move up a third line
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .abcd↩     .
    .efgh↩     .
    .ij        .
    .k         .
  ]
]

# same as editor-scrolls-up-past-wrapped-line-using-arrow-keys but length
# slightly off, just to prevent over-training
scenario editor-scrolls-up-past-wrapped-line-using-arrow-keys-3 [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  1:address:array:character <- new [abcdef
g
h
i]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 6/right
  screen-should-contain [
    .          .
    .abcde↩    .
    .f         .
    .g         .
  ]
  # position cursor at top of second page, just below wrapped line
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .g         .
    .h         .
    .i         .
  ]
  # now move up one line
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows partial wrapped line
  screen-should-contain [
    .          .
    .f         .
    .g         .
    .h         .
  ]
]

# check empty lines
scenario editor-scrolls-up-past-wrapped-line-using-arrow-keys-4 [
  assume-screen 10/width, 4/height
  # initialize editor with some lines around an empty line
  1:address:array:character <- new [a
b

c
d
e]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 6/right
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .          .
    .c         .
    .d         .
  ]
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .d         .
    .e         .
    .┈┈┈┈┈┈    .
  ]
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .          .
    .c         .
    .d         .
  ]
]

scenario editor-scrolls-up-on-left-arrow [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains >3 lines
  1:address:array:character <- new [a
b
c
d
e]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at top of second page
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .     .
    .c    .
    .d    .
    .e    .
  ]
  # now try to move left
  assume-console [
    press 65515  # left arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .c    .
    .d    .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
]

scenario editor-can-scroll-up-to-start-of-file [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at top of second page, then try to move up to start of
  # text
  assume-console [
    press 65518  # page-down
    press 65517  # up-arrow
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen slides by one line
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # try to move up again
  assume-console [
    press 65517  # up-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen remains unchanged
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
]

# ctrl-f/page-down - render next page if it exists

scenario editor-can-scroll [
  assume-screen 10/width, 4/height
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows next page
  screen-should-contain [
    .          .
    .c         .
    .d         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after +handle-special-character [
  {
    page-down?:boolean <- equal *c, 6/ctrl-f
    break-unless page-down?
    page-down editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

after +handle-special-key [
  {
    page-down?:boolean <- equal *k, 65518/page-down
    break-unless page-down?
    page-down editor
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# page-down skips entire wrapped lines, so it can't scroll past lines
# taking up the entire screen
recipe page-down [
  local-scope
  editor:address:editor-data <- next-ingredient
  # if editor contents don't overflow screen, do nothing
  bottom-of-screen:address:duplex-list <- get *editor, bottom-of-screen:offset
  reply-unless bottom-of-screen, editor/same-as-ingredient:0
  # if not, position cursor at final character
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  *before-cursor <- prev-duplex bottom-of-screen
  # keep one line in common with previous page
  {
    last:character <- get **before-cursor, value:offset
    newline?:boolean <- equal last, 10/newline
    break-unless newline?:boolean
    *before-cursor <- prev-duplex *before-cursor
  }
  # move cursor and top-of-screen to start of that line
  move-to-start-of-line editor
  top-of-screen:address:address:duplex-list <- get-address *editor, top-of-screen:offset
  *top-of-screen <- copy *before-cursor
  reply editor/same-as-ingredient:0
]

scenario editor-does-not-scroll-past-end [
  assume-screen 10/width, 4/height
  1:address:array:character <- new [a
b]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen remains unmodified
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-starts-next-page-at-start-of-wrapped-line [
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a long last line
  1:address:array:character <- new [a
b
cdefgh]
  # editor screen triggers wrap of last line
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .cde↩      .
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows entire wrapped line
  screen-should-contain [
    .          .
    .cde↩      .
    .fgh       .
    .┈┈┈┈      .
  ]
]

scenario editor-starts-next-page-at-start-of-wrapped-line-2 [
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a very long line that occupies last two lines of screen
  # and still has something left over
  1:address:array:character <- new [a
bcdefgh]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .bcd↩      .
    .efg↩      .
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows entire wrapped line
  screen-should-contain [
    .          .
    .bcd↩      .
    .efg↩      .
    .h         .
  ]
]

# ctrl-b/page-up - render previous page if it exists

scenario editor-can-scroll-up [
  assume-screen 10/width, 4/height
  1:address:array:character <- new [a
b
c
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows next page
  screen-should-contain [
    .          .
    .c         .
    .d         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  # scroll back up
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows original page again
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
]

after +handle-special-character [
  {
    page-up?:boolean <- equal *c, 2/ctrl-b
    break-unless page-up?
    editor <- page-up editor, screen-height
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

after +handle-special-key [
  {
    page-up?:boolean <- equal *k, 65519/page-up
    break-unless page-up?
    editor <- page-up editor, screen-height
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

recipe page-up [
  local-scope
  editor:address:editor-data <- next-ingredient
  screen-height:number <- next-ingredient
  max:number <- subtract screen-height, 1/menu-bar, 1/overlapping-line
  count:number <- copy 0
  top-of-screen:address:address:duplex-list <- get-address *editor, top-of-screen:offset
  {
#?     $print [- ], count, [ vs ], max, 10/newline #? 1
    done?:boolean <- greater-or-equal count, max
    break-if done?
    prev:address:duplex-list <- before-previous-line *top-of-screen, editor
    break-unless prev
    *top-of-screen <- copy prev
    count <- add count, 1
    loop
  }
  reply editor/same-as-ingredient:0
]

scenario editor-can-scroll-up-multiple-pages [
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with 8 lines
  1:address:array:character <- new [a
b
c
d
e
f
g
h]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down two pages
  assume-console [
    press 65518  # page-down
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows third page
  screen-should-contain [
    .          .
    .e         .
    .f         .
    .g         .
  ]
  # scroll up
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows second page
  screen-should-contain [
    .          .
    .c         .
    .d         .
    .e         .
  ]
  # scroll up again
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows original page again
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
]

scenario editor-can-scroll-up-wrapped-lines [
  # screen has 1 line for menu + 5 lines for text
  assume-screen 10/width, 6/height
  # editor contains a long line in the first page
  1:address:array:character <- new [a
b
cdefgh
i
j
k
l
m
n
o]
  # editor screen triggers wrap of last line
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .cde↩      .
    .fgh       .
    .i         .
  ]
  # scroll down a page and a line
  assume-console [
    press 65518  # page-down
    left-click 5, 0
    press 65516  # down-arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows entire wrapped line
  screen-should-contain [
    .          .
    .j         .
    .k         .
    .l         .
    .m         .
    .n         .
  ]
  # now scroll up one page
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen resets
  screen-should-contain [
    .          .
    .b         .
    .cde↩      .
    .fgh       .
    .i         .
    .j         .
  ]
]

scenario editor-can-scroll-up-wrapped-lines-2 [
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a very long line that occupies last two lines of screen
  # and still has something left over
  1:address:array:character <- new [a
bcdefgh]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .bcd↩      .
    .efg↩      .
  ]
  # scroll down
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen shows entire wrapped line
  screen-should-contain [
    .          .
    .bcd↩      .
    .efg↩      .
    .h         .
  ]
  # scroll back up
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # screen resets
  screen-should-contain [
    .          .
    .a         .
    .bcd↩      .
    .efg↩      .
  ]
]

scenario editor-can-scroll-up-past-nonempty-lines [
  assume-screen 10/width, 4/height
  # text with empty line in second screen
  1:address:array:character <- new [axx
bxx
cxx
dxx
exx
fxx
gxx
hxx
]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  screen-should-contain [
    .          .
    .axx       .
    .bxx       .
    .cxx       .
  ]
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .cxx       .
    .dxx       .
    .exx       .
  ]
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .exx       .
    .fxx       .
    .gxx       .
  ]
  # scroll back up past empty line
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .cxx       .
    .dxx       .
    .exx       .
  ]
]

scenario editor-can-scroll-up-past-empty-lines [
  assume-screen 10/width, 4/height
  # text with empty line in second screen
  1:address:array:character <- new [axy
bxy
cxy

dxy
exy
fxy
gxy
]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 4/right
  screen-should-contain [
    .          .
    .axy       .
    .bxy       .
    .cxy       .
  ]
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .cxy       .
    .          .
    .dxy       .
  ]
  assume-console [
    press 65518  # page-down
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .dxy       .
    .exy       .
    .fxy       .
  ]
  # scroll back up past empty line
  assume-console [
    press 65519  # page-up
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .cxy       .
    .          .
    .dxy       .
  ]
]

## putting the environment together out of editors

container programming-environment-data [
  recipes:address:editor-data
  recipe-warnings:address:array:character
  current-sandbox:address:editor-data
  sandbox:address:sandbox-data  # list of sandboxes, from top to bottom
  sandbox-in-focus?:boolean  # false => cursor in recipes; true => cursor in current-sandbox
]

recipe new-programming-environment [
  local-scope
  screen:address <- next-ingredient
  initial-recipe-contents:address:array:character <- next-ingredient
  initial-sandbox-contents:address:array:character <- next-ingredient
  width:number <- screen-width screen
  height:number <- screen-height screen
  # top menu
  result:address:programming-environment-data <- new programming-environment-data:type
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  # dotted line down the middle
  divider:number, _ <- divide-with-remainder width, 2
  draw-vertical screen, divider, 1/top, height, 9482/vertical-dotted
  # recipe editor on the left
  recipes:address:address:editor-data <- get-address *result, recipes:offset
  *recipes <- new-editor initial-recipe-contents, screen, 0/left, divider/right
  # sandbox editor on the right
  new-left:number <- add divider, 1
  current-sandbox:address:address:editor-data <- get-address *result, current-sandbox:offset
  *current-sandbox <- new-editor initial-sandbox-contents, screen, new-left, width/right
  +programming-environment-initialization
  reply result
]

recipe event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:address:boolean <- get-address *env, sandbox-in-focus?:offset
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console, found?:boolean, quit?:boolean <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    +handle-event
    # check for global events that will trigger regardless of which editor has focus
    {
      k:address:number <- maybe-convert e:event, keycode:variant
      break-unless k
      +global-keypress
    }
    {
      c:address:character <- maybe-convert e:event, text:variant
      break-unless c
      +global-type
    }
    # 'touch' event - send to both sides, see what picks it up
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t
      # ignore all but 'left-click' events for now
      # todo: test this
      touch-type:number <- get *t, type:offset
      is-left-click?:boolean <- equal touch-type, 65513/mouse-left
      loop-unless is-left-click?, +next-event:label
      # later exceptions for non-editor touches will go here
      +global-touch
      # send to both editors
      _ <- move-cursor-in-editor screen, recipes, *t
      *sandbox-in-focus? <- move-cursor-in-editor screen, current-sandbox, *t
      screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
      loop +next-event:label
    }
    # 'resize' event - redraw editor
    # todo: test this after supporting resize in assume-console
    {
      r:address:resize-event <- maybe-convert e:event, resize:variant
      break-unless r
      # if more events, we're still resizing; wait until we stop
      more-events?:boolean <- has-more-events? console
      break-if more-events?
      env <- resize screen, env
      screen <- render-all screen, env
      loop +next-event:label
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      hide-screen screen
      {
        break-if *sandbox-in-focus?
        screen, recipes, render?:boolean <- handle-keyboard-event screen, recipes, e:event
        {
          break-unless render?
          screen <- render-recipes screen, env
        }
      }
      {
        break-unless *sandbox-in-focus?
        screen, current-sandbox, render?:boolean <- handle-keyboard-event screen, current-sandbox, e:event
        {
          break-unless render?:boolean
          screen <- render-sandbox-side screen, env
        }
      }
      screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
      show-screen screen
    }
    loop
  }
]

recipe resize [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  clear-screen screen  # update screen dimensions
  width:number <- screen-width screen
  divider:number, _ <- divide-with-remainder width, 2
  # update recipe editor
  recipes:address:editor-data <- get *env, recipes:offset
  right:address:number <- get-address *recipes, right:offset
  *right <- subtract divider, 1
  # reset cursor (later we'll try to preserve its position)
  cursor-row:address:number <- get-address *recipes, cursor-row:offset
  *cursor-row <- copy 1
  cursor-column:address:number <- get-address *recipes, cursor-column:offset
  *cursor-column <- copy 0
  # update sandbox editor
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:address:number <- get-address *current-sandbox, left:offset
  right:address:number <- get-address *current-sandbox, right:offset
  *left <- add divider, 1
  *right <- subtract width, 1
  # reset cursor (later we'll try to preserve its position)
  cursor-row:address:number <- get-address *current-sandbox, cursor-row:offset
  *cursor-row <- copy 1
  cursor-column:address:number <- get-address *current-sandbox, cursor-column:offset
  *cursor-column <- copy *left
  reply env/same-as-ingredient:1
]

scenario point-at-multiple-editors [
  $close-trace
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # focus on both sides
  assume-console [
    left-click 1, 1
    left-click 1, 17
  ]
  # check cursor column in each
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    4:address:editor-data <- get *3:address:programming-environment-data, recipes:offset
    5:number <- get *4:address:editor-data, cursor-column:offset
    6:address:editor-data <- get *3:address:programming-environment-data, current-sandbox:offset
    7:number <- get *6:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    5 <- 1
    7 <- 17
  ]
]

scenario edit-multiple-editors [
  $close-trace
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  # type one letter in each of them
  assume-console [
    left-click 1, 1
    type [0]
    left-click 1, 17
    type [1]
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    4:address:editor-data <- get *3:address:programming-environment-data, recipes:offset
    5:number <- get *4:address:editor-data, cursor-column:offset
    6:address:editor-data <- get *3:address:programming-environment-data, current-sandbox:offset
    7:number <- get *6:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .           run (F4)           .  # this line has a different background, but we don't test that yet
    .a0bc           ┊d1ef          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  memory-should-contain [
    5 <- 2  # cursor column of recipe editor
    7 <- 18  # cursor column of sandbox editor
  ]
  # show the cursor at the right window
  run [
    print-character screen:address, 9251/␣/cursor
  ]
  screen-should-contain [
    .           run (F4)           .
    .a0bc           ┊d1␣f          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario multiple-editors-cover-only-their-own-areas [
  $close-trace
  assume-screen 60/width, 10/height
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [def]
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    render-all screen, 3:address:programming-environment-data
  ]
  # divider isn't messed up
  screen-should-contain [
    .                                         run (F4)           .
    .abc                           ┊def                          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              ┊                             .
    .                              ┊                             .
  ]
]

scenario editor-in-focus-keeps-cursor [
  $close-trace
  assume-screen 30/width, 5/height
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  # initialize programming environment and highlight cursor
  assume-console []
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # is cursor at the right place?
  screen-should-contain [
    .           run (F4)           .
    .␣bc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # now try typing a letter
  assume-console [
    type [z]
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # cursor should still be right
  screen-should-contain [
    .           run (F4)           .
    .z␣bc           ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario backspace-in-sandbox-editor-joins-lines [
  $close-trace
  assume-screen 30/width, 5/height
  # initialize sandbox side with two lines
  1:address:array:character <- new []
  2:address:array:character <- new [abc
def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊def           .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # position cursor at start of second line and hit backspace
  assume-console [
    left-click 2, 16
    type [«]
  ]
  4:event/backspace <- merge 0/text, 8/backspace, 0/dummy, 0/dummy
  replace-in-console 171/«, 4:event/backspace
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # cursor moves to end of old line
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc␣ef        .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

recipe render-all [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 10, [app], [render all]
  hide-screen screen
  # top menu
  trace 11, [app], [render top menu]
  width:number <- screen-width screen
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  # error message
  trace 11, [app], [render status]
  recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
  }
  # dotted line down the middle
  trace 11, [app], [render divider]
  divider:number, _ <- divide-with-remainder width, 2
  height:number <- screen-height screen
  draw-vertical screen, divider, 1/top, height, 9482/vertical-dotted
  #
  screen <- render-recipes screen, env
  screen <- render-sandbox-side screen, env
  #
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?
  #
  show-screen screen
  reply screen/same-as-ingredient:0
]

recipe render-minimal [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  hide-screen screen
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  {
    break-if sandbox-in-focus?
    screen <- render-recipes screen, env
    cursor-row:number <- get *recipes, cursor-row:offset
    cursor-column:number <- get *recipes, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?
    screen <- render-sandbox-side screen, env
    cursor-row:number <- get *current-sandbox, cursor-row:offset
    cursor-column:number <- get *current-sandbox, cursor-column:offset
  }
  screen <- move-cursor screen, cursor-row, cursor-column
  show-screen screen
  reply screen/same-as-ingredient:0
]

recipe render-recipes [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 11, [app], [render recipes]
  recipes:address:editor-data <- get *env, recipes:offset
  # render recipes
  left:number <- get *recipes, left:offset
  right:number <- get *recipes, right:offset
  row:number, column:number, screen <- render screen, recipes
  clear-line-delimited screen, column, right
  recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
  {
    # print any warnings
    break-unless recipe-warnings
    row, screen <- render-string screen, recipe-warnings, left, right, 1/red, row
  }
  {
    # no warnings? move to next line
    break-if recipe-warnings
    row <- add row, 1
  }
  # draw dotted line after recipes
  draw-horizontal screen, row, left, right, 9480/horizontal-dotted
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

recipe update-cursor [
  local-scope
  screen:address <- next-ingredient
  recipes:address:editor-data <- next-ingredient
  current-sandbox:address:editor-data <- next-ingredient
  sandbox-in-focus?:boolean <- next-ingredient
  {
    break-if sandbox-in-focus?
#?     $print [recipes in focus
#? ] #? 1
    cursor-row:number <- get *recipes, cursor-row:offset
    cursor-column:number <- get *recipes, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?
#?     $print [sandboxes in focus
#? ] #? 1
    cursor-row:number <- get *current-sandbox, cursor-row:offset
    cursor-column:number <- get *current-sandbox, cursor-column:offset
  }
  screen <- move-cursor screen, cursor-row, cursor-column
  reply screen/same-as-ingredient:0
]

# ctrl-l - redraw screen (just in case it printed junk somehow)

after +global-type [
  {
    redraw-screen??:boolean <- equal *c, 12/ctrl-l
    break-unless redraw-screen??
    screen <- render-all screen, env:address:programming-environment-data
    loop +next-event:label
  }
]

# ctrl-n - switch focus
# todo: test this

after +global-type [
  {
    switch-side?:boolean <- equal *c, 14/ctrl-n
    break-unless switch-side?
    *sandbox-in-focus? <- not *sandbox-in-focus?
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    loop +next-event:label
  }
]

# ctrl-x - maximize/unmaximize the side with focus

scenario maximize-side [
  $close-trace
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  screen <- render-all screen, 3:address:programming-environment-data
  screen-should-contain [
    .           run (F4)           .
    .abc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit ctrl-x
  assume-console [
    type [x]
  ]
  4:event/ctrl-x <- merge 0/text, 24/ctrl-x, 0/dummy, 0/dummy
  replace-in-console 120/x, 4:event/ctrl-x
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # only left side visible
  screen-should-contain [
    .           run (F4)           .
    .abc                           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈.
    .                              .
  ]
  # hit any key to toggle back
  assume-console [
    press 24  # ctrl-x
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .           run (F4)           .
    .abc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

container programming-environment-data [
  maximized?:boolean
]

after +global-type [
  {
    maximize?:boolean <- equal *c, 24/ctrl-x
    break-unless maximize?
    screen, console <- maximize screen, console, env:address:programming-environment-data
    loop +next-event:label
  }
]

recipe maximize [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  hide-screen screen
  # maximize one of the sides
  maximized?:address:boolean <- get-address *env, maximized?:offset
  *maximized? <- copy 1/true
  #
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  {
    break-if sandbox-in-focus?
    editor:address:editor-data <- get *env, recipes:offset
    right:address:number <- get-address *editor, right:offset
    *right <- screen-width screen
    *right <- subtract *right, 1
    screen <- render-recipes screen, env
  }
  {
    break-unless sandbox-in-focus?
    editor:address:editor-data <- get *env, current-sandbox:offset
    left:address:number <- get-address *editor, left:offset
    *left <- copy 0
    screen <- render-sandbox-side screen, env
  }
  show-screen screen
  reply screen/same-as-ingredient:0, console/same-as-ingredient:1
]

# when maximized, wait for any event and simply unmaximize
after +handle-event [
  {
    maximized?:address:boolean <- get-address *env, maximized?:offset
    break-unless *maximized?
    *maximized? <- copy 0/false
    # undo maximize
    {
      break-if *sandbox-in-focus?
      editor:address:editor-data <- get *env, recipes:offset
      right:address:number <- get-address *editor, right:offset
      *right <- screen-width screen
      *right <- divide *right, 2
      *right <- subtract *right, 1
    }
    {
      break-unless *sandbox-in-focus?
      editor:address:editor-data <- get *env, current-sandbox:offset
      left:address:number <- get-address *editor, left:offset
      *left <- screen-width screen
      *left <- divide *left, 2
      *left <- add *left, 1
    }
    render-all screen, env
    show-screen screen
    loop +next-event:label
  }
]

## running code from the editor and creating sandboxes

container sandbox-data [
  data:address:array:character
  response:address:array:character
  warnings:address:array:character
  trace:address:array:character
  expected-response:address:array:character
  # coordinates to track clicks
  starting-row-on-screen:number
  code-ending-row-on-screen:number
  response-starting-row-on-screen:number
  display-trace?:boolean
  screen:address:screen  # prints in the sandbox go here
  next-sandbox:address:sandbox-data
]

scenario run-and-show-results [
  $close-trace  # trace too long for github
  assume-screen 100/width, 15/height
  # recipe editor is empty
  1:address:array:character <- new []
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [divide-with-remainder 11, 3]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   divide-with-remainder 11, 3                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊                                                 .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # run another command
  assume-console [
    left-click 1, 80
    type [add 2, 2]
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

# hook into event-loop recipe: read non-unicode keypress from k, process it if
# necessary, then go to next level
after +global-keypress [
  # F4? load all code and run all sandboxes.
  {
    do-run?:boolean <- equal *k, 65532/F4
    break-unless do-run?
    status:address:array:character <- new [running...  ]
    screen <- update-status screen, status, 245/grey
    screen, error?:boolean <- run-sandboxes env, screen
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env
    {
      break-if error?
      status:address:array:character <- new [            ]
      screen <- update-status screen, status, 245/grey
    }
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    loop +next-event:label
  }
]

recipe run-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  screen:address <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  # copy code from recipe editor, persist, load into mu, save any warnings
  in:address:array:character <- editor-contents recipes
  save [recipes.mu], in
  recipe-warnings:address:address:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  {
    break-unless *recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
    reply screen/same-as-ingredient:1, 1/errors-found
  }
  # check contents of right editor (sandbox)
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:sandbox-data <- new sandbox-data:type
    data:address:address:array:character <- get-address *new-sandbox, data:offset
    *data <- copy sandbox-contents
    # push to head of sandbox list
    dest:address:address:sandbox-data <- get-address *env, sandbox:offset
    next:address:address:sandbox-data <- get-address *new-sandbox, next-sandbox:offset
    *next <- copy *dest
    *dest <- copy new-sandbox
    # clear sandbox editor
    init:address:address:duplex-list <- get-address *current-sandbox, data:offset
    *init <- push-duplex 167/§, 0/tail
    top-of-screen:address:address:duplex-list <- get-address *current-sandbox, top-of-screen:offset
    *top-of-screen <- copy *init
  }
  # save all sandboxes before running, just in case we die when running
  save-sandboxes env
  # run all sandboxes
  curr:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    data <- get-address *curr, data:offset
    response:address:address:array:character <- get-address *curr, response:offset
    warnings:address:address:array:character <- get-address *curr, warnings:offset
    trace:address:address:array:character <- get-address *curr, trace:offset
    fake-screen:address:address:screen <- get-address *curr, screen:offset
    *response, *warnings, *fake-screen, *trace, completed?:boolean <- run-interactive *data
    {
      break-if *warnings
      break-if completed?:boolean
      *warnings <- new [took too long!
]
    }
    curr <- get *curr, next-sandbox:offset
    loop
  }
  reply screen/same-as-ingredient:1, 0/no-errors-found
]

recipe update-status [
  local-scope
  screen:address <- next-ingredient
  msg:address:array:character <- next-ingredient
  color:number <- next-ingredient
  screen <- move-cursor screen, 0, 2
  screen <- print-string screen, msg, color, 238/grey/background
  reply screen/same-as-ingredient:0
]

recipe save-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:sandbox-data <- get *env, sandbox:offset
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  {
    break-unless curr
    data:address:array:character <- get *curr, data:offset
    filename:address:array:character <- integer-to-decimal-string idx
    save filename, data
    {
      expected-response:address:array:character <- get *curr, expected-response:offset
      break-unless expected-response
      filename <- string-append filename, suffix
      save filename, expected-response
    }
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

recipe render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 11, [app], [render sandbox side]
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-screen-from screen, row, column, left, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row
  clear-rest-of-screen screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

recipe render-sandboxes [
  local-scope
  screen:address <- next-ingredient
  sandbox:address:sandbox-data <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless sandbox, row/same-as-ingredient:4, screen/same-as-ingredient:0
  screen-height:number <- screen-height screen
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?:boolean, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # render sandbox menu
  row <- add row, 1
  screen <- move-cursor screen, row, left
  clear-line-delimited screen, left, right
  print-character screen, 120/x, 245/grey
  # save menu row so we can detect clicks to it later
  starting-row:address:number <- get-address *sandbox, starting-row-on-screen:offset
  *starting-row <- copy row
  # render sandbox contents
  sandbox-data:address:array:character <- get *sandbox, data:offset
  row, screen <- render-string screen, sandbox-data, left, right, 7/white, row
  code-ending-row:address:number <- get-address *sandbox, code-ending-row-on-screen:offset
  *code-ending-row <- copy row
  # render sandbox warnings, screen or response, in that order
  response-starting-row:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
  sandbox-response:address:array:character <- get *sandbox, response:offset
  sandbox-warnings:address:array:character <- get *sandbox, warnings:offset
  sandbox-screen:address <- get *sandbox, screen:offset
  +render-sandbox-results
  {
    break-unless sandbox-warnings
    *response-starting-row <- copy 0  # no response
    row, screen <- render-string screen, sandbox-warnings, left, right, 1/red, row
  }
  {
    break-if sandbox-warnings
    empty-screen?:boolean <- fake-screen-is-empty? sandbox-screen
    break-if empty-screen?
    row, screen <- render-screen screen, sandbox-screen, left, right, row
  }
  {
    break-if sandbox-warnings
    break-unless empty-screen?
#?     $print [display response from ], row, 10/newline #? 1
    *response-starting-row <- add row, 1
    +render-sandbox-response
    row, screen <- render-string screen, sandbox-response, left, right, 245/grey, row
  }
  +render-sandbox-end
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # draw solid line after sandbox
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  # draw next sandbox
  next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row
  reply row/same-as-ingredient:4, screen/same-as-ingredient:0
]

# assumes programming environment has no sandboxes; restores them from previous session
recipe restore-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  # read all scenarios, pushing them to end of a list of scenarios
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  curr:address:address:sandbox-data <- get-address *env, sandbox:offset
  {
    filename:address:array:character <- integer-to-decimal-string idx
    contents:address:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    *curr <- new sandbox-data:type
    data:address:address:array:character <- get-address **curr, data:offset
    *data <- copy contents
    # restore expected output for sandbox if it exists
    {
      filename <- string-append filename, suffix
      contents <- restore filename
      break-unless contents
      expected-response:address:address:array:character <- get-address **curr, expected-response:offset
      *expected-response <- copy contents
    }
    +continue
    idx <- add idx, 1
    curr <- get-address **curr, next-sandbox:offset
    loop
  }
  reply env/same-as-ingredient:0
]

# row, screen <- render-screen screen:address, sandbox-screen:address, left:number, right:number, row:number
# print the fake sandbox screen to 'screen' with appropriate delimiters
# leave cursor at start of next line
recipe render-screen [
  local-scope
  screen:address <- next-ingredient
  s:address:screen <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  row <- add row, 1
  reply-unless s, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # print 'screen:'
  header:address:array:character <- new [screen:]
  row <- subtract row, 1  # compensate for render-string below
  row <- render-string screen, header, left, right, 245/grey, row
  # newline
  row <- add row, 1
  screen <- move-cursor screen, row, left
  # start printing s
  column:number <- copy left
  s-width:number <- screen-width s
  s-height:number <- screen-height s
  buf:address:array:screen-cell <- get *s, data:offset
  stop-printing:number <- add left, s-width, 3
  max-column:number <- min stop-printing, right
  i:number <- copy 0
  len:number <- length *buf
  screen-height:number <- screen-height screen
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    column <- copy left
    screen <- move-cursor screen, row, column
    # initial leader for each row: two spaces and a '.'
    print-character screen, 32/space, 245/grey
    print-character screen, 32/space, 245/grey
    print-character screen, 46/full-stop, 245/grey
    column <- add left, 3
    {
      # print row
      row-done?:boolean <- greater-or-equal column, max-column
      break-if row-done?
      curr:screen-cell <- index *buf, i
      c:character <- get curr, contents:offset
      print-character screen, c, 245/grey
      column <- add column, 1
      i <- add i, 1
      loop
    }
    # print final '.'
    print-character screen, 46/full-stop, 245/grey
    column <- add column, 1
    {
      # clear rest of current line
      line-done?:boolean <- greater-than column, right
      break-if line-done?
      print-character screen, 32/space
      column <- add column, 1
      loop
    }
    row <- add row, 1
    loop
  }
  reply row/same-as-ingredient:4, screen/same-as-ingredient:0
]

scenario run-updates-results [
  $close-trace  # trace too long for github
  assume-screen 100/width, 12/height
  # define a recipe (no indent for the 'add' line below so column numbers are more obvious)
  1:address:array:character <- new [ 
recipe foo [
z:number <- add 2, 2
]]
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 2                              ┊                                                x.
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  assume-console [
    left-click 3, 28  # one past the value of the second arg
    type [«3]  # replace
    press 65532  # F4
  ]
  4:event/backspace <- merge 0/text, 8/backspace, 0/dummy, 0/dummy
  replace-in-console 171/«, 4:event/backspace
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen updates the result on the right
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 3                              ┊                                                x.
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊5                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings [
  $close-trace  # trace too long for github
  assume-screen 100/width, 10/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints error message in red
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   get 1234:number, foo:offset                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   unknown element foo in container number          .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings-only-once [
  $close-trace  # trace too long for github
  assume-screen 100/width, 10/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors multiple times
  assume-console [
    press 65532  # F4
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-manages-screen-per-sandbox [
  $close-trace  # trace too long for github
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an instruction
  2:address:array:character <- new [print-integer screen:address, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editor
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that it prints a little toy screen
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊print-integer screen:address, 4                  .
    .                                                  ┊screen:                                          .
    .                                                  ┊  .4                             .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario sandbox-with-print-can-be-edited [
  $close-trace
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an instruction
  2:address:array:character <- new [print-integer screen:address, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the sandbox
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊print-integer screen:address, 4                  .
    .                                                  ┊screen:                                          .
    .                                                  ┊  .4                             .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # edit the sandbox
  assume-console [
    left-click 3, 70
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊print-integer screen:address, 4                  .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario sandbox-can-handle-infinite-loop [
  $close-trace
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new [recipe foo [
  {
    loop
  }
]]
  # right editor contains an instruction
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the sandbox
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  {                                               ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .    loop                                          ┊                                                x.
    .  }                                               ┊foo                                              .
    .]                                                 ┊took too long!                                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

recipe editor-contents [
  local-scope
  editor:address:editor-data <- next-ingredient
  buf:address:buffer <- new-buffer 80
  curr:address:duplex-list <- get *editor, data:offset
  # skip § sentinel
  assert curr, [editor without data is illegal; must have at least a sentinel]
  curr <- next-duplex curr
  reply-unless curr, 0
  {
    break-unless curr
    c:character <- get *curr, value:offset
    buffer-append buf, c
    curr <- next-duplex curr
    loop
  }
  result:address:array:character <- buffer-to-array buf
  reply result
]

scenario editor-provides-edited-contents [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  assume-console [
    left-click 1, 2
    type [def]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:address:array:character <- editor-contents 2:address:editor-data
    4:array:character <- copy *3:address:array:character
  ]
  memory-should-contain [
    4:string <- [abdefc]
  ]
]

## editing sandboxes after they've been created

scenario clicking-on-a-sandbox-moves-it-to-editor [
  $close-trace
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  add 2, 2
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press 65532  # F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click somewhere on the sandbox
  assume-console [
    left-click 3, 30
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # it pops back into editor
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊foo                .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                   .
    .]                   ┊                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                   .
    .                    ┊                   .
    .                    ┊                   .
  ]
]

after +global-touch [
  # right side of screen and below sandbox editor? pop appropriate sandbox
  # contents back into sandbox editor provided it's empty
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get *t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get *t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    empty-sandbox-editor?:boolean <- empty-editor? current-sandbox
    break-unless empty-sandbox-editor?  # make the user hit F4 before editing a new sandbox
    # identify the sandbox to edit and remove it from the sandbox list
    sandbox:address:sandbox-data <- extract-sandbox env, click-row
    text:address:array:character <- get *sandbox, data:offset
    current-sandbox <- insert-text current-sandbox, text
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    show-screen screen
    loop +next-event:label
  }
]

recipe empty-editor? [
  local-scope
  editor:address:editor-data <- next-ingredient
  head:address:duplex-list <- get *editor, data:offset
  first:address:duplex-list <- next-duplex head
  result:boolean <- not first
  reply result
]

recipe extract-sandbox [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  click-row:number <- next-ingredient
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:address:sandbox-data <- get-address *env, sandbox:offset
  start:number <- get **sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  {
    next-sandbox:address:sandbox-data <- get **sandbox, next-sandbox:offset
    break-unless next-sandbox
    # if click-row < sandbox.next-sandbox.starting-row-on-screen, break
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- get-address **sandbox, next-sandbox:offset
    loop
  }
  # snip sandbox out of its list
  result:address:sandbox-data <- copy *sandbox
  *sandbox <- copy next-sandbox
  reply result
]

## deleting sandboxes

scenario deleting-sandboxes [
  $close-trace  # trace too long for github
  assume-screen 100/width, 15/height
  1:address:array:character <- new []
  2:address:array:character <- new []
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run a few commands
  assume-console [
    left-click 1, 80
    type [divide-with-remainder 11, 3]
    press 65532  # F4
    type [add 2, 2]
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # delete second sandbox
  assume-console [
    left-click 7, 99
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
  # delete first sandbox
  assume-console [
    left-click 3, 99
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
]

after +global-touch [
  # on a sandbox delete icon? process delete
  {
    was-delete?:boolean <- delete-sandbox *t, env
    break-unless was-delete?
#?     trace 10, [app], [delete clicked] #? 1
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    show-screen screen
    loop +next-event:label
  }
]

# was-deleted?:boolean <- delete-sandbox t:touch-event, env:address:programming-environment-data
recipe delete-sandbox [
  local-scope
  t:touch-event <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  click-column:number <- get t, column:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  right:number <- get *current-sandbox, right:offset
  at-right?:boolean <- equal click-column, right
  reply-unless at-right?, 0/false
  click-row:number <- get t, row:offset
  prev:address:address:sandbox-data <- get-address *env, sandbox:offset
  curr:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    # more sandboxes to check
    {
      target-row:number <- get *curr, starting-row-on-screen:offset
      delete-curr?:boolean <- equal target-row, click-row
      break-unless delete-curr?
      # delete this sandbox, rerender and stop
      *prev <- get *curr, next-sandbox:offset
      reply 1/true
    }
    prev <- get-address *curr, next-sandbox:offset
    curr <- get *curr, next-sandbox:offset
    loop
  }
  reply 0/false
]

## clicking on sandbox results to 'fix' them and turn sandboxes into tests

scenario sandbox-click-on-result-toggles-color-to-green [
  $close-trace
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  add 2, 2
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press 65532  # F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click on the '4' in the result
  assume-console [
    left-click 5, 21
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # color toggles to green
  screen-should-contain-in-color 2/green, [
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                     4                  .
    .                                        .
    .                                        .
  ]
  # cursor should remain unmoved
  run [
    print-character screen:address, 9251/␣/cursor
  ]
  screen-should-contain [
    .                     run (F4)           .
    .␣                   ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # now change the second arg of the 'add'
  # then rerun
  assume-console [
    left-click 3, 11  # cursor to end of line
    type [«3]  # turn '2' into '3'
    press 65532  # F4
  ]
  4:event/backspace <- merge 0/text, 8/backspace, 0/dummy, 0/dummy
  replace-in-console 171/«, 4:event/backspace
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # result turns red
  screen-should-contain-in-color 1/red, [
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                     5                  .
    .                                        .
    .                                        .
  ]
]

# clicks on sandbox responses save it as 'expected'
after +global-touch [
  # right side of screen? check if it's inside the output of any sandbox
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get *t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get *t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    # identify the sandbox whose output is being clicked on
    sandbox:address:sandbox-data <- find-click-in-sandbox-output env, click-row
    break-unless sandbox
    # toggle its expected-response, and save session
    sandbox <- toggle-expected-response sandbox
    save-sandboxes env
    hide-screen screen
    screen <- render-sandbox-side screen, env, 1/clear
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    # no change in cursor
    show-screen screen
    loop +next-event:label
  }
]

recipe find-click-in-sandbox-output [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  click-row:number <- next-ingredient
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  start:number <- get *sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  # while click-row < sandbox.next-sandbox.starting-row-on-screen
  {
    next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
    break-unless next-sandbox
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- copy next-sandbox
    loop
  }
  # return sandbox if click is in its output region
  response-starting-row:number <- get *sandbox, response-starting-row-on-screen:offset
  reply-unless response-starting-row, 0/no-click-in-sandbox-output
  click-in-response?:boolean <- greater-or-equal click-row, response-starting-row
  reply-unless click-in-response?, 0/no-click-in-sandbox-output
  reply sandbox
]

recipe toggle-expected-response [
  local-scope
  sandbox:address:sandbox-data <- next-ingredient
  expected-response:address:address:array:character <- get-address *sandbox, expected-response:offset
  {
    # if expected-response is set, reset
    break-unless *expected-response
    *expected-response <- copy 0
    reply sandbox/same-as-ingredient:0
  }
  # if not, current response is the expected response
  response:address:array:character <- get *sandbox, response:offset
  *expected-response <- copy response
  reply sandbox/same-as-ingredient:0
]

# when rendering a sandbox, color it in red/green if expected response exists
after +render-sandbox-response [
  {
    break-unless sandbox-response
    expected-response:address:array:character <- get *sandbox, expected-response:offset
    break-unless expected-response  # fall-through to print in grey
    response-is-expected?:boolean <- string-equal expected-response, sandbox-response
    {
      break-if response-is-expected?:boolean
      row, screen <- render-string screen, sandbox-response, left, right, 1/red, row
    }
    {
      break-unless response-is-expected?:boolean
      row, screen <- render-string screen, sandbox-response, left, right, 2/green, row
    }
    jump +render-sandbox-end:label
  }
]

## clicking on the code typed into a sandbox toggles its trace

scenario sandbox-click-on-code-toggles-app-trace [
  $close-trace
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  stash [abc]
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press 65532  # F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  stash [abc]       ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click on the 'foo' line in the sandbox
  assume-console [
    left-click 4, 21
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # trace now printed and cursor shouldn't have budged
  screen-should-contain [
    .                     run (F4)           .
    .␣                   ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  stash [abc]       ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊abc                .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                        .
    .                    ┊                   .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                  x.
    .                    ┊                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊abc                .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click again on the same region
  assume-console [
    left-click 4, 25
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # trace hidden again
  screen-should-contain [
    .                     run (F4)           .
    .␣                   ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  stash [abc]       ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
]

scenario sandbox-shows-app-trace-and-result [
  $close-trace
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  stash [abc]
  add 2, 2
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press 65532  # F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  stash [abc]       ┊                  x.
    .  add 2, 2          ┊foo                .
    .]                   ┊4                  .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click on the 'foo' line in the sandbox
  assume-console [
    left-click 4, 21
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # trace now printed
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  stash [abc]       ┊                  x.
    .  add 2, 2          ┊foo                .
    .]                   ┊abc                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
]

# clicks on sandbox code toggle its display-trace? flag
after +global-touch [
  # right side of screen? check if it's inside the code of any sandbox
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get *t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get *t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    # identify the sandbox whose code is being clicked on
    sandbox:address:sandbox-data <- find-click-in-sandbox-code env, click-row
    break-unless sandbox
    # toggle its display-trace? property
    x:address:boolean <- get-address *sandbox, display-trace?:offset
    *x <- not *x
    hide-screen screen
    screen <- render-sandbox-side screen, env, 1/clear
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    # no change in cursor
    show-screen screen
    loop +next-event:label
  }
]

recipe find-click-in-sandbox-code [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  click-row:number <- next-ingredient
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  start:number <- get *sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  # while click-row < sandbox.next-sandbox.starting-row-on-screen
  {
    next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
    break-unless next-sandbox
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- copy next-sandbox
    loop
  }
  # return sandbox if click is in its code region
  code-ending-row:number <- get *sandbox, code-ending-row-on-screen:offset
  click-above-response?:boolean <- lesser-or-equal click-row, code-ending-row
  start:number <- get *sandbox, starting-row-on-screen:offset
  click-below-menu?:boolean <- greater-than click-row, start
  click-on-sandbox-code?:boolean <- and click-above-response?, click-below-menu?
  {
    break-if click-on-sandbox-code?
    reply 0/no-click-in-sandbox-output
  }
  reply sandbox
]

# when rendering a sandbox, dump its trace before response/warning if display-trace? property is set
after +render-sandbox-results [
  {
    display-trace?:boolean <- get *sandbox, display-trace?:offset
    break-unless display-trace?
    sandbox-trace:address:array:character <- get *sandbox, trace:offset
    break-unless sandbox-trace  # nothing to print; move on
#?     $print [display trace from ], row, 10/newline #? 1
    row, screen <- render-string, screen, sandbox-trace, left, right, 245/grey, row
    row <- subtract row, 1  # trim the trailing newline that's always present
  }
]

## handling malformed programs

scenario run-shows-warnings-in-get [
  $close-trace
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  get 123:number, foo:offset                      ┊                                                 .
    .]                                                 ┊                                                 .
    .unknown element foo in container number           ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found                                                                                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .unknown element foo in container number                                                             .
    .                                                                                                    .
  ]
]

scenario run-shows-missing-type-warnings [
  $close-trace
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .]                                                 ┊                                                 .
    .missing type in 'x <- copy 0'                     ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-unbalanced-bracket-warnings [
  $close-trace
  assume-screen 100/width, 15/height
  # recipe is incomplete (unbalanced '[')
  1:address:array:character <- new [ 
recipe foo «
  x <- copy 0
]
  string-replace 1:address:array:character, 171/«, 91  # '['
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo \\\[                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .                                                  ┊                                                 .
    .9: unbalanced '\\\[' for recipe                      ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-get-on-non-container-warnings [
  $close-trace
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:address:point <- new point:type
  get x:address:point, 1:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:address:point <- new point:type               ┊                                                x.
    .  get x:address:point, 1:offset                   ┊foo                                              .
    .]                                                 ┊foo: first ingredient of 'get' should be a conta↩.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊iner, but got x:address:point                    .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-non-literal-get-argument-warnings [
  $close-trace
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy 0
  y:address:point <- new point:type
  get *y:address:point, x:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy 0                              ┊                                                 .
    .  y:address:point <- new point:type               ┊                                                 .
    .  get *y:address:point, x:number                  ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: expected ingredient 1 of 'get' to have type ↩┊                                                 .
    .'offset'; got x:number                            ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-warnings-everytime [
  $close-trace
  # try to run a file with an error
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy y:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .use before set: y in foo                          ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  # rerun the file, check for the same error
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .use before set: y in foo                          ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

## undo/redo

# for every undoable event, create a type of *operation* that contains all the
# information needed to reverse it
exclusive-container operation [
  typing:insert-operation
  move:move-operation
  delete:delete-operation
]

container insert-operation [
  before-row:number
  before-column:number
  before-top-of-screen:address:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:duplex-list:character
  insert-from:address:duplex-list:character
  insert-until:address:duplex-list:character
]

container move-operation [
  before-row:number
  before-column:number
  before-top-of-screen:address:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:duplex-list:character
]

container delete-operation [
  before-row:number
  before-column:number
  before-top-of-screen:address:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:duplex-list:character
  deleted:address:duplex-list:character
  deleted-from:address:duplex-list:character
]

# every editor accumulates a list of operations to undo/redo
container editor-data [
  undo:address:list:address:operation
  redo:address:list:address:operation
]

# ctrl-z - undo operation
after +handle-special-character [
  {
    undo?:boolean <- equal *c, 26/ctrl-z
    break-unless undo?
    undo:address:address:list <- get-address *editor, undo:offset
    break-unless *undo
    op:address:operation <- first *undo
    *undo <- rest *undo
    redo:address:address:list <- get-address *editor, redo:offset
    *redo <- push op, *redo
    +handle-undo
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# ctrl-y - redo operation
after +handle-special-character [
  {
    redo?:boolean <- equal *c, 25/ctrl-y
    break-unless redo?
    redo:address:address:list <- get-address *editor, redo:offset
    break-unless *redo
    op:address:operation <- first *redo
    *redo <- rest *redo
    undo:address:address:list <- get-address *editor, undo:offset
    *undo <- push op, *undo
    +handle-redo
    reply screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# undo typing

scenario editor-can-undo-typing [
  # create an editor and type a character
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [0]
  ]
  editor-event-loop screen:address, console:address, 2:address:editor-data
  # now undo
  assume-console [
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # character should be gone
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .1         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# save operation to undo
after +insert-character-begin [
  top-before:address:duplex-list <- get *editor, top-of-screen:offset
]
before +insert-character-end [
  top-after:address:duplex-list <- get *editor, top-of-screen:offset
  undo:address:address:list <- get-address *editor, undo:offset
  {
    # if previous operation was an insert, merge with it
    break-unless *undo
    op:address:operation <- first *undo
    typing:address:insert-operation <- maybe-convert *op, typing:variant
    break-unless typing
    insert-until:address:address:duplex-list <- get-address *typing, insert-until:offset
    *insert-until <- next-duplex *before-cursor
    after-row:address:number <- get-address *typing, after-row:offset
    *after-row <- copy *cursor-row
    after-column:address:number <- get-address *typing, after-column:offset
    *after-column <- copy *cursor-column
    after-top:address:number <- get-address *typing, after-top-of-screen:offset
    *after-top <- get *editor, top-of-screen:offset
    jump +done-inserting-character:label
  }
  # it so happens that before-cursor is at the character we just inserted
  insert-from:address:duplex-list <- copy *before-cursor
  insert-to:address:duplex-list <- next-duplex insert-from
  op:address:operation <- new operation:type
  *op <- merge 0/insert-operation, save-row/before, save-column/before, top-before, *cursor-row/after, *cursor-column/after, top-after, insert-from, insert-to
  *undo <- push op, *undo
  +done-inserting-character
]

after +handle-undo [
  {
    typing:address:insert-operation <- maybe-convert *op, typing:variant
    break-unless typing
    start:address:duplex-list <- get *typing, insert-from:offset
    end:address:duplex-list <- get *typing, insert-until:offset
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    *before-cursor <- prev-duplex start
    remove-duplex-between *before-cursor, end
    *cursor-row <- get *typing, before-row:offset
    *cursor-column <- get *typing, before-column:offset
    top:address:address:duplex-list <- get *editor, top-of-screen:offset
    *top <- get *typing, before-top-of-screen:offset
  }
]

scenario editor-can-undo-typing-multiple [
  # create an editor and type multiple characters
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [012]
  ]
  editor-event-loop screen:address, console:address, 2:address:editor-data
  # now undo
  assume-console [
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # all characters must be gone
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-can-undo-typing-multiple-2 [
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:array:character <- new [a]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  # type some characters
  assume-console [
    type [012]
  ]
  editor-event-loop screen:address, console:address, 2:address:editor-data
  screen-should-contain [
    .          .
    .012a      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # now undo
  assume-console [
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # back to original text
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor should be in the right place
  assume-console [
    type [3]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .3a        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# redo typing

scenario editor-redo-typing [
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  1:address:array:character <- new [a]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [012]
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  editor-event-loop screen:address, console:address, 2:address:editor-data
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    type [y]  # ctrl-y
  ]
  4:event/ctrl-y <- merge 0/text, 25/ctrl-y, 0/dummy, 0/dummy
  replace-in-console 121/y, 4:event/ctrl-y
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # all characters must be back
  screen-should-contain [
    .          .
    .012a      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor should be in the right place
  assume-console [
    type [3]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0123a     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-redo-typing-empty [
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [012]
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  editor-event-loop screen:address, console:address, 2:address:editor-data
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    type [y]  # ctrl-y
  ]
  4:event/ctrl-y <- merge 0/text, 25/ctrl-y, 0/dummy, 0/dummy
  replace-in-console 121/y, 4:event/ctrl-y
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # all characters must be back
  screen-should-contain [
    .          .
    .012       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor should be in the right place
  assume-console [
    type [3]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0123      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after +handle-redo [
  {
    typing:address:insert-operation <- maybe-convert *op, typing:variant
    break-unless typing
    insert-from:address:duplex-list <- get *typing, insert-from:offset
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    insert-duplex-range *before-cursor, insert-from
    *cursor-row <- get *typing, after-row:offset
    *cursor-column <- get *typing, after-column:offset
    top:address:address:duplex-list <- get *editor, top-of-screen:offset
    *top <- get *typing, after-top-of-screen:offset
  }
]

# undo cursor movement and scroll

scenario editor-can-undo-touch [
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def
ghi]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    left-click 3, 1
  ]
  editor-event-loop screen:address, console:address, 2:address:editor-data
  # undo
  assume-console [
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # click undone
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .1abc      .
    .def       .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after +move-cursor-start [
  before-cursor-row:number <- get *editor, cursor-row:offset
  before-cursor-column:number <- get *editor, cursor-column:offset
  before-top-of-screen:address:duplex-list <- get *editor, top-of-screen:offset
]
before +move-cursor-end [
  after-cursor-row:number <- get *editor, cursor-row:offset
  after-cursor-column:number <- get *editor, cursor-column:offset
  after-top-of-screen:address:duplex-list <- get *editor, top-of-screen:offset
  op:address:operation <- new operation:type
  *op <- merge 1/move-operation, before-cursor-row, before-cursor-column, before-top-of-screen, after-cursor-row, after-cursor-column, after-top-of-screen, 0/empty, 0/empty
  undo:address:address:list <- get-address *editor, undo:offset
  *undo <- push op, *undo
]

after +handle-undo [
  {
    move:address:move-operation <- maybe-convert *op, move:variant
    break-unless move
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    top:address:address:duplex-list <- get-address *editor, top-of-screen:offset
    *cursor-row <- get *move, before-row:offset
    *cursor-column <- get *move, before-column:offset
    *top <- get *move, before-top-of-screen:offset
  }
]

scenario editor-can-undo-scroll [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a wrapped line
  1:address:array:character <- new [a
b
cdefgh]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press 65514  # right arrow
  ]
  editor-event-loop screen:address, console:address, 2:address:editor-data
  3:number <- get *2:address:editor-data, cursor-row:offset
  4:number <- get *2:address:editor-data, cursor-column:offset
  # screen scrolls
  screen-should-contain [
    .     .
    .b    .
    .cdef↩.
    .gh   .
  ]
  memory-should-contain [
    3 <- 3
    4 <- 0
  ]
  # undo
  assume-console [
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moved back
  memory-should-contain [
    3 <- 3
    4 <- 3
  ]
  # scroll undone
  screen-should-contain [
    .     .
    .a    .
    .b    .
    .cdef↩.
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .     .
    .b    .
    .cde1↩.
    .fgh  .
  ]
]

# redo cursor movement and scroll

scenario editor-redo-touch [
  # create an editor with some text, click on a character, undo
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def
ghi]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console [
    left-click 3, 1
    type [z]  # ctrl-z
  ]
  3:event/ctrl-z <- merge 0/text, 26/ctrl-z, 0/dummy, 0/dummy
  replace-in-console 122/z, 3:event/ctrl-z
  editor-event-loop screen:address, console:address, 2:address:editor-data
  # redo
  assume-console [
    type [y]  # ctrl-y
  ]
  4:event/ctrl-y <- merge 0/text, 25/ctrl-y, 0/dummy, 0/dummy
  replace-in-console 121/y, 4:event/ctrl-y
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor moves to left-click
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .g1hi      .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after +handle-redo [
  {
    move:address:move-operation <- maybe-convert *op, move:variant
    break-unless move
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    *cursor-row <- get *move, after-row:offset
    *cursor-column <- get *move, after-column:offset
    top:address:address:duplex-list <- get *editor, top-of-screen:offset
    *top <- get *move, after-top-of-screen:offset
  }
]

# todo:
# operations for recipe side and each sandbox-data
# undo delete sandbox as a separate primitive on the status bar
# types of operations:
#   typing
#   cursor movement and scrolling (click, arrow keys, ctrl-a, ctrl-e, page up/down, resize)
#   delete (backspace, delete, ctrl-k, ctrl-u)
# collapse runs
#   of the same event (arrow keys, etc.)
#   of typing that's not newline or backspace or tab
# render entire screen blindly on undo/redo operations for now

## helpers for drawing editor borders

recipe draw-box [
  local-scope
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  # top border
  draw-horizontal screen, top, left, right, color
  draw-horizontal screen, bottom, left, right, color
  draw-vertical screen, left, top, bottom, color
  draw-vertical screen, right, top, bottom, color
  draw-top-left screen, top, left, color
  draw-top-right screen, top, right, color
  draw-bottom-left screen, bottom, left, color
  draw-bottom-right screen, bottom, right, color
  # position cursor inside box
  screen <- move-cursor screen, top, left
  cursor-down screen
  cursor-right screen
]

recipe draw-horizontal [
  local-scope
  screen:address <- next-ingredient
  row:number <- next-ingredient
  x:number <- next-ingredient
  right:number <- next-ingredient
  style:character, style-found?:boolean <- next-ingredient
  {
    break-if style-found?
    style <- copy 9472/horizontal
  }
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  screen <- move-cursor screen, row, x
  {
    continue?:boolean <- lesser-or-equal x, right  # right is inclusive, to match editor-data semantics
    break-unless continue?
    print-character screen, style, color, bg-color
    x <- add x, 1
    loop
  }
]

recipe draw-vertical [
  local-scope
  screen:address <- next-ingredient
  col:number <- next-ingredient
  y:number <- next-ingredient
  bottom:number <- next-ingredient
  style:character, style-found?:boolean <- next-ingredient
  {
    break-if style-found?
    style <- copy 9474/vertical
  }
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  {
    continue?:boolean <- lesser-than y, bottom
    break-unless continue?
    screen <- move-cursor screen, y, col
    print-character screen, style, color
    y <- add y, 1
    loop
  }
]

recipe draw-top-left [
  local-scope
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  screen <- move-cursor screen, top, left
  print-character screen, 9484/down-right, color
]

recipe draw-top-right [
  local-scope
  screen:address <- next-ingredient
  top:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  screen <- move-cursor screen, top, right
  print-character screen, 9488/down-left, color
]

recipe draw-bottom-left [
  local-scope
  screen:address <- next-ingredient
  bottom:number <- next-ingredient
  left:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  screen <- move-cursor screen, bottom, left
  print-character screen, 9492/up-right, color
]

recipe draw-bottom-right [
  local-scope
  screen:address <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  screen <- move-cursor screen, bottom, right
  print-character screen, 9496/up-left, color
]

recipe print-string-with-gradient-background [
  local-scope
  screen:address <- next-ingredient
  s:address:array:character <- next-ingredient
  color:number <- next-ingredient
  bg-color1:number <- next-ingredient
  bg-color2:number <- next-ingredient
  len:number <- length *s
  color-range:number <- subtract bg-color2, bg-color1
  color-quantum:number <- divide color-range, len
  bg-color:number <- copy bg-color1
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *s, i
    print-character screen, c, color, bg-color
    i <- add i, 1
    bg-color <- add bg-color, color-quantum
    loop
  }
  reply screen/same-as-ingredient:0
]
