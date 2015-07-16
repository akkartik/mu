# Environment for learning programming using mu.

recipe main [
  local-scope
  open-console
  initial-recipe:address:array:character <- new [ 
# return true if a list of numbers contains the pattern 1, 5, 3
recipe check [
  default-space:address:array:location <- new location:type, 30:literal
  state:number <- copy 0:literal
  {
    +next-number
    curr:number, found?:boolean <- next-ingredient
    break-unless found?:boolean
    # if curr is 1, state = 1
    {
      state1:boolean <- equal curr:number, 1:literal
      break-unless state1:boolean
      state:number <- copy 1:literal
      loop +next-number:label
    }
    # if state is 1 and curr is 5, state = 2
    {
      state-is-1?:boolean <- equal state:number, 1:literal
      break-unless state-is-1?:boolean
      state2:boolean <- equal curr:number, 5:literal
      break-unless state2:boolean
      state:number <- copy 2:literal
      loop +next-number:label
    }
    # if state is 2 and curr is 3, return true
    {
      state-is-2?:boolean <- equal state:number, 2:literal
      break-unless state-is-2?:boolean
      state3:boolean <- equal curr:number, 3:literal
      break-unless state3:boolean
      reply 1:literal/found
    }
    # otherwise reset state
    #state:number <- copy 0:literal
    loop
  }
  reply 0:literal/not-found
]]
#?   initial-recipe:address:array:character <- new [recipe new-add [
#?   x:number <- next-ingredient
#?   y:number <- next-ingredient
#?   z:number <- add x:number, y:number
#?   reply z:number
#? ]]
  initial-sandbox:address:array:character <- new []
  env:address:programming-environment-data <- new-programming-environment 0:literal/screen, initial-recipe:address:array:character, initial-sandbox:address:array:character
  event-loop 0:literal/screen, 0:literal/console, env:address:programming-environment-data
]

container programming-environment-data [
  recipes:address:editor-data
  recipe-warnings:address:array:character
  current-sandbox:address:editor-data
  sandbox:address:sandbox-data
  sandbox-in-focus?:boolean  # false => focus in recipes; true => focus in current-sandbox
]

recipe new-programming-environment [
  local-scope
  screen:address <- next-ingredient
  initial-recipe-contents:address:array:character <- next-ingredient
  initial-sandbox-contents:address:array:character <- next-ingredient
  width:number <- screen-width screen:address
  height:number <- screen-height screen:address
  # top menu
  result:address:programming-environment-data <- new programming-environment-data:type
  draw-horizontal screen:address, 0:literal, 0:literal/left, width:number, 32:literal/space, 0:literal/black, 238:literal/grey
  button-start:number <- subtract width:number, 20:literal
  button-on-screen?:boolean <- greater-or-equal button-start:number, 0:literal
  assert button-on-screen?:boolean, [screen too narrow for menu]
  move-cursor screen:address, 0:literal/row, button-start:number/column
  run-button:address:array:character <- new [ run (F10)  ]
  print-string screen:address, run-button:address:array:character, 255:literal/white, 161:literal/reddish
  # dotted line down the middle
  divider:number, _ <- divide-with-remainder width:number, 2:literal
  draw-vertical screen:address, divider:number, 1:literal/top, height:number, 9482:literal/vertical-dotted
  # recipe editor on the left
  recipes:address:address:editor-data <- get-address result:address:programming-environment-data/deref, recipes:offset
  recipes:address:address:editor-data/deref <- new-editor initial-recipe-contents:address:array:character, screen:address, 0:literal/left, divider:number/right
  # sandbox editor on the right
  new-left:number <- add divider:number, 1:literal
  new-right:number <- add new-left:number, 5:literal
  current-sandbox:address:address:editor-data <- get-address result:address:programming-environment-data/deref, current-sandbox:offset
  current-sandbox:address:address:editor-data/deref <- new-editor initial-sandbox-contents:address:array:character, screen:address, new-left:number, width:number
  screen:address <- render-all screen:address, result:address:programming-environment-data
  reply result:address:programming-environment-data
]

scenario editor-initially-prints-string-to-screen [
  assume-screen 10:literal/width, 5:literal/height
  run [
    1:address:array:character <- new [abc]
    new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
]

## In which we introduce the editor data structure, and show how it displays
## text to the screen.

container editor-data [
  # editable text: doubly linked list of characters (head contains a special sentinel)
  data:address:duplex-list
  # location before cursor inside data
  before-cursor:address:duplex-list

  # raw bounds of display area on screen
  # always displays from row 1 and at most until bottom of screen
  left:number
  right:number
  # raw screen coordinates of cursor
  cursor-row:number
  cursor-column:number
]

# editor:address, screen:address <- new-editor s:address:array:character, screen:address, left:number, right:number
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
  right:number <- subtract right:number, 1:literal
  result:address:editor-data <- new editor-data:type
  # initialize screen-related fields
  x:address:number <- get-address result:address:editor-data/deref, left:offset
  x:address:number/deref <- copy left:number
  x:address:number <- get-address result:address:editor-data/deref, right:offset
  x:address:number/deref <- copy right:number
  # initialize cursor
  x:address:number <- get-address result:address:editor-data/deref, cursor-row:offset
  x:address:number/deref <- copy 1:literal/top
  x:address:number <- get-address result:address:editor-data/deref, cursor-column:offset
  x:address:number/deref <- copy left:number
  init:address:address:duplex-list <- get-address result:address:editor-data/deref, data:offset
  init:address:address:duplex-list/deref <- push-duplex 167:literal/§, 0:literal/tail
  y:address:address:duplex-list <- get-address result:address:editor-data/deref, before-cursor:offset
  y:address:address:duplex-list/deref <- copy init:address:address:duplex-list/deref
  # early exit if s is empty
  reply-unless s:address:array:character, result:address:editor-data
  len:number <- length s:address:array:character/deref
  reply-unless len:number, result:address:editor-data
  idx:number <- copy 0:literal
  # now we can start appending the rest, character by character
  curr:address:duplex-list <- copy init:address:address:duplex-list/deref
  {
    done?:boolean <- greater-or-equal idx:number, len:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, idx:number
    insert-duplex c:character, curr:address:duplex-list
    # next iter
    curr:address:duplex-list <- next-duplex curr:address:duplex-list
    idx:number <- add idx:number, 1:literal
    loop
  }
  # initialize cursor to top of screen
  y:address:address:duplex-list <- get-address result:address:editor-data/deref, before-cursor:offset
  y:address:address:duplex-list/deref <- copy init:address:address:duplex-list/deref
  # initial render to screen, just for some old tests
  _, screen:address <- render screen:address, result:address:editor-data
  reply result:address:editor-data
]

