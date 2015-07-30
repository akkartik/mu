# Environment for learning programming using mu.

recipe main [
  local-scope
  open-console
  initial-recipe:address:array:character <- restore [recipes.mu]
  initial-sandbox:address:array:character <- new []
  env:address:programming-environment-data <- new-programming-environment 0/screen, initial-recipe, initial-sandbox
  env <- restore-sandboxes env
  render-all 0/screen, env
  show-screen 0/screen
  event-loop 0/screen, 0/console, env
  # never gets here
]

container programming-environment-data [
  recipes:address:editor-data
  recipe-warnings:address:array:character
  current-sandbox:address:editor-data
  sandbox:address:sandbox-data
  sandbox-in-focus?:boolean  # false => focus in recipes; true => focus in current-sandbox
]

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
  y:address:address:duplex-list <- get-address *result, before-cursor:offset
  *y <- copy *init
  # early exit if s is empty
  reply-unless s, result
  len:number <- length *s
  reply-unless len, result
  idx:number <- copy 0
  # now we can start appending the rest, character by character
  curr:address:duplex-list <- copy *init
  {
    done?:boolean <- greater-or-equal idx, len
    break-if done?
    c:character <- index *s, idx
    insert-duplex c, curr
    # next iter
    curr <- next-duplex curr
    idx <- add idx, 1
    loop
  }
  # initialize cursor to top of screen
  y <- get-address *result, before-cursor:offset
  *y <- copy *init
  # initial render to screen, just for some old tests
  _, screen <- render screen, result
  reply result
]

scenario editor-initializes-without-data [
  assume-screen 5/width, 3/height
  run [
    1:address:editor-data <- new-editor 0/data, screen:address, 2/left, 5/right
    2:editor-data <- copy *1:address:editor-data
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
  reply-unless editor, 1/top, screen/same-as-ingredient:0
  left:number <- get *editor, left:offset
  screen-height:number <- screen-height screen
  right:number <- get *editor, right:offset
  hide-screen screen
  # highlight mu code with color
  color:number <- copy 7/white
  highlighting-state:number <- copy 0/normal
  # traversing editor
  curr:address:duplex-list <- get *editor, data:offset
  prev:address:duplex-list <- copy curr
  curr <- next-duplex curr
  # traversing screen
  row:number <- copy 1/top
  column:number <- copy left
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  move-cursor screen, row, column
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
      *before-cursor <- prev-duplex curr
    }
    c:character <- get *curr, value:offset
    color, highlighting-state <- get-color color, highlighting-state, c
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
      move-cursor screen, row, column
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
      move-cursor screen, row, column
      # don't increment curr
      loop +next-character:label
    }
    print-character screen, c, color
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
    # line not wrapped but cursor outside bounds? wrap cursor
    {
      too-far-right?:boolean <- greater-than *cursor-column, right
      break-unless too-far-right?
      *cursor-column <- copy left
      *cursor-row <- add *cursor-row, 1
      above-screen-bottom?:boolean <- lesser-than *cursor-row, screen-height
      assert above-screen-bottom?, [unimplemented: wrapping cursor past bottom of screen]
    }
    *before-cursor <- copy prev
  }
  # clear rest of current line
  clear-line-delimited screen, column, right
  reply row, screen/same-as-ingredient:0
]

# row:number, screen:address <- render-string screen:address, s:address:array:character, left:number, right:number, color:number, row:number
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
  move-cursor screen, row, column
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
      move-cursor screen, row, column
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
      move-cursor screen, row, column
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
  left:number <- next-ingredient
  right:number <- next-ingredient
  column:number <- copy left
  {
    done?:boolean <- greater-than column, right
    break-if done?
    print-character screen, 32/space
    column <- add column, 1
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

# color:number, highlighting-state:number <- get-color color:number, highlighting-state:number, c:character
recipe get-color [
  local-scope
  color:number <- next-ingredient
  highlighting-state:number <- next-ingredient
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
  reply color, highlighting-state
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
    trace [app], [next-event]
    # 'touch' event - send to both editors
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t
      move-cursor-in-editor screen, editor, *t
      jump +continue:label
    }
    # other events - send to appropriate editor
    handle-event screen, console, editor, e:event
    +continue
    row:number, screen <- render screen, editor
    # clear next line, in case we just processed a backspace
    left:number <- get *editor, left:offset
    right:number <- get *editor, right:offset
    row <- add row, 1
    move-cursor screen, row, left
    clear-line-delimited screen, left, right
    loop
  }
]

