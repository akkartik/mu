# Environment for learning programming using mu.

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  open-console
  programming-environment 0:literal/screen, 0:literal/console
  close-console
]

recipe programming-environment [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  console:address <- next-ingredient
  width:number <- screen-width screen:address
  height:number <- screen-height screen:address
  # draw menu
#?   draw-horizontal screen:address, 0:literal, 0:literal/left, width:number, 95:literal/underscore
  draw-horizontal screen:address, 0:literal, 0:literal/left, width:number, 32:literal/space, 0:literal/black, 238:literal/grey
  # draw a dotted line down the middle
  divider:number, _ <- divide-with-remainder width:number, 2:literal
  draw-vertical screen:address, divider:number, 1:literal/top, height:number, 9482:literal/vertical-dotted
  # left column consists of multiple recipes
  draw-horizontal screen:address, 10:literal, 0:literal/left, divider:number, 9480:literal/horizontal-dotted
  draw-horizontal screen:address, 20:literal, 0:literal/left, divider:number, 9480:literal/horizontal-dotted
  draw-horizontal screen:address, 30:literal, 0:literal/left, divider:number, 9480:literal/horizontal-dotted
  # right column consists of multiple sandboxes isolated from each other, but
  # with access to the recipes on the left
  column2:number <- add divider:number, 1:literal
  draw-horizontal screen:address, 3:literal, column2:number, width:number, 9473:literal/horizontal-double
  # nav bar
  button-start:number <- subtract width:number, 20:literal
  move-cursor screen:address, 0:literal/row, button-start:number/column
  run-button:address:array:character <- new [  run (F9)  ]
  print-string screen:address, run-button:address:array:character, 255:literal/white, 161:literal/reddish
  # editor on the left
  left:address:array:character <- new [recipe new-add [
  x:number <- next-ingredient
  y:number <- next-ingredient
  z:number <- add x:number, y:number
]]
  left-editor:address:editor-data <- new-editor left:address:array:character, screen:address, 1:literal/top, 0:literal/left, divider:number/right
  # editor on the right
  right:address:array:character <- new [new-add 2:literal, 3:literal]
  new-left:number <- add divider:number, 1:literal
  new-right:number <- add new-left:number, 5:literal
  right-editor:address:editor-data <- new-editor right:address:array:character, screen:address, 1:literal/top, new-left:number, width:number
  # chain
  x:address:address:editor-data <- get-address left-editor:address:editor-data/deref, next-editor:offset
  x:address:address:editor-data/deref <- copy right-editor:address:editor-data
  # initialize focus
  reset-focus left-editor:address:editor-data
  cursor-row:number <- get left-editor:address:editor-data/deref, cursor-row:offset
  cursor-column:number <- get left-editor:address:editor-data/deref, cursor-column:offset
  move-cursor screen:address, cursor-row:number, cursor-column:number
  # and we're off!
  event-loop screen:address, console:address, left-editor:address:editor-data
]

