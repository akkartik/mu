## handling events from the keyboard, mouse, touch screen, ...

# temporary main: interactive editor
# hit ctrl-c to exit
def! main text:text [
  local-scope
  load-ingredients
  open-console
  editor:&:editor <- new-editor text, 5/left, 45/right
  editor-event-loop 0/screen, 0/console, editor
  close-console
]

def editor-event-loop screen:&:screen, console:&:console, editor:&:editor -> screen:&:screen, console:&:console, editor:&:editor [
  local-scope
  load-ingredients
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    cursor-row:num <- get *editor, cursor-row:offset
    cursor-column:num <- get *editor, cursor-column:offset
    screen <- move-cursor screen, cursor-row, cursor-column
    e:event, found?:bool, quit?:bool, console <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    # 'touch' event
    t:touch-event, is-touch?:bool <- maybe-convert e, touch:variant
    {
      break-unless is-touch?
      move-cursor-in-editor screen, editor, t
      loop +next-event
    }
    # keyboard events
    {
      break-if is-touch?
      go-render?:bool <- handle-keyboard-event screen, editor, e
      {
        break-unless go-render?
        screen <- editor-render screen, editor
      }
    }
    loop
  }
]

# process click, return if it was on current editor
def move-cursor-in-editor screen:&:screen, editor:&:editor, t:touch-event -> in-focus?:bool, editor:&:editor [
  local-scope
  load-ingredients
  return-unless editor, 0/false
  click-row:num <- get t, row:offset
  return-unless click-row, 0/false  # ignore clicks on 'menu'
  click-column:num <- get t, column:offset
  left:num <- get *editor, left:offset
  too-far-left?:bool <- lesser-than click-column, left
  return-if too-far-left?, 0/false
  right:num <- get *editor, right:offset
  too-far-right?:bool <- greater-than click-column, right
  return-if too-far-right?, 0/false
  # position cursor
  <move-cursor-begin>
  editor <- snap-cursor screen, editor, click-row, click-column
  undo-coalesce-tag:num <- copy 0/never
  <move-cursor-end>
  # gain focus
  return 1/true
]