recipe handle-event [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  editor:address:editor-data <- next-ingredient
  e:event <- next-ingredient
  reply-unless editor
  # character
  {
    c:address:character <- maybe-convert e:event, text:variant
    break-unless c
    ## check for special characters
    # backspace - delete character before cursor
    {
      backspace?:boolean <- equal *c, 8/backspace
      break-unless backspace?
      delete-before-cursor editor
      reply
    }
    # ctrl-a - move cursor to start of line
    {
      ctrl-a?:boolean <- equal *c, 1/ctrl-a
      break-unless ctrl-a?
      move-to-start-of-line editor
      reply
    }
    # ctrl-e - move cursor to end of line
    {
      ctrl-e?:boolean <- equal *c, 5/ctrl-e
      break-unless ctrl-e?
      move-to-end-of-line editor
      reply
    }
    # ctrl-u - delete until start of line (excluding cursor)
    {
      ctrl-u?:boolean <- equal *c, 21/ctrl-u
      break-unless ctrl-u?
      delete-to-start-of-line editor
      reply
    }
    # ctrl-k - delete until end of line (including cursor)
    {
      ctrl-k?:boolean <- equal *c, 11/ctrl-k
      break-unless ctrl-k?
      delete-to-end-of-line editor
      reply
    }
    # tab - insert two spaces
    {
      tab?:boolean <- equal *c, 9/tab
      break-unless tab?:boolean
      insert-at-cursor editor, 32/space, screen
      insert-at-cursor editor, 32/space, screen
      reply
    }
    # otherwise type it in
    insert-at-cursor editor, *c, screen
    reply
  }
  # otherwise it's a special key
  k:address:number <- maybe-convert e:event, keycode:variant
  assert k, [event was of unknown type; neither keyboard nor mouse]
  d:address:duplex-list <- get *editor, data:offset
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  screen-height:number <- screen-height screen
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  # arrows; update cursor-row and cursor-column, leave before-cursor to 'render'.
  # right arrow
  {
    move-to-next-character?:boolean <- equal *k, 65514/right-arrow
    break-unless move-to-next-character?
    # if not at end of text
    old-cursor:address:duplex-list <- next-duplex *before-cursor
    break-unless old-cursor
    # scan to next character
    *before-cursor <- copy old-cursor
    # if crossed a newline, move cursor to start of next row
    {
      old-cursor-character:character <- get **before-cursor, value:offset
      was-at-newline?:boolean <- equal old-cursor-character, 10/newline
      break-unless was-at-newline?
      *cursor-row <- add *cursor-row, 1
      *cursor-column <- copy left
      # todo: what happens when cursor is too far down?
      screen-height <- screen-height screen
      above-screen-bottom?:boolean <- lesser-than *cursor-row, screen-height
      assert above-screen-bottom?, [unimplemented: moving past bottom of screen]
      reply
    }
    # if the line wraps, move cursor to start of next row
    {
      # if we're at the column just before the wrap indicator
      wrap-column:number <- subtract right, 1
      at-wrap?:boolean <- equal *cursor-column, wrap-column
      break-unless at-wrap?
      # and if next character isn't newline
      new-cursor:address:duplex-list <- next-duplex old-cursor
      break-unless new-cursor
      next-character:character <- get *new-cursor, value:offset
      newline?:boolean <- equal next-character, 10/newline
      break-if newline?
      *cursor-row <- add *cursor-row, 1
      *cursor-column <- copy left
      # todo: what happens when cursor is too far down?
      above-screen-bottom?:boolean <- lesser-than *cursor-row, screen-height
      assert above-screen-bottom?, [unimplemented: moving past bottom of screen]
      reply
    }
    # otherwise move cursor one character right
    *cursor-column <- add *cursor-column, 1
  }
  # left arrow
  {
    move-to-previous-character?:boolean <- equal *k, 65515/left-arrow
    break-unless move-to-previous-character?
#?     trace [app], [left arrow] #? 1
    # if not at start of text (before-cursor at § sentinel)
    prev:address:duplex-list <- prev-duplex *before-cursor
    break-unless prev
    editor <- move-cursor-coordinates-left editor
  }
  # down arrow
  {
    move-to-next-line?:boolean <- equal *k, 65516/down-arrow
    break-unless move-to-next-line?
    # todo: support scrolling
    already-at-bottom?:boolean <- greater-or-equal *cursor-row, screen-height
    break-if already-at-bottom?
#?     $print [moving down
#? ] #? 1
    *cursor-row <- add *cursor-row, 1
    # that's it; render will adjust cursor-column as necessary
  }
  # up arrow
  {
    move-to-previous-line?:boolean <- equal *k, 65517/up-arrow
    break-unless move-to-previous-line?
    # todo: support scrolling
    already-at-top?:boolean <- lesser-or-equal *cursor-row, 1/top
    break-if already-at-top?
#?     $print [moving up
#? ] #? 1
    *cursor-row <- subtract *cursor-row, 1
    # that's it; render will adjust cursor-column as necessary
  }
  # home
  {
    home?:boolean <- equal *k, 65521/home
    break-unless home?
    move-to-start-of-line editor
    reply
  }
  # end
  {
    end?:boolean <- equal *k, 65520/end
    break-unless end?
    move-to-end-of-line editor
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
  reply-unless editor, 0/false
  click-column:number <- get t, column:offset
  left:number <- get *editor, left:offset
  too-far-left?:boolean <- lesser-than click-column, left
  reply-if too-far-left?, 0/false
  right:number <- get *editor, right:offset
  too-far-right?:boolean <- greater-than click-column, right
  reply-if too-far-right?, 0/false
  # update cursor
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  *cursor-row <- get t, row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  *cursor-column <- get t, column:offset
  # gain focus
  reply 1/true
]

recipe insert-at-cursor [
  local-scope
  editor:address:editor-data <- next-ingredient
  c:character <- next-ingredient
  screen:address <- next-ingredient
#?   $print [insert ], c, 10/newline #? 1
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  insert-duplex c, *before-cursor
  *before-cursor <- next-duplex *before-cursor
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  # update cursor: if newline, move cursor to start of next line
  # todo: bottom of screen
  {
    newline?:boolean <- equal c, 10/newline
    break-unless newline?
    *cursor-row <- add *cursor-row, 1
    *cursor-column <- copy left
    # indent if necessary
#?     $print [computing indent], 10/newline #? 1
    d:address:duplex-list <- get *editor, data:offset
    end-of-previous-line:address:duplex-list <- prev-duplex *before-cursor
    indent:number <- line-indent end-of-previous-line, d
#?     $print indent, 10/newline #? 1
    i:number <- copy 0
    {
      indent-done?:boolean <- greater-or-equal i, indent
      break-if indent-done?
      insert-at-cursor editor, 32/space, screen
      i <- add i, 1
      loop
    }
    reply
  }
  # if the line wraps at the cursor, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:number <- subtract right, 1
#?     $print [wrap? ], *cursor-column, [ vs ], wrap-column, 10/newline
    at-wrap?:boolean <- greater-or-equal *cursor-column, wrap-column
    break-unless at-wrap?
#?     $print [wrap!
#? ] #? 1
    *cursor-column <- subtract *cursor-column, wrap-column
    *cursor-row <- add *cursor-row, 1
    # todo: what happens when cursor is too far down?
    screen-height:number <- screen-height screen
    above-screen-bottom?:boolean <- lesser-than *cursor-row, screen-height
    assert above-screen-bottom?, [unimplemented: typing past bottom of screen]
#?     $print [return
#? ] #? 1
    reply
  }
  # otherwise move cursor right
  *cursor-column <- add *cursor-column, 1
]