scenario editor-initially-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  run [
    1:address:array:character <- new [abc]
    new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

## In which we introduce the editor data structure, and show how it displays
## text to the screen.

container editor-data [
  # doubly linked list of characters (head contains a special sentinel)
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

  # pointer to another editor, responsible for a different area of screen.
  # helps organize editors in a 'chain'.
  next-editor:address:editor-data
  in-focus?:boolean  # set for the one editor in this chain currently being edited

  # functions to run
  render:recipe-ordinal  # how to render this container
  respond:recipe-ordinal  # how it reacts to events from the console
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
  # bottom = top (in case of early exit)
  x:address:number <- get-address result:address:editor-data/deref, bottom:offset
  x:address:number/deref <- copy top:number
  # initialize cursor
  x:address:number <- get-address result:address:editor-data/deref, cursor-row:offset
  x:address:number/deref <- copy top:number
  x:address:number <- get-address result:address:editor-data/deref, cursor-column:offset
#?   $print left:number, [ 
#? ] #? 1
  x:address:number/deref <- copy left:number
  d:address:address:duplex-list <- get-address result:address:editor-data/deref, data:offset
  d:address:address:duplex-list/deref <- push-duplex 167:literal/§, 0:literal/tail
  y:address:address:duplex-list <- get-address result:address:editor-data/deref, before-cursor:offset
  y:address:address:duplex-list/deref <- copy d:address:address:duplex-list/deref
  init:address:address:duplex-list <- get-address result:address:editor-data/deref, top-of-screen:offset
  init:address:address:duplex-list/deref <- copy d:address:address:duplex-list/deref
  # set focus
  # if using multiple editors, must call reset-focus after chaining them all
  b:address:boolean <- get-address result:address:editor-data/deref, in-focus?:offset
  b:address:boolean/deref <- copy 1:literal/true
#?   $print d:address:address:duplex-list/deref, [ 
#? ] #? 1
  # early exit if s is empty
  reply-unless s:address:array:character, result:address:editor-data
  len:number <- length s:address:array:character/deref
  reply-unless len:number, result:address:editor-data
  idx:number <- copy 0:literal
  # now we can start appending the rest, character by character
  curr:address:duplex-list <- copy init:address:address:duplex-list/deref
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
    # 2 <- just the § sentinel
    # 3 (top of screen) <- the § sentinel
    # 4 (before cursor) <- the § sentinel
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
  default-space:address:array:location <- new location:type, 40:literal
  editor:address:editor-data <- next-ingredient
#?   $print [=== render
#? ] #? 2
  screen:address <- get editor:address:editor-data/deref, screen:offset
  top:number <- get editor:address:editor-data/deref, top:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  screen-height:number <- screen-height screen:address
  right:number <- get editor:address:editor-data/deref, right:offset
  hide-screen screen:address
  # traversing editor
  curr:address:duplex-list <- get editor:address:editor-data/deref, top-of-screen:offset
  prev:address:duplex-list <- copy curr:address:duplex-list
  curr:address:duplex-list <- next-duplex curr:address:duplex-list
  # traversing screen
  row:number <- copy top:number
  column:number <- copy left:number
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
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
      at-cursor-row?:boolean <- equal row:number, cursor-row:address:number/deref
      break-unless at-cursor-row?:boolean
      at-cursor?:boolean <- equal column:number, cursor-column:address:number/deref
      break-unless at-cursor?:boolean
      before-cursor:address:address:duplex-list/deref <- prev-duplex curr:address:duplex-list
#?       new-prev:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset #? 1
#?       $print [render 0: cursor adjusted to after ], new-prev:character, [(], cursor-row:address:number/deref, [, ], cursor-column:address:number/deref, [)
#? ] #? 1
    }
    c:character <- get curr:address:duplex-list/deref, value:offset
#?     $print [rendering ], c:character, [ 
#? ] #? 2
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c:character, 10:literal/newline
      break-unless newline?:boolean
      # adjust cursor if necessary
      {
        at-cursor-row?:boolean <- equal row:number, cursor-row:address:number/deref
        break-unless at-cursor-row?:boolean
        left-of-cursor?:boolean <- lesser-than column:number, cursor-column:address:number/deref
        break-unless left-of-cursor?:boolean
        cursor-column:address:number/deref <- copy column:number
        before-cursor:address:address:duplex-list/deref <- prev-duplex curr:address:duplex-list
#?         new-prev:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset #? 1
#?         $print [render 1: cursor adjusted to after ], new-prev:character, [(], cursor-row:address:number/deref, [, ], cursor-column:address:number/deref, [)
#? ] #? 1
      }
      # clear rest of line in this window
#?       $print row:number, [ ], column:number, [ ], right:number, [ 
#? ] #? 1
      {
        done?:boolean <- greater-than column:number, right:number
        break-if done?:boolean
        print-character screen:address, 32:literal/space
        column:number <- add column:number, 1:literal
#?         $print column:number, [ 
#? ] #? 1
        loop
      }
      # skip to next line
      row:number <- add row:number, 1:literal
      column:number <- copy left:number
      move-cursor screen:address, row:number, column:number
      curr:address:duplex-list <- next-duplex curr:address:duplex-list
      prev:address:duplex-list <- next-duplex prev:address:duplex-list
      loop +next-character:label
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:boolean <- equal column:number, right:number
      break-unless at-right?:boolean
      # print wrap icon
      print-character screen:address, 8617:literal/loop-back-to-left, 245:literal/grey
      column:number <- copy left:number
      row:number <- add row:number, 1:literal
      move-cursor screen:address, row:number, column:number
      # don't increment curr
      loop +next-character:label
    }
    print-character screen:address, c:character
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    prev:address:duplex-list <- next-duplex prev:address:duplex-list
    column:number <- add column:number, 1:literal
    loop
  }
  # bottom = row
  bottom:address:number <- get-address editor:address:editor-data/deref, bottom:offset
  bottom:address:number/deref <- copy row:number
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row:number, cursor-row:address:number/deref
    cursor-outside-line?:boolean <- lesser-or-equal column:number, cursor-column:address:number/deref
    before-cursor-on-same-line?:boolean <- and at-cursor-row?:boolean, cursor-outside-line?:boolean
    above-cursor-row?:boolean <- lesser-than row:number, cursor-row:address:number/deref
    before-cursor?:boolean <- or before-cursor-on-same-line?:boolean, above-cursor-row?:boolean
    break-unless before-cursor?:boolean
#?     $print [pointed after all text
#? ] #? 1
    cursor-row:address:number/deref <- copy row:number
    cursor-column:address:number/deref <- copy column:number
#?     $print [render: cursor moved to ], cursor-row:address:number/deref, [, ], cursor-column:address:number/deref, [ 
#? ] #? 1
    # line not wrapped but cursor outside bounds? wrap cursor
    {
      too-far-right?:boolean <- greater-than cursor-column:address:number/deref, right:number
      break-unless too-far-right?:boolean
      cursor-column:address:number/deref <- copy left:number
      cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
      above-screen-bottom?:boolean <- lesser-than cursor-row:address:number/deref, screen-height:number
      assert above-screen-bottom?:boolean, [unimplemented: wrapping cursor past bottom of screen]
    }