scenario editor-initializes-without-data [
  assume-screen 5:literal/width, 3:literal/height
  run [
    1:address:editor-data <- new-editor 0:literal/data, screen:address, 2:literal/left, 5:literal/right
    2:editor-data <- copy 1:address:editor-data/deref
  ]
  memory-should-contain [
    # 2 (data) <- just the § sentinel
    # 3 (before cursor) <- the § sentinel
    4 <- 2  # left
    5 <- 4  # right  (inclusive)
    6 <- 1  # cursor row
    7 <- 2  # cursor column
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]

# bottom:number, screen:address <- render screen:address, editor:address:editor-data
recipe render [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  reply-unless editor:address:editor-data, 1:literal/top, screen:address/same-as-ingredient:0
  left:number <- get editor:address:editor-data/deref, left:offset
  screen-height:number <- screen-height screen:address
  right:number <- get editor:address:editor-data/deref, right:offset
  hide-screen screen:address
  # traversing editor
  curr:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  prev:address:duplex-list <- copy curr:address:duplex-list
  curr:address:duplex-list <- next-duplex curr:address:duplex-list
  # traversing screen
  row:number <- copy 1:literal/top
  column:number <- copy left:number
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  move-cursor screen:address, row:number, column:number
  {
    +next-character
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
    }
    c:character <- get curr:address:duplex-list/deref, value:offset
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
      }
      # clear rest of line in this window
      clear-line-delimited screen:address, column:number, right:number
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
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row:number, cursor-row:address:number/deref
    cursor-outside-line?:boolean <- lesser-or-equal column:number, cursor-column:address:number/deref
    before-cursor-on-same-line?:boolean <- and at-cursor-row?:boolean, cursor-outside-line?:boolean
    above-cursor-row?:boolean <- lesser-than row:number, cursor-row:address:number/deref
    before-cursor?:boolean <- or before-cursor-on-same-line?:boolean, above-cursor-row?:boolean
    break-unless before-cursor?:boolean
    cursor-row:address:number/deref <- copy row:number
    cursor-column:address:number/deref <- copy column:number
    # line not wrapped but cursor outside bounds? wrap cursor
    {
      too-far-right?:boolean <- greater-than cursor-column:address:number/deref, right:number
      break-unless too-far-right?:boolean
      cursor-column:address:number/deref <- copy left:number
      cursor-row:address:number/deref <- add cursor-row:address:number/deref, 1:literal
      above-screen-bottom?:boolean <- lesser-than cursor-row:address:number/deref, screen-height:number
      assert above-screen-bottom?:boolean, [unimplemented: wrapping cursor past bottom of screen]
    }
    before-cursor:address:address:duplex-list/deref <- copy prev:address:duplex-list
  }
  # clear rest of current line
  clear-line-delimited screen:address, column:number, right:number
  reply row:number, screen:address/same-as-ingredient:0
]

# row:number, screen:address <- render-string screen:address, s:address:array:character, left:number, right:number, color:number, row:number
# print a string 's' to 'editor' in 'color' starting at 'row'
# leave cursor at start of next line
recipe render-string [
  local-scope
  screen:address <- next-ingredient
  s:address:array:character <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  color:number <- next-ingredient
  row:number <- next-ingredient
  row:number <- add row:number, 1:literal
  reply-unless s:address:array:character, row:number/same-as-ingredient:5, screen:address/same-as-ingredient:0
  column:number <- copy left:number
  move-cursor screen:address, row:number, column:number
  screen-height:number <- screen-height screen:address
  i:number <- copy 0:literal
  len:number <- length s:address:array:character/deref
  {
    +next-character
    done?:boolean <- greater-or-equal i:number, len:number
    break-if done?:boolean
    done?:boolean <- greater-or-equal row:number, screen-height:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, i:number
    {
      # at right? wrap.
      at-right?:boolean <- equal column:number, right:number
      break-unless at-right?:boolean
      # print wrap icon
      print-character screen:address, 8617:literal/loop-back-to-left, 245:literal/grey
      column:number <- copy left:number
      row:number <- add row:number, 1:literal
      move-cursor screen:address, row:number, column:number
      loop +next-character:label  # retry i
    }
    i:number <- add i:number, 1:literal
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c:character, 10:literal/newline
      break-unless newline?:boolean
      # clear rest of line in this window
      {
        done?:boolean <- greater-than column:number, right:number
        break-if done?:boolean
        print-character screen:address, 32:literal/space
        column:number <- add column:number, 1:literal
        loop
      }
      row:number <- add row:number, 1:literal
      column:number <- copy left:number
      move-cursor screen:address, row:number, column:number
      loop +next-character:label
    }
    print-character screen:address, c:character, color:number
    column:number <- add column:number, 1:literal
    loop
  }
  {
    # clear rest of current line
    line-done?:boolean <- greater-than column:number, right:number
    break-if line-done?:boolean
    print-character screen:address, 32:literal/space
    column:number <- add column:number, 1:literal
    loop
  }
  reply row:number/same-as-ingredient:5, screen:address/same-as-ingredient:0
]