recipe delete-before-cursor [
  local-scope
  editor:address:editor-data <- next-ingredient
  before-cursor:address:address:duplex-list <- get-address *editor, before-cursor:offset
  # if at start of text (before-cursor at § sentinel), return
  prev:address:duplex-list <- prev-duplex *before-cursor
  reply-unless prev
  editor <- move-cursor-coordinates-left editor
  remove-duplex *before-cursor
  *before-cursor <- copy prev
]

recipe move-cursor-coordinates-left [
  local-scope
  editor:address:editor-data <- next-ingredient
  before-cursor:address:duplex-list <- get *editor, before-cursor:offset
  cursor-row:address:number <- get-address *editor, cursor-row:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  # if not at left margin, move one character left
  {
    at-left-margin?:boolean <- equal *cursor-column, 0
    break-if at-left-margin?
#?     trace [app], [decrementing cursor column] #? 1
    *cursor-column <- subtract *cursor-column, 1
    reply editor/same-as-ingredient:0
  }
  # if at left margin, we must move to previous row:
  assert *cursor-row, [unimplemented: moving cursor above top of screen]
  *cursor-row <- subtract *cursor-row, 1
  {
    # case 1: if previous character was newline, figure out how long the previous line is
    previous-character:character <- get *before-cursor, value:offset
    previous-character-is-newline?:boolean <- equal previous-character, 10/newline
    break-unless previous-character-is-newline?
    # compute length of previous line
#?     trace [app], [switching to previous line] #? 1
    d:address:duplex-list <- get *editor, data:offset
    end-of-line:number <- previous-line-length before-cursor, d
    *cursor-column <- copy end-of-line
    reply editor/same-as-ingredient:0
  }
  # case 2: if previous-character was not newline, we're just at a wrapped line
#?   trace [app], [wrapping to previous line] #? 1
  right:number <- get *editor, right:offset
  *cursor-column <- subtract right, 1  # leave room for wrap icon
  reply editor/same-as-ingredient:0
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
  # move one past final character
  *cursor-column <- add *cursor-column, 1
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
  end-prev:address:address:duplex-list <- get-address *end, prev:offset
  *end-prev <- copy start
  # adjust cursor
  *before-cursor <- prev-duplex end
  left:number <- get *editor, left:offset
  cursor-column:address:number <- get-address *editor, cursor-column:offset
  *cursor-column <- copy left
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

scenario editor-handles-empty-event-queue [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
    .          .
  ]
  memory-should-contain [
    3 <- 1  # cursor is at row 0..
    4 <- 1  # ..and column 1
  ]
]

