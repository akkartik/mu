## handling events from the keyboard, mouse, touch screen, ...

# temporary main: interactive editor
# hit ctrl-c to exit
def! main text:address:array:character [
  local-scope
  load-ingredients
  open-console
  editor:address:editor-data <- new-editor text, 0/screen, 5/left, 45/right
  editor-event-loop 0/screen, 0/console, editor
  close-console
]

def editor-event-loop screen:address:screen, console:address:console, editor:address:editor-data -> screen:address:screen, console:address:console, editor:address:editor-data [
  local-scope
  load-ingredients
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    cursor-row:number <- get *editor, cursor-row:offset
    cursor-column:number <- get *editor, cursor-column:offset
    screen <- move-cursor screen, cursor-row, cursor-column
    e:event, console:address:console, found?:boolean, quit?:boolean <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    # 'touch' event
    t:touch-event, is-touch?:boolean <- maybe-convert e, touch:variant
    {
      break-unless is-touch?
      move-cursor-in-editor screen, editor, t
      loop +next-event:label
    }
    # keyboard events
    {
      break-if is-touch?
      screen, editor, go-render?:boolean <- handle-keyboard-event screen, editor, e
      {
        break-unless go-render?
        screen <- editor-render screen, editor
      }
    }
    loop
  }
]

# process click, return if it was on current editor
def move-cursor-in-editor screen:address:screen, editor:address:editor-data, t:touch-event -> in-focus?:boolean, editor:address:editor-data [
  local-scope
  load-ingredients
  return-unless editor, 0/false
  click-row:number <- get t, row:offset
  return-unless click-row, 0/false  # ignore clicks on 'menu'
  click-column:number <- get t, column:offset
  left:number <- get *editor, left:offset
  too-far-left?:boolean <- lesser-than click-column, left
  return-if too-far-left?, 0/false
  right:number <- get *editor, right:offset
  too-far-right?:boolean <- greater-than click-column, right
  return-if too-far-right?, 0/false
  # position cursor
  <move-cursor-begin>
  editor <- snap-cursor screen, editor, click-row, click-column
  undo-coalesce-tag:number <- copy 0/never
  <move-cursor-end>
  # gain focus
  return 1/true
]

# Variant of 'render' that only moves the cursor (coordinates and
# before-cursor). If it's past the end of a line, it 'slides' it left. If it's
# past the last line it positions at end of last line.
def snap-cursor screen:address:screen, editor:address:editor-data, target-row:number, target-column:number -> editor:address:editor-data [
  local-scope
  load-ingredients
  return-unless editor
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  screen-height:number <- screen-height screen
  # count newlines until screen row
  curr:address:duplex-list:character <- get *editor, top-of-screen:offset
  prev:address:duplex-list:character <- copy curr  # just in case curr becomes null and we can't compute prev
  curr <- next curr
  row:number <- copy 1/top
  column:number <- copy left
  *editor <- put *editor, cursor-row:offset, target-row
  cursor-row:number <- copy target-row
  *editor <- put *editor, cursor-column:offset, target-column
  cursor-column:number <- copy target-column
  before-cursor:address:duplex-list:character <- get *editor, before-cursor:offset
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
      *editor <- put *editor, before-cursor:offset, before-cursor
    }
    c:character <- get *curr, value:offset
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
        *editor <- put *editor, cursor-column:offset, cursor-column
        before-cursor <- copy prev
        *editor <- put *editor, before-cursor:offset, before-cursor
      }
      # skip to next line
      row <- add row, 1
      column <- copy left
      curr <- next curr
      prev <- next prev
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
    curr <- next curr
    prev <- next prev
    column <- add column, 1
    loop
  }
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:boolean <- equal row, cursor-row
    cursor-outside-line?:boolean <- lesser-or-equal column, cursor-column
    before-cursor-on-same-line?:boolean <- and at-cursor-row?, cursor-outside-line?
    above-cursor-row?:boolean <- lesser-than row, cursor-row
    before-cursor?:boolean <- or before-cursor-on-same-line?, above-cursor-row?
    break-unless before-cursor?
    cursor-row <- copy row
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- copy column
    *editor <- put *editor, cursor-column:offset, cursor-column
    before-cursor <- copy prev
    *editor <- put *editor, before-cursor:offset, before-cursor
  }
]