recipe clear-line-delimited [
  local-scope
  screen:address <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  column:number <- copy left:number
  {
    done?:boolean <- greater-than column:number, right:number
    break-if done?:boolean
    print-character screen:address, 32:literal/space
    column:number <- add column:number, 1:literal
    loop
  }
]

scenario editor-initially-prints-multiple-lines [
  assume-screen 5:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 0:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .     .
    .abc  .
    .def  .
    .     .
  ]
]

scenario editor-initially-handles-offsets [
  assume-screen 5:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abc]
    new-editor s:address:array:character, screen:address, 1:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .     .
    . abc .
    .     .
  ]
]

scenario editor-initially-prints-multiple-lines-at-offset [
  assume-screen 5:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abc
def]
    new-editor s:address:array:character, screen:address, 1:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .     .
    . abc .
    . def .
    .     .
  ]
]

scenario editor-initially-wraps-long-lines [
  assume-screen 5:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abc def]
    new-editor s:address:array:character, screen:address, 0:literal/left, 5:literal/right
  ]
  screen-should-contain [
    .     .
    .abc ↩.
    .def  .
    .     .
  ]
  screen-should-contain-in-color, 245:literal/grey [
    .     .
    .    ↩.
    .     .
    .     .
  ]
]

scenario editor-initially-wraps-barely-long-lines [
  assume-screen 5:literal/width, 5:literal/height
  run [
    s:address:array:character <- new [abcde]
    new-editor s:address:array:character, screen:address, 0:literal/left, 5:literal/right
  ]
  # still wrap, even though the line would fit. We need room to click on the
  # end of the line
  screen-should-contain [
    .     .
    .abcd↩.
    .e    .
    .     .
  ]
  screen-should-contain-in-color, 245:literal/grey [
    .     .
    .    ↩.
    .     .
    .     .
  ]
]

scenario editor-initializes-empty-text [
  assume-screen 5:literal/width, 5:literal/height
  run [
    1:address:array:character <- new []
    2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
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

## handling events from the keyboard, mouse, touch screen, ...

recipe event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get env:address:programming-environment-data/deref, recipes:offset
  current-sandbox:address:editor-data <- get env:address:programming-environment-data/deref, current-sandbox:offset
  sandbox-in-focus?:address:boolean <- get-address env:address:programming-environment-data/deref, sandbox-in-focus?:offset
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
    loop-unless found?:boolean
    break-if quit?:boolean  # only in tests
    trace [app], [next-event]
    # check for global events that will trigger regardless of which editor has focus
    {
      k:address:number <- maybe-convert e:event, keycode:variant
      break-unless k:address:number
      # F10? load all code and run all sandboxes.
      {
        do-run?:boolean <- equal k:address:number/deref, 65526:literal/F10
        break-unless do-run?:boolean
        run-sandboxes env:address:programming-environment-data
        screen:address <- render-sandbox-side screen:address, env:address:programming-environment-data
        # F10 doesn't mess with the recipe side
        update-cursor screen:address, recipes:address:editor-data, current-sandbox:address:editor-data, sandbox-in-focus?:address:boolean/deref
        show-screen screen:address
        loop +next-event:label
      }
    }
    # 'touch' event - send to both editors
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t:address:touch-event
      _ <- move-cursor-in-editor screen:address, recipes:address:editor-data, t:address:touch-event/deref
      sandbox-in-focus?:address:boolean/deref <- move-cursor-in-editor screen:address, current-sandbox:address:editor-data, t:address:touch-event/deref
      jump +continue:label
    }
    # if it's not global, send to appropriate editor
    {
      {
        break-if sandbox-in-focus?:address:boolean/deref
        handle-event screen:address, console:address, recipes:address:editor-data, e:event
      }
      {
        break-unless sandbox-in-focus?:address:boolean/deref
        handle-event screen:address, console:address, current-sandbox:address:editor-data, e:event
      }
    }
    +continue
    # if no more events currently left to process, render.
    # we rely on 'render' to update 'before-cursor' on pointer events, but
    # they won't usually come fast enough to trigger this.
    # todo: test this
    {
      more-events?:boolean <- has-more-events? console:address
      break-if more-events?:boolean
      render-minimal screen:address, env:address:programming-environment-data
    }
    loop
  }
]

# helper for testing a single editor
recipe editor-event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
    loop-unless found?:boolean
    break-if quit?:boolean  # only in tests
    trace [app], [next-event]
    # 'touch' event - send to both editors
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t:address:touch-event
      move-cursor-in-editor screen:address, editor:address:editor-data, t:address:touch-event/deref
      jump +continue:label
    }
    # other events - send to appropriate editor
    handle-event screen:address, console:address, editor:address:editor-data, e:event
    +continue
    row:number, screen:address <- render screen:address, editor:address:editor-data
    # clear next line, in case we just processed a backspace
    left:number <- get editor:address:editor-data/deref, left:offset
    right:number <- get editor:address:editor-data/deref, right:offset
    row:number <- add row:number, 1:literal
    move-cursor screen:address, row:number, left:number
    clear-line-delimited screen:address, left:number, right:number
    loop
  }
]