scenario editor-handles-mouse-clicks-outside-text [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-handles-mouse-clicks-outside-text-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-handles-mouse-clicks-outside-text-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-handles-mouse-clicks-outside-column [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  # editor occupies only left half of screen
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
    .          .
  ]
  memory-should-contain [
    3 <- 1  # no change to cursor row
    4 <- 0  # ..or column
  ]
]

scenario editor-inserts-characters-into-empty-editor [
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 5/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [ab]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 0  # cursor column
  ]
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
    .          .
  ]
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
    .          .
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

scenario editor-handles-backspace-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
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
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 2
  ]
]

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

scenario editor-moves-cursor-right-with-key [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-2 [
  assume-screen 10/width, 5/height
  # line just barely wrapping
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-3 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 1/left, 6/right
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
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-at-end-of-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  # initialize editor with two lines
  1:address:array:character <- new [abc
d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-2 [
  assume-screen 10/width, 5/height
  # initialize editor with three lines
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def
g]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abc

d]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
  assume-screen 10/width, 5/height
  # initialize editor with text containing an empty line
  1:address:array:character <- new [abcdef]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 5/right
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
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # previous row
    4 <- 3  # end of wrapped line
  ]
]

scenario editor-moves-to-previous-line-with-up-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-next-line-with-down-arrow [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-adjusts-column-at-previous-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [ab
def]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-adjusts-column-at-next-line [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc
de]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-start-of-line-with-ctrl-a [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-start-of-line-with-ctrl-a-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-start-of-line-with-home [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-start-of-line-with-home-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-start-of-line-with-ctrl-e [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
    .          .
  ]
]

scenario editor-moves-to-end-of-line-with-ctrl-e-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-end-of-line-with-end [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

scenario editor-moves-to-end-of-line-with-end-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [123
456]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
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
]

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
    .          .
  ]
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
  3:event/ctrl-u <- merge 0/text, 21/ctrl-a, 0/dummy, 0/dummy
  replace-in-console 117/a, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .3         .
    .456       .
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
  3:event/ctrl-u <- merge 0/text, 21/ctrl-a, 0/dummy, 0/dummy
  replace-in-console 117/a, 3:event/ctrl-u
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .          .
    .456       .
    .          .
  ]
]

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
    .          .
  ]
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
    .          .
  ]
]