#?     $print [now ], cursor-row:address:number/deref, [, ], cursor-column:address:number/deref, [ 
#? ] #? 1
    before-cursor:address:address:duplex-list/deref <- copy prev:address:duplex-list
#?     new-prev:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset #? 1
#?     $print [render Ω: cursor adjusted to after ], new-prev:character, [(], cursor-row:address:number/deref, [, ], cursor-column:address:number/deref, [)
#? ] #? 1
  }
#?   $print [clearing ], row:number, [ ], column:number, [ ], right:number, [ 
#? ] #? 2
  {
    # clear rest of current line
    done?:boolean <- greater-or-equal row:number, screen-height:number
    break-if done?:boolean
    {
      line-done?:boolean <- greater-than column:number, right:number
      break-if line-done?:boolean
      print-character screen:address, 32:literal/space
      column:number <- add column:number, 1:literal
      loop
    }
    # clear one more line just in case we just backspaced out of it
    row:number <- add row:number, 1:literal
    column:number <- copy left:number
    done?:boolean <- greater-or-equal row:number, screen-height:number
    break-if done?:boolean
    move-cursor screen:address, row:number, column:number
    {
      line-done?:boolean <- greater-or-equal column:number, right:number
      break-if line-done?:boolean
      print-character screen:address, 32:literal/space
      column:number <- add column:number, 1:literal
      loop
    }
  }
  # update cursor
  {
    in-focus?:boolean <- get editor:address:editor-data/deref, in-focus?:offset
    break-unless in-focus?:boolean
    cursor-inside-right-margin?:boolean <- lesser-or-equal cursor-column:address:number/deref, right:number
    assert cursor-inside-right-margin?:boolean, [cursor outside right margin]
    cursor-inside-left-margin?:boolean <- greater-or-equal cursor-column:address:number/deref, left:number
    assert cursor-inside-left-margin?:boolean, [cursor outside left margin]
    move-cursor screen:address, cursor-row:address:number/deref, cursor-column:address:number/deref
  }
  show-screen screen:address
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

scenario editor-initially-wraps-barely-long-lines [
  assume-screen 5:literal/width, 3:literal/height
  run [
    s:address:array:character <- new [abcde]
    new-editor s:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  ]
  # still wrap, even though the line would fit. We need room to click on the
  # end of the line
  screen-should-contain [
    .abcd↩.
    .e    .
    .     .
  ]
  screen-should-contain-in-color, 245:literal/grey [
    .    ↩.
    .     .
    .     .
  ]
]