# Process an event 'e' and try to minimally update the screen.
# Set 'go-render?' to true to indicate the caller must perform a non-minimal update.
def handle-keyboard-event screen:address:screen, editor:address:editor-data, e:event -> screen:address:screen, editor:address:editor-data, go-render?:boolean [
  local-scope
  load-ingredients
  go-render? <- copy 0/false
  return-unless editor
  screen-width:number <- screen-width screen
  screen-height:number <- screen-height screen
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  before-cursor:address:duplex-list:character <- get *editor, before-cursor:offset
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  save-row:number <- copy cursor-row
  save-column:number <- copy cursor-column
  # character
  {
    c:character, is-unicode?:boolean <- maybe-convert e, text:variant
    break-unless is-unicode?
    trace 10, [app], [handle-keyboard-event: special character]
    # exceptions for special characters go here
    <handle-special-character>
    # ignore any other special characters
    regular-character?:boolean <- greater-or-equal c, 32/space
    go-render? <- copy 0/false
    return-unless regular-character?
    # otherwise type it in
    <insert-character-begin>
    editor, screen, go-render?:boolean <- insert-at-cursor editor, c, screen
    <insert-character-end>
    return
  }
  # special key to modify the text or move the cursor
  k:number, is-keycode?:boolean <- maybe-convert e:event, keycode:variant
  assert is-keycode?, [event was of unknown type; neither keyboard nor mouse]
  # handlers for each special key will go here
  <handle-special-key>
  go-render? <- copy 1/true
  return
]

def insert-at-cursor editor:address:editor-data, c:character, screen:address:screen -> editor:address:editor-data, screen:address:screen, go-render?:boolean [
  local-scope
  load-ingredients
  before-cursor:address:duplex-list:character <- get *editor, before-cursor:offset
  insert c, before-cursor
  before-cursor <- next before-cursor
  *editor <- put *editor, before-cursor:offset, before-cursor
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  save-row:number <- copy cursor-row
  save-column:number <- copy cursor-column
  screen-width:number <- screen-width screen
  screen-height:number <- screen-height screen
  # occasionally we'll need to mess with the cursor
  <insert-character-special-case>
  # but mostly we'll just move the cursor right
  cursor-column <- add cursor-column, 1
  *editor <- put *editor, cursor-column:offset, cursor-column
  next:address:duplex-list:character <- next before-cursor
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
    print screen, c
    go-render? <- copy 0/false
    return
  }
  {
    # not at right margin? print the character and rest of line
    break-unless next
    at-right?:boolean <- greater-or-equal cursor-column, screen-width
    break-if at-right?
    curr:address:duplex-list:character <- copy before-cursor
    move-cursor screen, save-row, save-column
    curr-column:number <- copy save-column
    {
      # hit right margin? give up and let caller render
      go-render? <- copy 1/true
      at-right?:boolean <- greater-than curr-column, right
      return-if at-right?
      break-unless curr
      # newline? done.
      currc:character <- get *curr, value:offset
      at-newline?:boolean <- equal currc, 10/newline
      break-if at-newline?
      print screen, currc
      curr-column <- add curr-column, 1
      curr <- next curr
      loop
    }
    go-render? <- copy 0/false
    return
  }
  go-render? <- copy 1/true
  return
]