# Variant of 'render' that only moves the cursor (coordinates and
# before-cursor). If it's past the end of a line, it 'slides' it left. If it's
# past the last line it positions at end of last line.
def snap-cursor screen:&:screen, editor:&:editor, target-row:num, target-column:num -> editor:&:editor [
  local-scope
  load-ingredients
  return-unless editor
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  screen-height:num <- screen-height screen
  # count newlines until screen row
  curr:&:duplex-list:char <- get *editor, top-of-screen:offset
  prev:&:duplex-list:char <- copy curr  # just in case curr becomes null and we can't compute prev
  curr <- next curr
  row:num <- copy 1/top
  column:num <- copy left
  *editor <- put *editor, cursor-row:offset, target-row
  cursor-row:num <- copy target-row
  *editor <- put *editor, cursor-column:offset, target-column
  cursor-column:num <- copy target-column
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  {
    +next-character
    break-unless curr
    off-screen?:bool <- greater-or-equal row, screen-height
    break-if off-screen?
    # update editor.before-cursor
    # Doing so at the start of each iteration ensures it stays one step behind
    # the current character.
    {
      at-cursor-row?:bool <- equal row, cursor-row
      break-unless at-cursor-row?
      at-cursor?:bool <- equal column, cursor-column
      break-unless at-cursor?
      before-cursor <- copy prev
      *editor <- put *editor, before-cursor:offset, before-cursor
    }
    c:char <- get *curr, value:offset
    {
      # newline? move to left rather than 0
      newline?:bool <- equal c, 10/newline
      break-unless newline?
      # adjust cursor if necessary
      {
        at-cursor-row?:bool <- equal row, cursor-row
        break-unless at-cursor-row?
        left-of-cursor?:bool <- lesser-than column, cursor-column
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
      loop +next-character
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:bool <- equal column, right
      break-unless at-right?
      column <- copy left
      row <- add row, 1
      # don't increment curr/prev
      loop +next-character
    }
    curr <- next curr
    prev <- next prev
    column <- add column, 1
    loop
  }
  # is cursor to the right of the last line? move to end
  {
    at-cursor-row?:bool <- equal row, cursor-row
    cursor-outside-line?:bool <- lesser-or-equal column, cursor-column
    before-cursor-on-same-line?:bool <- and at-cursor-row?, cursor-outside-line?
    above-cursor-row?:bool <- lesser-than row, cursor-row
    before-cursor?:bool <- or before-cursor-on-same-line?, above-cursor-row?
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
def handle-keyboard-event screen:&:screen, editor:&:editor, e:event -> go-render?:bool, screen:&:screen, editor:&:editor [
  local-scope
  load-ingredients
  return-unless editor, 0/don't-render
  screen-width:num <- screen-width screen
  screen-height:num <- screen-height screen
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  save-row:num <- copy cursor-row
  save-column:num <- copy cursor-column
  # character
  {
    c:char, is-unicode?:bool <- maybe-convert e, text:variant
    break-unless is-unicode?
    trace 10, [app], [handle-keyboard-event: special character]
    # exceptions for special characters go here
    <handle-special-character>
    # ignore any other special characters
    regular-character?:bool <- greater-or-equal c, 32/space
    return-unless regular-character?, 0/don't-render
    # otherwise type it in
    <insert-character-begin>
    go-render? <- insert-at-cursor editor, c, screen
    <insert-character-end>
    return
  }
  # special key to modify the text or move the cursor
  k:num, is-keycode?:bool <- maybe-convert e:event, keycode:variant
  assert is-keycode?, [event was of unknown type; neither keyboard nor mouse]
  # handlers for each special key will go here
  <handle-special-key>
  return 1/go-render
]

def insert-at-cursor editor:&:editor, c:char, screen:&:screen -> go-render?:bool, editor:&:editor, screen:&:screen [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  insert c, before-cursor
  before-cursor <- next before-cursor
  *editor <- put *editor, before-cursor:offset, before-cursor
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  save-row:num <- copy cursor-row
  save-column:num <- copy cursor-column
  screen-width:num <- screen-width screen
  screen-height:num <- screen-height screen
  # occasionally we'll need to mess with the cursor
  <insert-character-special-case>
  # but mostly we'll just move the cursor right
  cursor-column <- add cursor-column, 1
  *editor <- put *editor, cursor-column:offset, cursor-column
  next:&:duplex-list:char <- next before-cursor
  {
    # at end of all text? no need to scroll? just print the character and leave
    at-end?:bool <- equal next, 0/null
    break-unless at-end?
    bottom:num <- subtract screen-height, 1
    at-bottom?:bool <- equal save-row, bottom
    at-right?:bool <- equal save-column, right
    overflow?:bool <- and at-bottom?, at-right?
    break-if overflow?
    move-cursor screen, save-row, save-column
    print screen, c
    return 0/don't-render
  }
  {
    # not at right margin? print the character and rest of line
    break-unless next
    at-right?:bool <- greater-or-equal cursor-column, screen-width
    break-if at-right?
    curr:&:duplex-list:char <- copy before-cursor
    move-cursor screen, save-row, save-column
    curr-column:num <- copy save-column
    {
      # hit right margin? give up and let caller render
      at-right?:bool <- greater-than curr-column, right
      return-if at-right?, 1/go-render
      break-unless curr
      # newline? done.
      currc:char <- get *curr, value:offset
      at-newline?:bool <- equal currc, 10/newline
      break-if at-newline?
      print screen, currc
      curr-column <- add curr-column, 1
      curr <- next curr
      loop
    }
    return 0/don't-render
  }
  return 1/go-render
]

# helper for tests
def editor-render screen:&:screen, editor:&:editor -> screen:&:screen, editor:&:editor [
  local-scope
  load-ingredients
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  row:num, column:num <- render screen, editor
  clear-line-until screen, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9480/horizontal-dotted
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
]

scenario editor-handles-empty-event-queue [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  editor-render screen, e
  assume-console []
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-handles-mouse-clicks [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 1  # on the 'b'
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # last line, to the right of text
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-text-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
def]
  e:&:editor <- new-editor s, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 1, 7  # interior line, to the right of text
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-text-3 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
def]
  e:&:editor <- new-editor s, 0/left, 10/right
  $clear-trace
  assume-console [
    left-click 3, 7  # below text
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2  # cursor row
    4 <- 3  # cursor column
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-handles-mouse-clicks-outside-column [
  local-scope
  assume-screen 10/width, 5/height
  # editor occupies only left half of screen
  e:&:editor <- new-editor [abc], 0/left, 5/right
  editor-render screen, e
  $clear-trace
  assume-console [
    # click on right half of screen
    left-click 3, 8
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 5/right
  editor-render screen, e
  $clear-trace
  assume-console [
    # click on first, 'menu' row
    left-click 0, 3
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # no change to cursor
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
]

scenario editor-inserts-characters-into-empty-editor [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 5/right
  editor-render screen, e
  $clear-trace
  assume-console [
    type [abc]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # type two letters at different places
  assume-console [
    type [0]
    left-click 1, 2
    type [d]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 5  # right of last line
    type [d]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 5  # right of non-last line
    type [e]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [d]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [e]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 3, 5  # below all text
    type [ef]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [ab], 0/left, 5/right
  editor-render screen, e
  assume-console [
    type [01]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 5/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 5/right
  editor-render screen, e
  # type a letter
  assume-console [
    type [e]
  ]
  run [
    editor-event-loop screen, console, e
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
    editor-event-loop screen, console, e
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
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  s:text <- new [abcdefg
defg]
  e:&:editor <- new-editor s, 0/left, 5/right
  editor-render screen, e
  # type more text at the start
  assume-console [
    left-click 3, 0
    type [abc]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    # if either:
    # a) we're at the end of the line and at the column of the wrap indicator, or
    # b) we're not at end of line and just before the column of the wrap indicator
    wrap-column:num <- copy right
    before-wrap-column:num <- subtract wrap-column, 1
    at-wrap?:bool <- greater-or-equal cursor-column, wrap-column
    just-before-wrap?:bool <- greater-or-equal cursor-column, before-wrap-column
    next:&:duplex-list:char <- next before-cursor
    # at end of line? next == 0 || next.value == 10/newline
    at-end-of-line?:bool <- equal next, 0
    {
      break-if at-end-of-line?
      next-character:char <- get *next, value:offset
      at-end-of-line? <- equal next-character, 10/newline
    }
    # break unless ((eol? and at-wrap?) or (~eol? and just-before-wrap?))
    move-cursor-to-next-line?:bool <- copy 0/false
    {
      break-if at-end-of-line?
      move-cursor-to-next-line? <- copy just-before-wrap?
      # if we're moving the cursor because it's in the middle of a wrapping
      # line, adjust it to left-most column
      potential-new-cursor-column:num <- copy left
    }
    {
      break-unless at-end-of-line?
      move-cursor-to-next-line? <- copy at-wrap?
      # if we're moving the cursor because it's at the end of a wrapping line,
      # adjust it to one past the left-most column to make room for the
      # newly-inserted wrap-indicator
      potential-new-cursor-column:num <- add left, 1/make-room-for-wrap-indicator
    }
    break-unless move-cursor-to-next-line?
    cursor-column <- copy potential-new-cursor-column
    *editor <- put *editor, cursor-column:offset, cursor-column
    cursor-row <- add cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    # if we're out of the screen, scroll down
    {
      below-screen?:bool <- greater-or-equal cursor-row, screen-height
      break-unless below-screen?
      <scroll-down>
    }
    return 1/go-render
  }
]

scenario editor-wraps-cursor-after-inserting-characters-in-middle-of-line [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abcde], 0/left, 5/right
  assume-console [
    left-click 1, 3  # right before the wrap icon
    type [f]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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

scenario editor-wraps-cursor-after-inserting-characters-at-end-of-line [
  local-scope
  assume-screen 10/width, 5/height
  # create an editor containing two lines
  s:text <- new [abc
xyz]
  e:&:editor <- new-editor s, 0/left, 5/right
  editor-render screen, e
  screen-should-contain [
    .          .
    .abc       .
    .xyz       .
    .┈┈┈┈┈     .
    .          .
  ]
  assume-console [
    left-click 1, 4  # at end of first line
    type [de]  # trigger wrap
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .e         .
    .xyz       .
    .┈┈┈┈┈     .
  ]
]

scenario editor-wraps-cursor-to-left-margin [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abcde], 2/left, 7/right
  assume-console [
    left-click 1, 5  # line is full; no wrap icon yet
    type [01]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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

container editor [
  indent?:bool
]

after <editor-initialization> [
  *result <- put *result, indent?:offset, 1/true
]

scenario editor-moves-cursor-down-after-inserting-newline [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 0/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen, console, e
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
    newline?:bool <- equal c, 10/newline
    break-unless newline?
    <insert-enter-begin>
    insert-new-line-and-indent editor, screen
    <insert-enter-end>
    return 1/go-render
  }
]

def insert-new-line-and-indent editor:&:editor, screen:&:screen -> editor:&:editor, screen:&:screen [
  local-scope
  load-ingredients
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  screen-height:num <- screen-height screen
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
    below-screen?:bool <- greater-or-equal cursor-row, screen-height  # must be equal, never greater
    break-unless below-screen?
    <scroll-down>
    cursor-row <- subtract cursor-row, 1  # bring back into screen range
    *editor <- put *editor, cursor-row:offset, cursor-row
  }
  # indent if necessary
  indent?:bool <- get *editor, indent?:offset
  return-unless indent?
  d:&:duplex-list:char <- get *editor, data:offset
  end-of-previous-line:&:duplex-list:char <- prev before-cursor
  indent:num <- line-indent end-of-previous-line, d
  i:num <- copy 0
  {
    indent-done?:bool <- greater-or-equal i, indent
    break-if indent-done?
    insert-at-cursor editor, 32/space, screen
    i <- add i, 1
    loop
  }
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the number of spaces at the start of the line containing 'curr'.
def line-indent curr:&:duplex-list:char, start:&:duplex-list:char -> result:num [
  local-scope
  load-ingredients
  result:num <- copy 0
  return-unless curr
  at-start?:bool <- equal curr, start
  return-if at-start?
  {
    curr <- prev curr
    break-unless curr
    at-start?:bool <- equal curr, start
    break-if at-start?
    c:char <- get *curr, value:offset
    at-newline?:bool <- equal c, 10/newline
    break-if at-newline?
    # if c is a space, increment result
    is-space?:bool <- equal c, 32/space
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], 1/left, 10/right
  assume-console [
    type [0
1]
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abcde], 0/left, 5/right
  editor-render screen, e
  screen-should-contain [
    .          .
    .abcd↩     .
    .e         .
    .┈┈┈┈┈     .
    .          .
  ]
  assume-console [
    press enter
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 10/height
  s:text <- new [ab
  cd
ef]
  e:&:editor <- new-editor s, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline'
  assume-console [
    left-click 2, 8
    type [
]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # cursor should be below start of previous line
  memory-should-contain [
    3 <- 3  # cursor row
    4 <- 2  # cursor column (indented)
  ]
]

scenario editor-skips-indent-around-paste [
  local-scope
  assume-screen 10/width, 10/height
  s:text <- new [ab
  cd
ef]
  e:&:editor <- new-editor s, 0/left, 10/right
  # position cursor after 'cd' and hit 'newline' surrounded by paste markers
  assume-console [
    left-click 2, 8
    press 65507  # start paste
    press enter
    press 65506  # end paste
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # cursor should be below start of previous line
  memory-should-contain [
    3 <- 3  # cursor row
    4 <- 0  # cursor column (not indented)
  ]
]

after <handle-special-key> [
  {
    paste-start?:bool <- equal k, 65507/paste-start
    break-unless paste-start?
    *editor <- put *editor, indent?:offset, 0/false
    return 1/go-render
  }
]

after <handle-special-key> [
  {
    paste-end?:bool <- equal k, 65506/paste-end
    break-unless paste-end?
    *editor <- put *editor, indent?:offset, 1/true
    return 1/go-render
  }
]

## helpers

def draw-horizontal screen:&:screen, row:num, x:num, right:num -> screen:&:screen [
  local-scope
  load-ingredients
  style:char, style-found?:bool <- next-ingredient
  {
    break-if style-found?
    style <- copy 9472/horizontal
  }
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
  {
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  screen <- move-cursor screen, row, x
  {
    continue?:bool <- lesser-or-equal x, right  # right is inclusive, to match editor semantics
    break-unless continue?
    print screen, style, color, bg-color
    x <- add x, 1
    loop
  }
]