scenario editor-initializes-empty-text [
  assume-screen 5:literal/width, 3:literal/height
  run [
    1:address:array:character <- new []
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
  memory-should-contain [
    3 <- 0  # cursor row
    4 <- 0  # cursor column
  ]
]

## handling events from the keyboard, mouse, touch screen, ...

# Takes a chain of editors (chained using editor-data.next-editor), sends each
# event from the console to each editor.
recipe event-loop [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  {
    # send each event to each editor
    e:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
    loop-unless found?:boolean
    break-if quit?:boolean  # only in tests
    trace [app], [next-event]
#?     $print [--- new event
#? ] #? 1
    curr:address:editor-data <- copy editor:address:editor-data
    {
      break-unless curr:address:editor-data
      handle-event screen:address, console:address, curr:address:editor-data, e:event
      curr:address:editor-data <- get curr:address:editor-data/deref, next-editor:offset
      loop
    }
    # ..and position the cursor
    curr:address:editor-data <- copy editor:address:editor-data
    {
      break-unless curr:address:editor-data
      {
        in-focus?:boolean <- get curr:address:editor-data/deref, in-focus?:offset
        break-unless in-focus?:boolean
        cursor-row:number <- get curr:address:editor-data/deref, cursor-row:offset
        cursor-column:number <- get curr:address:editor-data/deref, cursor-column:offset
        move-cursor screen:address, cursor-row:number, cursor-column:number
      }
      curr:address:editor-data <- get curr:address:editor-data/deref, next-editor:offset
      loop
    }
    loop
  }
]

recipe handle-event [
  default-space:address:array:location <- new location:type, 50:literal
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  e:event <- next-ingredient
  # 'touch' event
  {
    t:address:touch-event <- maybe-convert e:event, touch:variant
    break-unless t:address:touch-event
    move-cursor-in-editor editor:address:editor-data, t:address:touch-event/deref
    jump +render:label
  }
  # other events trigger only if this editor is in focus
#?   $print [checking ], editor:address:editor-data, [ 
#? ] #? 1
#?   x:address:boolean <- get-address editor:address:editor-data/deref, in-focus?:offset #? 1
#?   $print [address of focus: ], x:address:boolean, [ 
#? ] #? 1
  in-focus?:address:boolean <- get-address editor:address:editor-data/deref, in-focus?:offset
#?   $print [ at ], in-focus?:address:boolean, [ 
#? ] #? 1
  reply-unless in-focus?:address:boolean/deref  # no need to render
#?   $print [in focus: ], editor:address:editor-data, [ 
#? ] #? 1
  # typing a character
  {
    c:address:character <- maybe-convert e:event, text:variant
    break-unless c:address:character
    # unless it's a backspace
    {
      backspace?:boolean <- equal c:address:character/deref, 8:literal/backspace
      break-unless backspace?:boolean
      delete-before-cursor editor:address:editor-data
      jump +render:label
    }
    insert-at-cursor editor:address:editor-data, c:address:character/deref
    jump +render:label
  }
  # otherwise it's a special key to control the editor
  k:address:number <- maybe-convert e:event, keycode:variant
  assert k:address:number, [event was of unknown type; neither keyboard nor mouse]
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  screen-height:number <- screen-height screen:address
  top:number <- get editor:address:editor-data/deref, top:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  right:number <- get editor:address:editor-data/deref, right:offset
  # arrows; update cursor-row and cursor-column, leave before-cursor to 'render'.
  # right arrow
  {
    move-to-next-character?:boolean <- equal k:address:number/deref, 65514:literal/right-arrow
    break-unless move-to-next-character?:boolean
    # if not at end of text
    old-cursor:address:duplex-list <- next-duplex before-cursor:address:address:duplex-list/deref
    break-unless old-cursor:address:duplex-list
    # scan to next character
    before-cursor:address:address:duplex-list/deref <- copy old-cursor:address:duplex-list
    # if crossed a newline, move cursor to start of next row
    {
      old-cursor-character:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset
      was-at-newline?:boolean <- equal old-cursor-character:character, 10:literal/newline
      break-unless was-at-newline?:boolean
      cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
      cursor-column:address:number/deref <- copy left:number
      # todo: what happens when cursor is too far down?
      screen-height:number <- screen-height screen:address
      above-screen-bottom?:boolean <- lesser-than cursor-row:address:number/deref, screen-height:number
      assert above-screen-bottom?:boolean, [unimplemented: moving past bottom of screen]
      jump +render:label
    }
    # if the line wraps, move cursor to start of next row
    {
      # if we're at the column just before the wrap indicator
      wrap-column:number <- subtract right:number, 1:literal
      at-wrap?:boolean <- equal cursor-column:address:number/deref, wrap-column:number
      break-unless at-wrap?:boolean
      # and if next character isn't newline
      new-cursor:address:duplex-list <- next-duplex old-cursor:address:duplex-list
      break-unless new-cursor:address:duplex-list
      next-character:character <- get new-cursor:address:duplex-list/deref, value:offset
      newline?:boolean <- equal next-character:character, 10:literal/newline
      break-if newline?:boolean
      cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
      cursor-column:address:number/deref <- copy left:number
      # todo: what happens when cursor is too far down?
      above-screen-bottom?:boolean <- lesser-than cursor-row:address:number/deref, screen-height:number
      assert above-screen-bottom?:boolean, [unimplemented: moving past bottom of screen]
      jump +render:label
    }
    # otherwise move cursor one character right
    cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
  }
  # left arrow
  {
    move-to-previous-character?:boolean <- equal k:address:number/deref, 65515:literal/left-arrow
    break-unless move-to-previous-character?:boolean
    # if not at start of text (before-cursor at § sentinel)
    prev:address:duplex-list <- prev-duplex before-cursor:address:address:duplex-list/deref
    break-unless prev:address:duplex-list
    # if cursor not at left margin, move one character left
    {
      at-left-margin?:boolean <- equal cursor-column:address:number/deref, 0:literal
      break-if at-left-margin?:boolean
      cursor-column:address:number/deref <- subtract cursor-column:address:number/deref, 1:literal
      jump +render:label
    }
    # if at left margin, there's guaranteed to be a previous line, since we're
    # not at start of text
    {
      # if before-cursor is at newline, figure out how long the previous line is
      prevc:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset
      previous-character-is-newline?:boolean <- equal prevc:character, 10:literal/newline
      break-unless previous-character-is-newline?:boolean
      # compute length of previous line
      end-of-line:number <- previous-line-length before-cursor:address:address:duplex-list/deref, d:address:duplex-list
      cursor-row:address:number/deref <- subtract cursor-row:address:number/deref, 1:literal
      cursor-column:address:number/deref <- copy end-of-line:number
      jump +render:label
    }
    # if before-cursor is not at newline, we're just at a wrapped line
    assert cursor-row:address:number/deref, [unimplemented: moving cursor above top of screen]
    cursor-row:address:number/deref <- subtract cursor-row:address:number/deref, 1:literal
    cursor-column:address:number/deref <- subtract right:number, 1:literal  # leave room for wrap icon
  }
  # down arrow
  {
    move-to-next-line?:boolean <- equal k:address:number/deref, 65516:literal/down-arrow
    break-unless move-to-next-line?:boolean
    # todo: support scrolling
    already-at-bottom?:boolean <- greater-or-equal cursor-row:address:number/deref, screen-height:number
    break-if already-at-bottom?:boolean
#?     $print [moving down
#? ] #? 1
    cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
    # that's it; render will adjust cursor-column as necessary
  }
  # up arrow
  {
    move-to-previous-line?:boolean <- equal k:address:number/deref, 65517:literal/up-arrow
    break-unless move-to-previous-line?:boolean
    # todo: support scrolling
    already-at-top?:boolean <- lesser-or-equal cursor-row:address:number/deref, top:number
    break-if already-at-top?:boolean
#?     $print [moving up
#? ] #? 1
    cursor-row:address:number/deref <- subtract cursor-row:address:number/deref, 1:literal
    # that's it; render will adjust cursor-column as necessary
  }
  +render
  render editor:address:editor-data
]

recipe move-cursor-in-editor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  t:touch-event <- next-ingredient
  # clicks on the menu bar shouldn't affect focus
  click-row:number <- get t:touch-event, row:offset
  top:number <- get editor:address:editor-data/deref, top:offset
  too-far-up?:boolean <- lesser-than click-row:number, top:number
  reply-if too-far-up?:boolean
  # not on menu? reset focus then set it if necessary
  in-focus?:address:boolean <- get-address editor:address:editor-data/deref, in-focus?:offset
  in-focus?:address:boolean/deref <- copy 0:literal/true
  click-column:number <- get t:touch-event, column:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  too-far-left?:boolean <- lesser-than click-column:number, left:number
  reply-if too-far-left?:boolean
  right:number <- get editor:address:editor-data/deref, right:offset
  too-far-right?:boolean <- greater-than click-column:number, right:number
  reply-if too-far-right?:boolean
#?   $print [focus now at ], editor:address:editor-data, [ 
#? ] #? 2
  # click on this window; gain focus
  in-focus?:address:boolean/deref <- copy 1:literal/true
  # update cursor
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-row:address:number/deref <- get t:touch-event, row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- get t:touch-event, column:offset
#?   $print [column is at: ], cursor-column:address:number, [ 
#? ] #? 1
]