recipe handle-event [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  e:event <- next-ingredient
  reply-unless editor:address:editor-data
  # character
  {
    c:address:character <- maybe-convert e:event, text:variant
    break-unless c:address:character
    # check for special characters
    # unless it's a backspace
    {
      backspace?:boolean <- equal c:address:character/deref, 8:literal/backspace
      break-unless backspace?:boolean
      delete-before-cursor editor:address:editor-data
      reply
    }
    # ctrl-a
    {
      ctrl-a?:boolean <- equal c:address:character/deref, 1:literal/ctrl-a
      break-unless ctrl-a?:boolean
      move-to-start-of-line editor:address:editor-data
      reply
    }
    # ctrl-e
    {
      ctrl-e?:boolean <- equal c:address:character/deref, 5:literal/ctrl-e
      break-unless ctrl-e?:boolean
      move-to-end-of-line editor:address:editor-data
      reply
    }
    # otherwise type it in
    insert-at-cursor editor:address:editor-data, c:address:character/deref, screen:address
    reply
  }
  # otherwise it's a special key
  k:address:number <- maybe-convert e:event, keycode:variant
  assert k:address:number, [event was of unknown type; neither keyboard nor mouse]
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  screen-height:number <- screen-height screen:address
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
      reply
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
      reply
    }
    # otherwise move cursor one character right
    cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
  }
  # left arrow
  {
    move-to-previous-character?:boolean <- equal k:address:number/deref, 65515:literal/left-arrow
    break-unless move-to-previous-character?:boolean
#?     trace [app], [left arrow] #? 1
    # if not at start of text (before-cursor at § sentinel)
    prev:address:duplex-list <- prev-duplex before-cursor:address:address:duplex-list/deref
    break-unless prev:address:duplex-list
    # if cursor not at left margin, move one character left
    {
      at-left-margin?:boolean <- equal cursor-column:address:number/deref, 0:literal
      break-if at-left-margin?:boolean
#?       trace [app], [decrementing] #? 1
      cursor-column:address:number/deref <- subtract cursor-column:address:number/deref, 1:literal
      reply
    }
    # if at left margin, there's guaranteed to be a previous line, since we're
    # not at start of text
    {
      # if before-cursor is at newline, figure out how long the previous line is
      prevc:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset
      previous-character-is-newline?:boolean <- equal prevc:character, 10:literal/newline
      break-unless previous-character-is-newline?:boolean
#?       trace [app], [previous line] #? 1
      # compute length of previous line
      end-of-line:number <- previous-line-length before-cursor:address:address:duplex-list/deref, d:address:duplex-list
      cursor-row:address:number/deref <- subtract cursor-row:address:number/deref, 1:literal
      cursor-column:address:number/deref <- copy end-of-line:number
      reply
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
    already-at-top?:boolean <- lesser-or-equal cursor-row:address:number/deref, 1:literal/top
    break-if already-at-top?:boolean
#?     $print [moving up
#? ] #? 1
    cursor-row:address:number/deref <- subtract cursor-row:address:number/deref, 1:literal
    # that's it; render will adjust cursor-column as necessary
  }
  # home
  {
    home?:boolean <- equal k:address:number/deref, 65521:literal/home
    break-unless home?:boolean
    move-to-start-of-line editor:address:editor-data
    reply
  }
  # end
  {
    end?:boolean <- equal k:address:number/deref, 65520:literal/end
    break-unless end?:boolean
    move-to-end-of-line editor:address:editor-data
    reply
  }
]

# process click, return if it was on current editor
# todo: ignores menu bar (for now just displays shortcuts)
recipe move-cursor-in-editor [
  local-scope
  screen:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  t:touch-event <- next-ingredient
  reply-unless editor:address:editor-data, 0:literal/false
  click-column:number <- get t:touch-event, column:offset
  left:number <- get editor:address:editor-data/deref, left:offset
  too-far-left?:boolean <- lesser-than click-column:number, left:number
  reply-if too-far-left?:boolean, 0:literal/false
  right:number <- get editor:address:editor-data/deref, right:offset
  too-far-right?:boolean <- greater-than click-column:number, right:number
  reply-if too-far-right?:boolean, 0:literal/false
  # update cursor
  cursor-row:address:number <- get-address editor:address:editor-data/deref, cursor-row:offset
  cursor-row:address:number/deref <- get t:touch-event, row:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- get t:touch-event, column:offset
  # gain focus
  reply 1:literal/true
]

recipe insert-at-cursor [
  local-scope
  editor:address:editor-data <- next-ingredient
  c:character <- next-ingredient
  screen:address <- next-ingredient
#?   $print [insert ], c:character, [ 
#? ] #? 1
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  d:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  insert-duplex c:character, before-cursor:address:address:duplex-list/deref
  before-cursor:address:address:duplex-list/deref <- next-duplex before-cursor:address:address:duplex-list/deref
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
  local-scope
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
  local-scope
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

recipe move-to-start-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  # update cursor column
  left:number <- get editor:address:editor-data/deref, left:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  cursor-column:address:number/deref <- copy left:number
  # update before-cursor
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  init:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  # while not at start of line, move 
  {
    at-start-of-text?:boolean <- equal before-cursor:address:address:duplex-list/deref, init:address:duplex-list
    break-if at-start-of-text?:boolean
    prev:character <- get before-cursor:address:address:duplex-list/deref/deref, value:offset
    at-start-of-line?:boolean <- equal prev:character, 10:literal/newline
    break-if at-start-of-line?:boolean
    before-cursor:address:address:duplex-list/deref <- prev-duplex before-cursor:address:address:duplex-list/deref
    assert before-cursor:address:address:duplex-list/deref, [move-to-start-of-line tried to move before start of text]
    loop
  }
]