# helper for tests
def editor-render screen:address:screen, editor:address:editor-data -> screen:address:screen, editor:address:editor-data [
  local-scope
  load-ingredients
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  assume-console []
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 1  # on the 'b'
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # last line, to the right of text
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # interior line, to the right of text
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 3, 7  # below text
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    # click on right half of screen
    left-click 3, 8
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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

scenario editor-handles-mouse-clicks-in-menu-area [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    # click on first, 'menu' row
    left-click 0, 3
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # no change to cursor
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
]

scenario editor-inserts-characters-into-empty-editor [
  assume-screen 10/width, 5/height
  1:address:array:character <- new []
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    type [abc]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  # type two letters at different places
  assume-console [
    type [0]
    left-click 1, 2
    type [d]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 5  # right of last line
    type [d]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 1, 5  # right of non-last line
    type [e]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [d]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [e]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  editor-render screen, 2:address:editor-data
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [ef]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  assume-console [
    type [01]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  # type a letter
  assume-console [
    type [e]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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

scenario editor-wraps-line-on-insert-2 [
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcdefg
defg]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  editor-render screen, 2:address:editor-data
  # type more text at the start
  assume-console [
    left-click 3, 0
    type [abc]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor is not wrapped
  memory-should-contain [
    3 <- 3
    4 <- 3
  ]
  # but line is wrapped
  screen-should-contain [
    .          .
    .abcd↩     .
    .efg       .
    .abcd↩     .
    .efg       .
  ]
]

after <insert-character-special-case> [
  # if the line wraps at the cursor, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:number <- subtract right, 1
    at-wrap?:boolean <- greater-or-equal cursor-column, wrap-column
    break-unless at-wrap?
    cursor-column <- subtract cursor-column, wrap-column
    cursor-column <- add cursor-column, left
    *editor <- put *editor, cursor-column:offset, cursor-column
    cursor-row <- add cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    # if we're out of the screen, scroll down
    {
      below-screen?:boolean <- greater-or-equal cursor-row, screen-height
      break-unless below-screen?
      <scroll-down>
    }
    go-render? <- copy 1/true
    return
  }
]

scenario editor-wraps-cursor-after-inserting-characters [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  assume-console [
    left-click 1, 4  # line is full; no wrap icon yet
    type [f]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  assume-console [
    left-click 1, 3  # right before the wrap icon
    type [f]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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

scenario editor-wraps-cursor-to-left-margin [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abcde]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 2/left, 7/right
  assume-console [
    left-click 1, 5  # line is full; no wrap icon yet
    type [01]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .  abc0↩   .
    .  1de     .
    .  ┈┈┈┈┈   .
    .          .
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 3  # cursor column
  ]
]

# if newline, move cursor to start of next line, and maybe align indent with previous line

container editor-data [
  indent?:boolean
]

after <editor-initialization> [
  *result <- put *result, indent?:offset, 1/true
]

scenario editor-moves-cursor-down-after-inserting-newline [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
  ]
  screen-should-contain [
    .          .
    .0         .
    .1abc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <handle-special-character> [
  {
    newline?:boolean <- equal c, 10/newline
    break-unless newline?
    <insert-enter-begin>
    editor <- insert-new-line-and-indent editor, screen
    <insert-enter-end>
    go-render? <- copy 1/true
    return
  }
]

def insert-new-line-and-indent editor:address:editor-data, screen:address:screen -> editor:address:editor-data, screen:address:screen, go-render?:boolean [
  local-scope
  load-ingredients
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  before-cursor:address:duplex-list:character <- get *editor, before-cursor:offset
  left:number <- get *editor, left:offset
  right:number <- get *editor, right:offset
  screen-height:number <- screen-height screen
  # insert newline
  insert 10/newline, before-cursor
  before-cursor <- next before-cursor
  *editor <- put *editor, before-cursor:offset, before-cursor
  cursor-row <- add cursor-row, 1
  *editor <- put *editor, cursor-row:offset, cursor-row
  cursor-column <- copy left
  *editor <- put *editor, cursor-column:offset, cursor-column
  # maybe scroll
  {
    below-screen?:boolean <- greater-or-equal cursor-row, screen-height  # must be equal, never greater
    break-unless below-screen?
    <scroll-down>
    go-render? <- copy 1/true
    cursor-row <- subtract cursor-row, 1  # bring back into screen range
    *editor <- put *editor, cursor-row:offset, cursor-row
  }
  # indent if necessary
  indent?:boolean <- get *editor, indent?:offset
  return-unless indent?
  d:address:duplex-list:character <- get *editor, data:offset
  end-of-previous-line:address:duplex-list:character <- prev before-cursor
  indent:number <- line-indent end-of-previous-line, d
  i:number <- copy 0
  {
    indent-done?:boolean <- greater-or-equal i, indent
    break-if indent-done?
    editor, screen, go-render?:boolean <- insert-at-cursor editor, 32/space, screen
    i <- add i, 1
    loop
  }
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the number of spaces at the start of the line containing 'curr'.
def line-indent curr:address:duplex-list:character, start:address:duplex-list:character -> result:number [
  local-scope
  load-ingredients
  result:number <- copy 0
  return-unless curr
  at-start?:boolean <- equal curr, start
  return-if at-start?
  {
    curr <- prev curr
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
]

scenario editor-moves-cursor-down-after-inserting-newline-2 [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 1/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 5/right
  assume-console [
    press enter
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .e         .
    .          .
    .          .
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline'
  assume-console [
    left-click 2, 8
    type [
]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
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
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline' surrounded by paste markers
  assume-console [
    left-click 2, 8
    press 65507  # start paste
    press enter
    press 65506  # end paste
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
    3:number <- get *2:address:editor-data, cursor-row:offset
    4:number <- get *2:address:editor-data, cursor-column:offset
  ]
  # cursor should be below start of previous line
  memory-should-contain [
    3 <- 3  # cursor row
    4 <- 0  # cursor column (not indented)
  ]
]

after <handle-special-key> [
  {
    paste-start?:boolean <- equal k, 65507/paste-start
    break-unless paste-start?
    *editor <- put *editor, indent?:offset, 0/false
    go-render? <- copy 1/true
    return
  }
]

after <handle-special-key> [
  {
    paste-end?:boolean <- equal k, 65506/paste-end
    break-unless paste-end?
    *editor <- put *editor, indent?:offset, 1/true
    go-render? <- copy 1/true
    return
  }
]

## helpers

def draw-horizontal screen:address:screen, row:number, x:number, right:number -> screen:address:screen [
  local-scope
  load-ingredients
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
    print screen, style, color, bg-color
    x <- add x, 1
    loop
  }
]