recipe insert-at-cursor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  c:character <- next-ingredient
#?   $print [insert ], c:character, [ 
#? ] #? 1
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  insert-duplex c:character, before-cursor:address:address:duplex-list/deref
  before-cursor:address:address:duplex-list/deref <- next-duplex before-cursor:address:address:duplex-list/deref
  screen:address <- get editor:address:editor-data/deref, screen:offset
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  right:number <- get editor:address:editor-data/deref, right:offset
  # update cursor: if newline, move cursor to start of next line
  # todo: bottom of screen
  {
    newline?:boolean <- equal c:character, 10:literal/newline
    break-unless newline?:boolean
    cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
    cursor-column:address:number/deref <- copy left:number
    reply
  }
  # if the line wraps at the cursor, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:number <- subtract right:number, 1:literal
#?     $print [wrap? ], cursor-column:address:number/deref, [ vs ], wrap-column:number, [ 
#? ] #? 1
    at-wrap?:boolean <- greater-or-equal cursor-column:address:number/deref, wrap-column:number
    break-unless at-wrap?:boolean
#?     $print [wrap!
#? ] #? 1
    cursor-column:address:number/deref <- subtract cursor-column:address:number/deref, wrap-column:number
    cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
    # todo: what happens when cursor is too far down?
    screen-height:number <- screen-height screen:address
    above-screen-bottom?:boolean <- lesser-than cursor-row:address:number/deref, screen-height:number
    assert above-screen-bottom?:boolean, [unimplemented: typing past bottom of screen]
#?     $print [return
#? ] #? 1
    reply
  }
  # otherwise move cursor right
  cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
]