recipe move-to-end-of-line [
  local-scope
  editor:address:editor-data <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address editor:address:editor-data/deref, before-cursor:offset
  cursor-column:address:number <- get-address editor:address:editor-data/deref, cursor-column:offset
  # while not at start of line, move 
  {
    next:address:duplex-list <- next-duplex before-cursor:address:address:duplex-list/deref
    break-unless next:address:duplex-list  # end of text
    nextc:character <- get next:address:duplex-list/deref, value:offset
    at-end-of-line?:boolean <- equal nextc:character, 10:literal/newline
    break-if at-end-of-line?:boolean
    before-cursor:address:address:duplex-list/deref <- copy next:address:duplex-list
    cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
    loop
  }
  # move one past end of line
  cursor-column:address:number/deref <- add cursor-column:address:number/deref, 1:literal
]

recipe render-all [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  screen:address <- render-recipes screen:address, env:address:programming-environment-data
  screen:address <- render-sandbox-side screen:address, env:address:programming-environment-data
  recipes:address:editor-data <- get env:address:programming-environment-data/deref, recipes:offset
  current-sandbox:address:editor-data <- get env:address:programming-environment-data/deref, current-sandbox:offset
  sandbox-in-focus?:boolean <- get env:address:programming-environment-data/deref, sandbox-in-focus?:offset
  update-cursor screen:address, recipes:address:editor-data, current-sandbox:address:editor-data, sandbox-in-focus?:boolean
  show-screen screen:address
  reply screen:address/same-as-ingredient:0
]

recipe render-minimal [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get env:address:programming-environment-data/deref, recipes:offset
  current-sandbox:address:editor-data <- get env:address:programming-environment-data/deref, current-sandbox:offset
  sandbox-in-focus?:boolean <- get env:address:programming-environment-data/deref, sandbox-in-focus?:offset
  {
    break-if sandbox-in-focus?:boolean
    screen:address <- render-recipes screen:address, env:address:programming-environment-data
    cursor-row:number <- get recipes:address:editor-data/deref, cursor-row:offset
    cursor-column:number <- get recipes:address:editor-data/deref, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?:boolean
    screen:address <- render-sandbox-side screen:address, env:address:programming-environment-data
    cursor-row:number <- get current-sandbox:address:editor-data/deref, cursor-row:offset
    cursor-column:number <- get current-sandbox:address:editor-data/deref, cursor-column:offset
  }
  move-cursor screen:address, cursor-row:number, cursor-column:number
  show-screen screen:address
  reply screen:address/same-as-ingredient:0
]

recipe render-recipes [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get env:address:programming-environment-data/deref, recipes:offset
  # render recipes
  left:number <- get recipes:address:editor-data/deref, left:offset
  right:number <- get recipes:address:editor-data/deref, right:offset
  row:number, screen:address <- render screen:address, recipes:address:editor-data
  recipe-warnings:address:array:character <- get env:address:programming-environment-data/deref, recipe-warnings:offset
  {
    # print any warnings
    break-unless recipe-warnings:address:array:character
    row:number, screen:address <- render-string screen:address, recipe-warnings:address:array:character, left:number, right:number, 1:literal/red, row:number
  }
  {
    # no warnings? move to next line
    break-if recipe-warnings:address:array:character
    row:number <- add row:number, 1:literal
  }
  # draw dotted line after recipes
  draw-horizontal screen:address, row:number, left:number, right:number, 9480:literal/horizontal-dotted
  # clear next line, in case we just processed a backspace
  row:number <- add row:number, 1:literal
  move-cursor screen:address, row:number, left:number
  clear-line-delimited screen:address, left:number, right:number
  reply screen:address/same-as-ingredient:0
]

recipe render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get env:address:programming-environment-data/deref, current-sandbox:offset
  left:number <- get current-sandbox:address:editor-data/deref, left:offset
  right:number <- get current-sandbox:address:editor-data/deref, right:offset
  row:number, screen:address <- render screen:address, current-sandbox:address:editor-data
  row:number <- add row:number, 1:literal
  draw-horizontal screen:address, row:number, left:number, right:number, 9473:literal/horizontal-double
  sandbox:address:sandbox-data <- get env:address:programming-environment-data/deref, sandbox:offset
  row:number, screen:address <- render-sandboxes screen:address, sandbox:address:sandbox-data, left:number, right:number, row:number
  # clear next line, in case we just processed a backspace
  row:number <- add row:number, 1:literal
  move-cursor screen:address, row:number, left:number
  clear-line-delimited screen:address, left:number, right:number
  reply screen:address/same-as-ingredient:0
]

recipe render-sandboxes [
  local-scope
  screen:address <- next-ingredient
  sandbox:address:sandbox-data <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless sandbox:address:sandbox-data, row:number/same-as-ingredient:4, screen:address/same-as-ingredient:0
  screen-height:number <- screen-width screen:address
  at-bottom?:boolean <- greater-or-equal row:number screen-height:number
  reply-if at-bottom?:boolean, row:number/same-as-ingredient:4, screen:address/same-as-ingredient:0
  # render sandbox contents
  sandbox-data:address:array:character <- get sandbox:address:sandbox-data/deref, data:offset
  row:number, screen:address <- render-string screen:address, sandbox-data:address:array:character, left:number, right:number, 7:literal/white, row:number
  # render sandbox warnings or response, in that order
  sandbox-response:address:array:character <- get sandbox:address:sandbox-data/deref, response:offset
  sandbox-warnings:address:array:character <- get sandbox:address:sandbox-data/deref, warnings:offset
  {
    break-unless sandbox-warnings:address:array:character
    row:number, screen:address <- render-string screen:address, sandbox-warnings:address:array:character, left:number, right:number, 1:literal/red, row:number
  }
  {
    break-if sandbox-warnings:address:array:character
    row:number, screen:address <- render-string screen:address, sandbox-response:address:array:character, left:number, right:number, 245:literal/grey, row:number
  }
  # draw solid line after sandbox
  draw-horizontal screen:address, row:number, left:number, right:number, 9473:literal/horizontal-double
  # draw next sandbox
  next-sandbox:address:sandbox-data <- get sandbox:address:sandbox-data/deref, next-sandbox:offset
  row:number, screen:address <- render-sandboxes screen:address, next-sandbox:address:sandbox-data, left:number, right:number, row:number
  reply row:number/same-as-ingredient:4, screen:address/same-as-ingredient:0
]