## the environment consists of one editor on the left for recipes and one on
## the right for the sandbox

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
  move-cursor screen, 0/row, button-start
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
  new-right:number <- add new-left, 5
  current-sandbox:address:address:editor-data <- get-address *result, current-sandbox:offset
  *current-sandbox <- new-editor initial-sandbox-contents, screen, new-left, width/right
  screen <- render-all screen, result
  reply result
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
    screen:address <- print-character screen:address, 9251/␣
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
  # initialize programming environment and highlight cursor
  assume-console []
  run [
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    event-loop screen:address, console:address, 3:address:programming-environment-data
    screen:address <- print-character screen:address, 9251/␣
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
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    event-loop screen:address, console:address, 3:address:programming-environment-data
    screen:address <- print-character screen:address, 9251/␣
  ]
  # cursor should still be right
  screen-should-contain [
    .           run (F4)           .
    .z␣bc           ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

recipe render-all [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  screen <- render-recipes screen, env, 1/clear-below
  screen <- render-sandbox-side screen, env, 1/clear-below
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  update-cursor screen, recipes, current-sandbox, sandbox-in-focus?
  show-screen screen
  reply screen/same-as-ingredient:0
]

recipe render-minimal [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
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
  move-cursor screen, cursor-row, cursor-column
  show-screen screen
  reply screen/same-as-ingredient:0
]

recipe render-recipes [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  clear:boolean <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  # render recipes
  left:number <- get *recipes, left:offset
  right:number <- get *recipes, right:offset
  row:number, screen <- render screen, recipes
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
  # clear next line, in case we just processed a backspace
  row <- add row, 1
  move-cursor screen, row, left
  clear-line-delimited screen, left, right
  # clear rest of screen in this column, if requested
  reply-unless clear, screen/same-as-ingredient:0
  screen-height:number <- screen-height screen
  {
    at-bottom-of-screen?:boolean <- greater-or-equal row, screen-height
    break-if at-bottom-of-screen?
    move-cursor screen, row, left
    clear-line-delimited screen, left, right
    row <- add row, 1
    loop
  }
  reply screen/same-as-ingredient:0
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
    trace [app], [next-event]
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
      # ctrl-n? - switch focus
      {
        ctrl-n?:boolean <- equal *c, 14/ctrl-n
        break-unless ctrl-n?
        *sandbox-in-focus? <- not *sandbox-in-focus?
        update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
        show-screen screen
        loop +next-event:label
      }
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
      jump +continue:label
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      {
        break-if *sandbox-in-focus?
        handle-event screen, console, recipes, e:event
      }
      {
        break-unless *sandbox-in-focus?
        handle-event screen, console, current-sandbox, e:event
      }
    }
    +continue
    # if no more events currently left to process, render.
    # we rely on 'render' to update 'before-cursor' on pointer events, but
    # they won't usually come fast enough to trigger this.
    # todo: test this
    {
      more-events?:boolean <- has-more-events? console
      break-if more-events?
      render-minimal screen, env
    }
    loop
  }
]

# helper for testing a single editor

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
  move-cursor screen, cursor-row, cursor-column
]

## Running code from the editors

container sandbox-data [
  data:address:array:character
  response:address:array:character
  warnings:address:array:character
  starting-row-on-screen:number  # to track clicks on delete
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
    run-sandboxes env
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env
    update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    show-screen screen
    loop +next-event:label
  }
]