recipe delete-before-cursor [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  # unless already at start
  at-start?:boolean <- equal before-cursor:address:address:duplex-list/deref, d:address:duplex-list
  reply-if at-start?:boolean
  # delete character
  prev:address:duplex-list <- prev-duplex before-cursor:address:address:duplex-list/deref
  remove-duplex before-cursor:address:address:duplex-list/deref
  # update cursor
  before-cursor:address:address:duplex-list/deref <- copy prev:address:duplex-list
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- subtract cursor-column:address:number/deref, 1:literal
#?   $print [delete-before-cursor: ], cursor-column:address:number/deref, [ 
#? ] #? 1
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the length of the previous line before the 'curr' pointer.
recipe previous-line-length [
  default-space:address:array:location <- new location:type, 30:literal
  curr:address:duplex-list <- next-ingredient
  start:address:duplex-list <- next-ingredient
  result:number <- copy 0:literal
  reply-unless curr:address:duplex-list, result:number
  at-start?:boolean <- equal curr:address:duplex-list, start:address:duplex-list
  reply-if at-start?:boolean, result:number
  {
    curr:address:duplex-list <- prev-duplex curr:address:duplex-list
    break-unless curr:address:duplex-list
    at-start?:boolean <- equal curr:address:duplex-list, start:address:duplex-list
    break-if at-start?:boolean
    c:character <- get curr:address:duplex-list/deref, value:offset
    at-newline?:boolean <- equal c:character 10:literal/newline
    break-if at-newline?:boolean
    result:number <- add result:number, 1:literal
    loop
  }
  reply result:number
]

scenario editor-handles-empty-event-queue [
  assume-screen 10:literal/width, 5:literal/height
#?   3:number <- get screen:address/deref, num-rows:offset #? 1
#?   $print [0: ], screen:address, [: ], 3:number, [ 
#? ] #? 1
  1:address:array:character <- new [abc]
#?   $print [1: ], screen:address, [ 
#? ] #? 1
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console []
#?   $print [8: ], screen:address, [ 
#? ] #? 1
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
#?   $print [9: ], screen:address, [ 
#? ] #? 1
  screen-should-contain [
    .abc       .
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 1  # on the 'b'
  ]
  run [
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

scenario editor-handles-mouse-clicks-outside-text [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 7  # last line, to the right of text
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 0  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-text-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 7  # interior line, to the right of text
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 0  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-text-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 2, 7  # below text
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-column [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  # editor occupies only left half of screen
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    # click on right half of screen
    left-click 3, 8
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
  memory-should-contain [
    3 <- 0  # no change to cursor row
    4 <- 0  # ..or column
  ]
]

scenario editor-inserts-characters-into-empty-editor [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    type [abc]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    type [0]
    left-click 0, 2
    type [d]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .0adbc     .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 5  # right of last line
    type [d]  # should append
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abcd      .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [d]  # should append
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abcd      .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-4 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [e]  # should append
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .de        .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-5 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [ef]  # should append multiple characters in order
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .def       .
    .          .
  ]
]

scenario editor-wraps-line-on-insert [
  assume-screen 5:literal/width, 3:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  # type a letter
  assume-console [
    type [e]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  # no wrap yet
  screen-should-contain [
    .eabc .
    .     .
  ]
  # type a second letter
  assume-console [
    type [f]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  # now wrap
  screen-should-contain [
    .efab↩.
    .c    .
    .     .
  ]
]

scenario editor-moves-cursor-after-inserting-characters [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [ab]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    type [01]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .01ab      .
    .          .
  ]
]

scenario editor-wraps-cursor-after-inserting-characters [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    left-click 0, 4  # line is full; no wrap icon yet
    type [f]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .abcd↩     .
    .fe        .
    .          .
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 1  # cursor column
  ]
]

scenario editor-wraps-cursor-after-inserting-characters-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    left-click 0, 3  # right before the wrap icon
    type [f]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .abcf↩     .
    .de        .
    .          .
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 0  # cursor column
  ]
]

scenario editor-moves-cursor-down-after-inserting-newline [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    type [0
1]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .0         .
    .1abc      .
    .          .
  ]
]

scenario editor-moves-cursor-down-after-inserting-newline-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 1:literal/left, 10:literal/right
  assume-console [
    type [0
1]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    . 0        .
    . 1abc     .
    .          .
  ]
]

scenario editor-clears-previous-line-completely-after-inserting-newline [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  # press just a 'newline'
  assume-console [
    type [
]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  # line should be fully cleared
  screen-should-contain [
    .          .
    .abcd↩     .
    .e         .
    .          .
  ]
]

scenario editor-handles-backspace-key [
#?   $print [=== new test
#? ] #? 1
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
#?   $print [editor: ], 2:address:editor-data, [ 
#? ] #? 1
  assume-console [
    left-click 0, 1
    type [«]
  ]
  3:event/backspace <- merge 0:literal/text, 8:literal/backspace, 0:literal/dummy, 0:literal/dummy
  replace-in-console 171:literal/«, 3:event/backspace
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .bc        .
    .          .
  ]
  memory-should-contain [
    4 <- 0
    5 <- 0
  ]
]

scenario editor-clears-last-line-on-backspace [
  assume-screen 10:literal/width, 5:literal/height
  # just one character in final line
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    left-click 1, 0  # cursor at only character in final line
    type [«]
  ]
  3:event/backspace <- merge 0:literal/text, 8:literal/backspace, 0:literal/dummy, 0:literal/dummy
  replace-in-console 171:literal/«, 3:event/backspace
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abcd      .
    .          .
  ]
]