recipe update-cursor [
  local-scope
  screen:address <- next-ingredient
  recipes:address:editor-data <- next-ingredient
  current-sandbox:address:editor-data <- next-ingredient
  sandbox-in-focus?:boolean <- next-ingredient
  {
    break-if sandbox-in-focus?:boolean
#?     $print [recipes in focus
#? ] #? 1
    cursor-row:number <- get recipes:address:editor-data/deref, cursor-row:offset
    cursor-column:number <- get recipes:address:editor-data/deref, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?:boolean
#?     $print [sandboxes in focus
#? ] #? 1
    cursor-row:number <- get current-sandbox:address:editor-data/deref, cursor-row:offset
    cursor-column:number <- get current-sandbox:address:editor-data/deref, cursor-column:offset
  }
  move-cursor screen:address, cursor-row:number, cursor-column:number
]

scenario editor-handles-empty-event-queue [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console []
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 1  # on the 'b'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
  memory-should-contain [
    3 <- 1  # cursor is at row 0..
    4 <- 1  # ..and column 1
  ]
]

scenario editor-handles-mouse-clicks-outside-text [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 7  # last line, to the right of text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-text-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 7  # interior line, to the right of text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-text-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 7  # below text
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 3  # cursor column
  ]
]

scenario editor-handles-mouse-clicks-outside-column [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  # editor occupies only left half of screen
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    # click on right half of screen
    left-click 3, 8
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
  memory-should-contain [
    3 <- 1  # no change to cursor row
    4 <- 0  # ..or column
  ]
]

scenario editor-inserts-characters-into-empty-editor [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    type [abc]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 5  # right of last line
    type [d]  # should append
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [d]  # should append
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-4 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [e]  # should append
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .de        .
    .          .
  ]
]

scenario editor-inserts-characters-at-cursor-5 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 3, 5  # below all text
    type [ef]  # should append multiple characters in order
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .          .
  ]
]

scenario editor-wraps-line-on-insert [
  assume-screen 5:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
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
    .     .
  ]
]

scenario editor-moves-cursor-after-inserting-characters [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [ab]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    type [01]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .01ab      .
    .          .
  ]
]

scenario editor-wraps-cursor-after-inserting-characters [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    left-click 1, 4  # line is full; no wrap icon yet
    type [f]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .fe        .
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 1  # cursor column
  ]
]

scenario editor-wraps-cursor-after-inserting-characters-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    left-click 1, 3  # right before the wrap icon
    type [f]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcf↩     .
    .de        .
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 0  # cursor column
  ]
]

scenario editor-moves-cursor-down-after-inserting-newline [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-down-after-inserting-newline-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-clears-previous-line-completely-after-inserting-newline [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
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
    .          .
  ]
]

scenario editor-handles-backspace-key [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 1
    type [«]
  ]
  3:event/backspace <- merge 0:literal/text, 8:literal/backspace, 0:literal/dummy, 0:literal/dummy
  replace-in-console 171:literal/«, 3:event/backspace
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .bc        .
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
]

scenario editor-clears-last-line-on-backspace [
  assume-screen 10:literal/width, 5:literal/height
  # just one character in final line
  1:address:array:character <- new [ab
cd]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    left-click 2, 0  # cursor at only character in final line
    type [«]
  ]
  3:event/backspace <- merge 0:literal/text, 8:literal/backspace, 0:literal/dummy, 0:literal/dummy
  replace-in-console 171:literal/«, 3:event/backspace
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .          .
  ]
]