recipe run-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # copy code from recipe editor, persist, load into mu, save any warnings
  in:address:array:character <- editor-contents recipes
  save [recipes.mu], in
  recipe-warnings:address:address:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  reply-if *recipe-warnings
  # check contents of right editor (sandbox)
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
  }
  # save all sandboxes before running, just in case we die when running
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >&/dev/null]
  curr:address:sandbox-data <- get *env, sandbox:offset
  filename:number <- copy 0
  {
    break-unless curr
    data:address:address:array:character <- get-address *curr, data:offset
    save filename, *data
    filename <- add filename, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
  # run all sandboxes
  curr <- get *env, sandbox:offset
  {
    break-unless curr
    data <- get-address *curr, data:offset
    response:address:address:array:character <- get-address *curr, response:offset
    warnings:address:address:array:character <- get-address *curr, warnings:offset
    fake-screen:address:address:screen <- get-address *curr, screen:offset
    *response, *warnings, *fake-screen <- run-interactive *data
#?     $print *warnings, [ ], **warnings, 10/newline
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

recipe render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  clear:boolean <- next-ingredient
#?   trace [app], [render sandbox side] #? 1
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, screen <- render screen, current-sandbox
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row
  # clear next line, in case we just processed a backspace
  row <- add row, 1
  move-cursor screen, row, left
  clear-line-delimited screen, left, right
  reply-unless clear, screen/same-as-ingredient:0
  screen-height:number <- screen-height screen
  {
    at-bottom-of-screen?:boolean <- greater-or-equal row, screen-height
    break-if at-bottom-of-screen?
    move-cursor screen, row, left
    clear-line-delimited screen, left, right
    row <- add row, 1
    loop
  }
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
  move-cursor screen, row, left
  clear-line-delimited screen, left, right
  print-character screen, 120/x, 245/grey
  # save menu row so we can detect clicks to it later
  starting-row:address:number <- get-address *sandbox, starting-row-on-screen:offset
  *starting-row <- copy row
  # render sandbox contents
  sandbox-data:address:array:character <- get *sandbox, data:offset
  row, screen <- render-string screen, sandbox-data, left, right, 7/white, row
  # render sandbox warnings, screen or response, in that order
  sandbox-response:address:array:character <- get *sandbox, response:offset
  sandbox-warnings:address:array:character <- get *sandbox, warnings:offset
  sandbox-screen:address <- get *sandbox, screen:offset
  {
    break-unless sandbox-warnings
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
    row, screen <- render-string screen, sandbox-response, left, right, 245/grey, row
  }
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
  filename:number <- copy 0
  curr:address:address:sandbox-data <- get-address *env, sandbox:offset
  {
    contents:address:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    *curr <- new sandbox-data:type
    data:address:address:array:character <- get-address **curr, data:offset
    *data <- copy contents
    # increment loop variables
    filename <- add filename, 1
    curr <- get-address **curr, next-sandbox:offset
    loop
  }
  reply env/same-as-ingredient:0
]

# row:number, screen:address <- render-screen screen:address, sandbox-screen:address, left:number, right:number, row:number
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
  move-cursor screen, row, left
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
    move-cursor screen, row, column
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

after +global-touch [
  # on a sandbox delete icon? process delete
  {
    was-delete?:boolean <- delete-sandbox *t, env
    break-unless was-delete?
#?     trace [app], [delete clicked] #? 1
    screen <- render-sandbox-side screen, env, 1/clear
    update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
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

scenario run-instruction-manages-screen-per-sandbox [
  $close-trace  # trace too long for github #? 1
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [print-integer screen:address, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editor
  assume-console [
    press 65532  # F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that it prints a little 5x5 toy screen
  # hack: screen address is brittle
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

## handling malformed programs

scenario run-shows-warnings-in-get [
  $close-trace
  assume-screen 100/width, 15/height
  assume-console [
    press 65532  # F4
  ]
  run [
    x:address:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
    y:address:array:character <- new [foo]
    env:address:programming-environment-data <- new-programming-environment screen:address, x:address:array:character, y:address:array:character
    event-loop screen:address, console:address, env:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  get 123:number, foo:offset                      ┊                                                 .
    .]                                                 ┊                                                 .
    .unknown element foo in container number           ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
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
  assume-console [
    press 65532  # F4
  ]
  run [
    x:address:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
    y:address:array:character <- new [foo]
    env:address:programming-environment-data <- new-programming-environment screen:address, x:address:array:character, y:address:array:character
    event-loop screen:address, console:address, env:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .]                                                 ┊                                                 .
    .missing type in 'x <- copy 0'                     ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-get-on-non-container-warnings [
  $close-trace
  assume-screen 100/width, 15/height
  assume-console [
    press 65532  # F4
  ]
  run [
    x:address:array:character <- new [ 
recipe foo [
  x:address:point <- new point:type
  get x:address:point, 1:offset
]]
    y:address:array:character <- new [foo]
    env:address:programming-environment-data <- new-programming-environment screen:address, x:address:array:character, y:address:array:character
    event-loop screen:address, console:address, env:address:programming-environment-data
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
  assume-console [
    press 65532  # F4
  ]
  run [
    x:address:array:character <- new [ 
recipe foo [
  x:number <- copy 0
  y:address:point <- new point:type
  get *y:address:point, x:number
]]
    y:address:array:character <- new [foo]
    env:address:programming-environment-data <- new-programming-environment screen:address, x:address:array:character, y:address:array:character
    event-loop screen:address, console:address, env:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
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
  move-cursor screen, top, left
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
    break-if bg-color-found?:boolean
    bg-color <- copy 0/black
  }
  move-cursor screen, row, x
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
    move-cursor screen, y, col
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
  move-cursor screen, top, left
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
  move-cursor screen, top, right
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
  move-cursor screen, bottom, left
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
  move-cursor screen, bottom, right
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