scenario editor-moves-cursor-right-with-key [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    press 65514  # right arrow
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .a0bc      .
    .          .
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .0d        .
    .          .
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 1:literal/left, 10:literal/right
  assume-console [
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    . abc      .
    . 0d       .
    .          .
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  assume-console [
    left-click 0, 3
    press 65514  # right arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .abcd↩     .
    .ef        .
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-2 [
  assume-screen 10:literal/width, 5:literal/height
  # line just barely wrapping
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  # position cursor at last character before wrap and hit right-arrow
  assume-console [
    left-click 0, 3
    press 65514  # right arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # now hit right arrow again
  assume-console [
    press 65514
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 1:literal/left, 6:literal/right
  assume-console [
    left-click 0, 4
    press 65514  # right arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    . abcd↩    .
    . ef       .
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-at-end-of-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 3
    press 65514  # right arrow - next line
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .0d        .
    .          .
  ]
]

scenario editor-moves-cursor-left-with-key [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 2
    press 65515  # left arrow
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .a0bc      .
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with two lines
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  # position cursor at start of second line (so there's no previous newline)
  assume-console [
    left-click 1, 0
    press 65515  # left arrow
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc0      .
    .d         .
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-2 [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with three lines
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  # position cursor further down (so there's a newline before the character at
  # the cursor)
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .def0      .
    .g         .
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  # position cursor at start of text
  assume-console [
    left-click 0, 0
    press 65515  # left arrow should have no effect
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .0abc      .
    .def       .
    .g         .
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-4 [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abc

d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  # position cursor right after empty line
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
    type [0]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .abc       .
    .0         .
    .d         .
    .          .
  ]
]

scenario editor-moves-across-screen-lines-across-wrap-with-left-arrow [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  screen-should-contain [
    .abcd↩     .
    .ef        .
    .          .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 1, 0
    press 65515  # left arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 0  # previous row
    4 <- 3  # end of wrapped line
  ]
]

scenario editor-moves-to-previous-line-with-up-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 1
    press 65517  # up arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 0
    4 <- 1
  ]
]

scenario editor-moves-to-next-line-with-down-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  # cursor starts out at (0, 0)
  assume-console [
    press 65516  # down arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # ..and ends at (1, 0)
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
]

scenario editor-adjusts-column-at-previous-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [ab
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 3
    press 65517  # up arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 0
    4 <- 2
  ]
]

scenario editor-adjusts-column-at-next-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
de]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 3
    press 65516  # down arrow
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
]

scenario point-at-multiple-editors [
  assume-screen 10:literal/width, 5:literal/height
  # initialize an editor covering left half of screen
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  3:address:array:character <- new [def]
  # chain new editor to it, covering the right half of the screen
  4:address:address:editor-data <- get-address 2:address:editor-data/deref, next-editor:offset
  4:address:address:editor-data/deref <- new-editor 3:address:array:character, screen:address, 0:literal/top, 5:literal/left, 10:literal/right
  # type one letter in each of them
  assume-console [
    left-click 0, 1
    left-click 0, 8
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
    6:number <- get 4:address:address:editor-data/deref/deref, cursor-column:offset
  ]
  memory-should-contain [
    5 <- 1
    6 <- 8
  ]
]

scenario editors-chain-to-cover-multiple-columns [
  assume-screen 10:literal/width, 5:literal/height
  # initialize an editor covering left half of screen
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  3:address:array:character <- new [def]
  # chain new editor to it, covering the right half of the screen
  4:address:address:editor-data <- get-address 2:address:editor-data/deref, next-editor:offset
  4:address:address:editor-data/deref <- new-editor 3:address:array:character, screen:address, 0:literal/top, 5:literal/left, 10:literal/right
  reset-focus 2:address:editor-data
  # type one letter in each of them
  assume-console [
    left-click 0, 1
    type [0]
    left-click 0, 6
    type [1]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
    6:number <- get 4:address:address:editor-data/deref/deref, cursor-column:offset
  ]
  screen-should-contain [
    .a0bc d1ef .
    .          .
  ]
  memory-should-contain [
    5 <- 2
    6 <- 7
  ]
  # show the cursor at the right window
  run [
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  screen-should-contain [
    .a0bc d1␣f .
    .          .
  ]
]

scenario multiple-editors-cover-only-their-own-areas [
  assume-screen 10:literal/width, 5:literal/height
  run [
    # draw a divider
    draw-vertical screen:address, 5:literal/divider, 0:literal/top, 5:literal/height
    # initialize editors on both sides of it and chain the two
    1:address:array:character <- new [abc]
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
    3:address:array:character <- new [def]
    4:address:address:editor-data <- get-address 2:address:editor-data/deref, next-editor:offset
    4:address:address:editor-data/deref <- new-editor 3:address:array:character, screen:address, 0:literal/top, 6:literal/left, 10:literal/right
  ]
  # divider isn't messed up
  screen-should-contain [
    .abc  │def .
    .     │    .
    .     │    .
    .     │    .
    .     │    .
  ]
]

scenario editor-in-focus-keeps-cursor [
  assume-screen 10:literal/width, 5:literal/height
  # initialize an editor covering left half of screen
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 5:literal/right
  3:address:array:character <- new [def]
  # chain new editor to it, covering the right half of the screen
  4:address:address:editor-data <- get-address 2:address:editor-data/deref, next-editor:offset
  4:address:address:editor-data/deref <- new-editor 3:address:array:character, screen:address, 0:literal/top, 5:literal/left, 10:literal/right
  # initialize cursor
  run [
    reset-focus 2:address:editor-data
    5:number <- get 2:address:editor-data/deref, cursor-row:offset
    6:number <- get 2:address:editor-data/deref, cursor-column:offset
    move-cursor screen:address, 5:number, 6:number
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  # is it at the right place?
  screen-should-contain [
    .␣bc  def  .
    .          .
  ]
  # now try typing a letter
  assume-console [
    type [z]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  # cursor should still be right
  screen-should-contain [
    .z␣bc def  .
    .          .
  ]
]

scenario editor-in-focus-keeps-cursor-2 [
  assume-screen 10:literal/width, 5:literal/height
  # initialize an editor covering left half of screen - but not from the top
  # row of screen
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1:literal/top, 0:literal/left, 5:literal/right
  3:address:array:character <- new [def]
  # chain new editor to it, covering the right half of the screen
  4:address:address:editor-data <- get-address 2:address:editor-data/deref, next-editor:offset
  4:address:address:editor-data/deref <- new-editor 3:address:array:character, screen:address, 1:literal/top, 5:literal/left, 10:literal/right
  # initialize cursor on left editor
  run [
    reset-focus 2:address:editor-data
  ]
  # now click on top row of screen on the right side
  assume-console [
    left-click 0, 8
    type [z]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor should still be at the left side
  screen-should-contain [
    .          .
    .zabc def  .
    .          .
  ]
]

# set focus to first editor, reset it in later ones
recipe reset-focus [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  in-focus:address:boolean <- get-address editor:address:editor-data/deref, in-focus?:offset
  in-focus:address:boolean/deref <- copy 1:literal/true
  e:address:editor-data <- get editor:address:editor-data/deref, next-editor:offset
  {
    break-unless e:address:editor-data
#?     $print [resetting focus in ], e:address:editor-data, [ 
#? ] #? 1
    x:address:boolean <- get-address e:address:editor-data/deref, in-focus?:offset
#?     $print [ at ], x:address:boolean, [ 
#? ] #? 1
    x:address:boolean/deref <- copy 0:literal/false
    e:address:editor-data <- get e:address:editor-data/deref, next-editor:offset
    loop
  }
]

## Running code from the editors

recipe editor-contents [
  default-space:address:array:location <- new location:type, 30:literal
  editor:address:editor-data <- next-ingredient
  buf:address:buffer <- new-buffer 80:literal
#?   $print [buffer: ], buf:address:buffer, [ 
#? ] #? 1
  curr:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  # skip § sentinel
  assert curr:address:duplex-list, [editor without data is illegal; must have at least a sentinel]
  curr:address:duplex-list <- next-duplex curr:address:duplex-list
  {
    break-unless curr:address:duplex-list
    c:character <- get curr:address:duplex-list/deref, value:offset
#?     $print [appending ], c:character, [ 
#? ] #? 1
    buffer-append buf:address:buffer, c:character
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    loop
  }
  result:address:array:character <- buffer-to-array buf:address:buffer
  reply result:address:array:character
]

scenario editor-provides-edited-contents [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/top, 0:literal/left, 10:literal/right
  assume-console [
    left-click 0, 2
    type [def]
  ]
  run [
    event-loop screen:address, console:address, 2:address:editor-data
    3:address:array:character <- editor-contents 2:address:editor-data
    4:array:character <- copy 3:address:array:character/deref
#?     $dump-memory #? 1
  ]
  memory-should-contain [
    4:string <- [abdefc]
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
  style:character, style-found?:boolean <- next-ingredient
  {
    break-if style-found?:boolean
    style:character <- copy 9472:literal/horizontal
  }
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 245:literal/grey
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    break-if bg-color-found?:boolean
    bg-color:number <- copy 0:literal/black
  }
  move-cursor screen:address, row:number, x:number
  {
    continue?:boolean <- lesser-than x:number, right:number
    break-unless continue?:boolean
    print-character screen:address, style:character, color:number, bg-color:number
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
  style:character, style-found?:boolean <- next-ingredient
  {
    break-if style-found?:boolean
    style:character <- copy 9474:literal/vertical
  }
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
    print-character screen:address, style:character, color:number
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

recipe print-string-with-gradient-background [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  s:address:array:character <- next-ingredient
  color:number <- next-ingredient
  bg-color1:number <- next-ingredient
  bg-color2:number <- next-ingredient
  len:number <- length s:address:array:character/deref
  color-range:number <- subtract bg-color2:number, bg-color1:number
  color-quantum:number <- divide color-range:number, len:number
#?   close-console #? 2
#?   $print len:number, [, ], color-range:number, [, ], color-quantum:number, [ 
#? ] #? 2
#? #?   $exit #? 3
  bg-color:number <- copy bg-color1:number
  i:number <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:number, len:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, i:number
    print-character x:address:screen, c:character, color:number, bg-color:number
    i:number <- add i:number, 1:literal
    bg-color:number <- add bg-color:number, color-quantum:number
#?     $print [=> ], bg-color:number, [ 
#? ] #? 1
    loop
  }
#?   $exit #? 1
  reply x:address:screen/same-as-ingredient:0
]