scenario editor-moves-cursor-right-with-key [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .abc       .
    .0d        .
    .          .
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  assume-console [
    left-click 1, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-2 [
  assume-screen 10:literal/width, 5:literal/height
  # line just barely wrapping
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  # position cursor at last character before wrap and hit right-arrow
  assume-console [
    left-click 1, 3
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
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
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1:literal/left, 6:literal/right
  assume-console [
    left-click 1, 4
    press 65514  # right arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    . abcd↩    .
    . ef       .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-at-end-of-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-left-with-key [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with two lines
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # position cursor at start of second line (so there's no previous newline)
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-2 [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with three lines
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-3 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-4 [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abc

d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
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
    .          .
  ]
]

scenario editor-moves-across-screen-lines-across-wrap-with-left-arrow [
  assume-screen 10:literal/width, 5:literal/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 5:literal/right
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .          .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 2, 0
    press 65515  # left arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # previous row
    4 <- 3  # end of wrapped line
  ]
]

scenario editor-moves-to-previous-line-with-up-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 2, 1
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
]

scenario editor-moves-to-next-line-with-down-arrow [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # cursor starts out at (1, 0)
  assume-console [
    press 65516  # down arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # ..and ends at (2, 0)
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
]

scenario editor-adjusts-column-at-previous-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [ab
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 2, 3
    press 65517  # up arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
]

scenario editor-adjusts-column-at-next-line [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [abc
de]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 3
    press 65516  # down arrow
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
]

scenario editor-moves-to-start-of-line-with-ctrl-a [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on second line, press ctrl-a
  assume-console [
    left-click 2, 3
    type [a]  # ctrl-a
  ]
  3:event/ctrl-a <- merge 0:literal/text, 1:literal/ctrl-a, 0:literal/dummy, 0:literal/dummy
  replace-in-console 97:literal/a, 3:event/ctrl-a
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 2
    5 <- 0
  ]
]

scenario editor-moves-to-start-of-line-with-ctrl-a-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on first line (no newline before), press ctrl-a
  assume-console [
    left-click 1, 3
    type [a]  # ctrl-a
  ]
  3:event/ctrl-a <- merge 0:literal/text, 1:literal/ctrl-a, 0:literal/dummy, 0:literal/dummy
  replace-in-console 97:literal/a, 3:event/ctrl-a
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
]

scenario editor-moves-to-start-of-line-with-home [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on second line, press 'home'
  assume-console [
    left-click 2, 3
    press 65521  # 'home'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
]

scenario editor-moves-to-start-of-line-with-home-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on first line (no newline before), press 'home'
  assume-console [
    left-click 1, 3
    press 65521  # 'home'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
]

scenario editor-moves-to-start-of-line-with-ctrl-e [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on first line, press ctrl-e
  assume-console [
    left-click 1, 1
    type [e]  # ctrl-e
  ]
  3:event/ctrl-e <- merge 0:literal/text, 5:literal/ctrl-e, 0:literal/dummy, 0:literal/dummy
  replace-in-console 101:literal/e, 3:event/ctrl-e
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    4 <- 1
    5 <- 3
  ]
  # editor inserts future characters at cursor
  assume-console [
    type [z]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    4 <- 1
    5 <- 4
  ]
  screen-should-contain [
    .          .
    .123z      .
    .456       .
    .          .
  ]
]

scenario editor-moves-to-end-of-line-with-ctrl-e-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on second line (no newline after), press ctrl-e
  assume-console [
    left-click 2, 1
    type [e]  # ctrl-e
  ]
  3:event/ctrl-e <- merge 0:literal/text, 5:literal/ctrl-e, 0:literal/dummy, 0:literal/dummy
  replace-in-console 101:literal/e, 3:event/ctrl-e
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    4:number <- get 2:address:editor-data/deref, cursor-row:offset
    5:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    4 <- 2
    5 <- 3
  ]
]

scenario editor-moves-to-end-of-line-with-end [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on first line, press 'end'
  assume-console [
    left-click 1, 1
    press 65520  # 'end'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
]

scenario editor-moves-to-end-of-line-with-end-2 [
  assume-screen 10:literal/width, 5:literal/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  # start on second line (no newline after), press 'end'
  assume-console [
    left-click 2, 1
    press 65520  # 'end'
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:number <- get 2:address:editor-data/deref, cursor-row:offset
    4:number <- get 2:address:editor-data/deref, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    3 <- 2
    4 <- 3
  ]
]

scenario point-at-multiple-editors [
  assume-screen 30:literal/width, 5:literal/height
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
    4:address:editor-data <- get 3:address:programming-environment-data/deref, recipes:offset
    5:number <- get 4:address:editor-data/deref, cursor-column:offset
    6:address:editor-data <- get 3:address:programming-environment-data/deref, current-sandbox:offset
    7:number <- get 6:address:editor-data/deref, cursor-column:offset
  ]
  memory-should-contain [
    5 <- 1
    7 <- 17
  ]
]

scenario edit-multiple-editors [
  assume-screen 30:literal/width, 5:literal/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # type one letter in each of them
  assume-console [
    left-click 1, 1
    type [0]
    left-click 1, 17
    type [1]
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    4:address:editor-data <- get 3:address:programming-environment-data/deref, recipes:offset
    5:number <- get 4:address:editor-data/deref, cursor-column:offset
    6:address:editor-data <- get 3:address:programming-environment-data/deref, current-sandbox:offset
    7:number <- get 6:address:editor-data/deref, cursor-column:offset
  ]
  screen-should-contain [
    .           run (F10)          .  # this line has a different background, but we don't test that yet
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
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  screen-should-contain [
    .           run (F10)          .
    .a0bc           ┊d1␣f          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario multiple-editors-cover-only-their-own-areas [
  assume-screen 60:literal/width, 10:literal/height
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [def]
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  ]
  # divider isn't messed up
  screen-should-contain [
    .                                         run (F10)          .
    .abc                           ┊def                          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              ┊                             .
    .                              ┊                             .
  ]
]

scenario editor-in-focus-keeps-cursor [
  assume-screen 30:literal/width, 5:literal/height
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  # initialize programming environment and highlight cursor
  assume-console []
  run [
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    event-loop screen:address, console:address, 3:address:programming-environment-data
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  # is cursor at the right place?
  screen-should-contain [
    .           run (F10)          .
    .␣bc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # now try typing a letter
  assume-console [
    type [z]
  ]
  run [
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    event-loop screen:address, console:address, 3:address:programming-environment-data
    screen:address <- print-character screen:address, 9251:literal/␣
  ]
  # cursor should still be right
  screen-should-contain [
    .           run (F10)          .
    .z␣bc           ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

## Running code from the editors

container sandbox-data [
  data:address:array:character
  response:address:array:character
  warnings:address:array:character
  next-sandbox:address:sandbox-data
]

scenario run-and-show-results [
  $close-trace  # trace too long for github
  assume-screen 100:literal/width, 12:literal/height
  # recipe editor is empty
  1:address:array:character <- new []
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [divide-with-remainder 11:literal, 3:literal]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65526  # F10
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊divide-with-remainder 11:literal, 3:literal      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   divide-with-remainder 11:literal, 3:literal      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color, 245:literal/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # run another command
  assume-console [
    left-click 1, 80
    type [add 2:literal, 2:literal]
    press 65526  # F10
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊add 2:literal, 2:literal                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊divide-with-remainder 11:literal, 3:literal      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

recipe run-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get env:address:programming-environment-data/deref, recipes:offset
  current-sandbox:address:editor-data <- get env:address:programming-environment-data/deref, current-sandbox:offset
  # load code from recipe editor, save any warnings
  in:address:array:character <- editor-contents recipes:address:editor-data
  recipe-warnings:address:address:array:character <- get-address env:address:programming-environment-data/deref, recipe-warnings:offset
  recipe-warnings:address:address:array:character/deref <- reload in:address:array:character
  # check contents of right editor (sandbox)
  {
    sandbox-contents:address:array:character <- editor-contents current-sandbox:address:editor-data
    break-unless sandbox-contents:address:array:character
    # if contents exist, run them and turn them into a new sandbox-data
    new-sandbox:address:sandbox-data <- new sandbox-data:type
    data:address:address:array:character <- get-address new-sandbox:address:sandbox-data/deref, data:offset
    data:address:address:array:character/deref <- copy sandbox-contents:address:array:character
    # push to head of sandbox list
    dest:address:address:sandbox-data <- get-address env:address:programming-environment-data/deref, sandbox:offset
    next:address:address:sandbox-data <- get-address new-sandbox:address:sandbox-data/deref, next-sandbox:offset
    next:address:address:sandbox-data/deref <- copy dest:address:address:sandbox-data/deref
    dest:address:address:sandbox-data/deref <- copy new-sandbox:address:sandbox-data
    # clear sandbox editor
    init:address:address:duplex-list <- get-address current-sandbox:address:editor-data/deref, data:offset
    init:address:address:duplex-list/deref <- push-duplex 167:literal/§, 0:literal/tail
  }
  # rerun other sandboxes
  curr:address:sandbox-data <- get env:address:programming-environment-data/deref, sandbox:offset
  {
    break-unless curr:address:sandbox-data
    data:address:address:array:character <- get-address curr:address:sandbox-data/deref, data:offset
    response:address:address:array:character <- get-address curr:address:sandbox-data/deref, response:offset
    warnings:address:address:array:character <- get-address curr:address:sandbox-data/deref, warnings:offset
    response:address:address:array:character/deref, warnings:address:address:array:character/deref <- run-interactive data:address:address:array:character/deref
#?     $print warnings:address:address:array:character/deref, [ ], warnings:address:address:array:character/deref/deref, [ 
#? ] #? 1
    curr:address:sandbox-data <- get curr:address:sandbox-data/deref, next-sandbox:offset
    loop
  }
]

scenario run-updates-results [
  $close-trace  # trace too long for github
  assume-screen 100:literal/width, 12:literal/height
  # define a recipe (no indent for the 'add' line below so column numbers are more obvious)
  1:address:array:character <- new [ 
recipe foo [
z:number <- add 2:literal, 2:literal
]]
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65526  # F10
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2:literal, 2:literal              ┊foo                                              .
    .]                                                 ┊4                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  assume-console [
    left-click 3, 28  # one past the value of the second arg
    type [«3]  # replace
    press 65526  # F10
  ]
  4:event/backspace <- merge 0:literal/text, 8:literal/backspace, 0:literal/dummy, 0:literal/dummy
  replace-in-console 171:literal/«, 4:event/backspace
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen updates the result on the right
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2:literal, 3:literal              ┊foo                                              .
    .]                                                 ┊5                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings [
  $close-trace  # trace too long for github
  assume-screen 100:literal/width, 10:literal/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press 65526  # F10
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints error message in red
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   get 1234:number, foo:offset                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color, 1:literal/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   unknown element foo in container number          .
    .                                                                                                    .
  ]
  screen-should-contain-in-color, 245:literal/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings-only-once [
  $close-trace  # trace too long for github
  assume-screen 100:literal/width, 10:literal/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors multiple times
  assume-console [
    press 65526  # F10
    press 65526  # F10
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .                                                                                 run (F10)          .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

recipe editor-contents [
  local-scope
  editor:address:editor-data <- next-ingredient
  buf:address:buffer <- new-buffer 80:literal
  curr:address:duplex-list <- get editor:address:editor-data/deref, data:offset
  # skip § sentinel
  assert curr:address:duplex-list, [editor without data is illegal; must have at least a sentinel]
  curr:address:duplex-list <- next-duplex curr:address:duplex-list
  reply-unless curr:address:duplex-list, 0:literal
  {
    break-unless curr:address:duplex-list
    c:character <- get curr:address:duplex-list/deref, value:offset
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0:literal/left, 10:literal/right
  assume-console [
    left-click 1, 2
    type [def]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:address:array:character <- editor-contents 2:address:editor-data
    4:array:character <- copy 3:address:array:character/deref
  ]
  memory-should-contain [
    4:string <- [abdefc]
  ]
]

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
  local-scope
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
    continue?:boolean <- lesser-or-equal x:number, right:number  # right is inclusive, to match editor-data semantics
    break-unless continue?:boolean
    print-character screen:address, style:character, color:number, bg-color:number
    x:number <- add x:number, 1:literal
    loop
  }
]

recipe draw-vertical [
  local-scope
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
  local-scope
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
  local-scope
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
  local-scope
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
  local-scope
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
  local-scope
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
