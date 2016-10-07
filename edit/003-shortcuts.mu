## special shortcuts for manipulating the editor
# Some keys on the keyboard generate unicode characters, others generate
# terminfo key codes. We need to modify different places in the two cases.

# tab - insert two spaces

scenario editor-inserts-two-spaces-on-tab [
  local-scope
  assume-screen 10/width, 5/height
  # just one character in final line
  s:text <- new [ab
cd]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  assume-console [
    press tab
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .  ab      .
    .cd        .
  ]
]

after <handle-special-character> [
  {
    tab?:bool <- equal c, 9/tab
    break-unless tab?
    <insert-character-begin>
    editor, screen, go-render?:bool <- insert-at-cursor editor, 32/space, screen
    editor, screen, go-render?:bool <- insert-at-cursor editor, 32/space, screen
    <insert-character-end>
    go-render? <- copy 1/true
    return
  }
]

# backspace - delete character before cursor

scenario editor-handles-backspace-key [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 1
    press backspace
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .bc        .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
  check-trace-count-for-label 3, [print-character]  # length of original line to overwrite
]

after <handle-special-character> [
  {
    delete-previous-character?:bool <- equal c, 8/backspace
    break-unless delete-previous-character?
    <backspace-character-begin>
    editor, screen, go-render?:bool, backspaced-cell:&:duplex-list:char <- delete-before-cursor editor, screen
    <backspace-character-end>
    return
  }
]

# return values:
#   go-render? - whether caller needs to update the screen
#   backspaced-cell - value deleted (or 0 if nothing was deleted) so we can save it for undo, etc.
def delete-before-cursor editor:&:editor, screen:&:screen -> editor:&:editor, screen:&:screen, go-render?:bool, backspaced-cell:&:duplex-list:char [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  data:&:duplex-list:char <- get *editor, data:offset
  # if at start of text (before-cursor at § sentinel), return
  prev:&:duplex-list:char <- prev before-cursor
  go-render?, backspaced-cell <- copy 0/no-more-render, 0/nothing-deleted
  return-unless prev
  trace 10, [app], [delete-before-cursor]
  original-row:num <- get *editor, cursor-row:offset
  editor, scroll?:bool <- move-cursor-coordinates-left editor
  backspaced-cell:&:duplex-list:char <- copy before-cursor
  data <- remove before-cursor, data  # will also neatly trim next/prev pointers in backspaced-cell/before-cursor
  before-cursor <- copy prev
  *editor <- put *editor, before-cursor:offset, before-cursor
  go-render? <- copy 1/true
  return-if scroll?
  screen-width:num <- screen-width screen
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  # did we just backspace over a newline?
  same-row?:bool <- equal cursor-row, original-row
  go-render? <- copy 1/true
  return-unless same-row?
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  curr:&:duplex-list:char <- next before-cursor
  screen <- move-cursor screen, cursor-row, cursor-column
  curr-column:num <- copy cursor-column
  {
    # hit right margin? give up and let caller render
    at-right?:bool <- greater-or-equal curr-column, right
    go-render? <- copy 1/true
    return-if at-right?
    break-unless curr
    # newline? done.
    currc:char <- get *curr, value:offset
    at-newline?:bool <- equal currc, 10/newline
    break-if at-newline?
    screen <- print screen, currc
    curr-column <- add curr-column, 1
    curr <- next curr
    loop
  }
  # we're guaranteed not to be at the right margin
  space:char <- copy 32/space
  screen <- print screen, space
  go-render? <- copy 0/false
]

def move-cursor-coordinates-left editor:&:editor -> editor:&:editor, go-render?:bool [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  left:num <- get *editor, left:offset
  # if not at left margin, move one character left
  {
    at-left-margin?:bool <- equal cursor-column, left
    break-if at-left-margin?
    trace 10, [app], [decrementing cursor column]
    cursor-column <- subtract cursor-column, 1
    *editor <- put *editor, cursor-column:offset, cursor-column
    go-render? <- copy 0/false
    return
  }
  # if at left margin, we must move to previous row:
  top-of-screen?:bool <- equal cursor-row, 1  # exclude menu bar
  go-render?:bool <- copy 0/false
  {
    break-if top-of-screen?
    cursor-row <- subtract cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
  }
  {
    break-unless top-of-screen?
    <scroll-up>
    go-render? <- copy 1/true
  }
  {
    # case 1: if previous character was newline, figure out how long the previous line is
    previous-character:char <- get *before-cursor, value:offset
    previous-character-is-newline?:bool <- equal previous-character, 10/newline
    break-unless previous-character-is-newline?
    # compute length of previous line
    trace 10, [app], [switching to previous line]
    d:&:duplex-list:char <- get *editor, data:offset
    end-of-line:num <- previous-line-length before-cursor, d
    right:num <- get *editor, right:offset
    width:num <- subtract right, left
    wrap?:bool <- greater-than end-of-line, width
    {
      break-unless wrap?
      _, column-offset:num <- divide-with-remainder end-of-line, width
      cursor-column <- add left, column-offset
      *editor <- put *editor, cursor-column:offset, cursor-column
    }
    {
      break-if wrap?
      cursor-column <- add left, end-of-line
      *editor <- put *editor, cursor-column:offset, cursor-column
    }
    return
  }
  # case 2: if previous-character was not newline, we're just at a wrapped line
  trace 10, [app], [wrapping to previous line]
  right:num <- get *editor, right:offset
  cursor-column <- subtract right, 1  # leave room for wrap icon
  *editor <- put *editor, cursor-column:offset, cursor-column
]

# takes a pointer 'curr' into the doubly-linked list and its sentinel, counts
# the length of the previous line before the 'curr' pointer.
def previous-line-length curr:&:duplex-list:char, start:&:duplex-list:char -> result:num [
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
    result <- add result, 1
    loop
  }
]

scenario editor-clears-last-line-on-backspace [
  local-scope
  assume-screen 10/width, 5/height
  # just one character in final line
  s:text <- new [ab
cd]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  assume-console [
    left-click 2, 0  # cursor at only character in final line
    press backspace
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd      .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  memory-should-contain [
    4 <- 1
    5 <- 2
  ]
]

scenario editor-joins-and-wraps-lines-on-backspace [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with two long-ish but non-wrapping lines
  s:text <- new [abc def
ghi jkl]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # position the cursor at the start of the second and hit backspace
  assume-console [
    left-click 2, 0
    press backspace
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # resulting single line should wrap correctly
  screen-should-contain [
    .          .
    .abc defgh↩.
    .i jkl     .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-wraps-long-lines-on-backspace [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor in part of the screen with a long line
  e:&:editor <- new-editor [abc def ghij], screen, 0/left, 8/right
  editor-render screen, e
  # confirm that it wraps
  screen-should-contain [
    .          .
    .abc def↩  .
    . ghij     .
    .╌╌╌╌╌╌╌╌  .
  ]
  $clear-trace
  # position the cursor somewhere in the middle of the top screen line and hit backspace
  assume-console [
    left-click 1, 4
    press backspace
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # resulting single line should wrap correctly and not overflow its bounds
  screen-should-contain [
    .          .
    .abcdef ↩  .
    .ghij      .
    .╌╌╌╌╌╌╌╌  .
    .          .
  ]
]

# delete - delete character at cursor

scenario editor-handles-delete-key [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    press delete
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .bc        .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]  # length of original line to overwrite
  $clear-trace
  assume-console [
    press delete
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .c         .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]  # new length to overwrite
]

after <handle-special-key> [
  {
    delete-next-character?:bool <- equal k, 65522/delete
    break-unless delete-next-character?
    <delete-character-begin>
    editor, screen, go-render?:bool, deleted-cell:&:duplex-list:char <- delete-at-cursor editor, screen
    <delete-character-end>
    return
  }
]

def delete-at-cursor editor:&:editor, screen:&:screen -> editor:&:editor, screen:&:screen, go-render?:bool, deleted-cell:&:duplex-list:char [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  data:&:duplex-list:char <- get *editor, data:offset
  deleted-cell:&:duplex-list:char <- next before-cursor
  go-render? <- copy 0/false
  return-unless deleted-cell
  currc:char <- get *deleted-cell, value:offset
  data <- remove deleted-cell, data
  deleted-newline?:bool <- equal currc, 10/newline
  go-render? <- copy 1/true
  return-if deleted-newline?
  # wasn't a newline? render rest of line
  curr:&:duplex-list:char <- next before-cursor  # refresh after remove above
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  screen <- move-cursor screen, cursor-row, cursor-column
  curr-column:num <- copy cursor-column
  screen-width:num <- screen-width screen
  {
    # hit right margin? give up and let caller render
    at-right?:bool <- greater-or-equal curr-column, screen-width
    go-render? <- copy 1/true
    return-if at-right?
    break-unless curr
    # newline? done.
    currc:char <- get *curr, value:offset
    at-newline?:bool <- equal currc, 10/newline
    break-if at-newline?
    screen <- print screen, currc
    curr-column <- add curr-column, 1
    curr <- next curr
    loop
  }
  # we're guaranteed not to be at the right margin
  space:char <- copy 32/space
  screen <- print screen, space
  go-render? <- copy 0/false
]

# right arrow

scenario editor-moves-cursor-right-with-key [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    press right-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]  # 0 and following characters
]

after <handle-special-key> [
  {
    move-to-next-character?:bool <- equal k, 65514/right-arrow
    break-unless move-to-next-character?
    # if not at end of text
    next-cursor:&:duplex-list:char <- next before-cursor
    break-unless next-cursor
    # scan to next character
    <move-cursor-begin>
    before-cursor <- copy next-cursor
    *editor <- put *editor, before-cursor:offset, before-cursor
    editor, go-render?:bool <- move-cursor-coordinates-right editor, screen-height
    screen <- move-cursor screen, cursor-row, cursor-column
    undo-coalesce-tag:num <- copy 2/right-arrow
    <move-cursor-end>
    return
  }
]

def move-cursor-coordinates-right editor:&:editor, screen-height:num -> editor:&:editor, go-render?:bool [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor before-cursor:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  # if crossed a newline, move cursor to start of next row
  {
    old-cursor-character:char <- get *before-cursor, value:offset
    was-at-newline?:bool <- equal old-cursor-character, 10/newline
    break-unless was-at-newline?
    cursor-row <- add cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- copy left
    *editor <- put *editor, cursor-column:offset, cursor-column
    below-screen?:bool <- greater-or-equal cursor-row, screen-height  # must be equal
    go-render? <- copy 0/false
    return-unless below-screen?
    <scroll-down>
    cursor-row <- subtract cursor-row, 1  # bring back into screen range
    *editor <- put *editor, cursor-row:offset, cursor-row
    go-render? <- copy 1/true
    return
  }
  # if the line wraps, move cursor to start of next row
  {
    # if we're at the column just before the wrap indicator
    wrap-column:num <- subtract right, 1
    at-wrap?:bool <- equal cursor-column, wrap-column
    break-unless at-wrap?
    # and if next character isn't newline
    next:&:duplex-list:char <- next before-cursor
    break-unless next
    next-character:char <- get *next, value:offset
    newline?:bool <- equal next-character, 10/newline
    break-if newline?
    cursor-row <- add cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- copy left
    *editor <- put *editor, cursor-column:offset, cursor-column
    below-screen?:bool <- greater-or-equal cursor-row, screen-height  # must be equal
    return-unless below-screen?, editor/same-as-ingredient:0, 0/no-more-render
    <scroll-down>
    cursor-row <- subtract cursor-row, 1  # bring back into screen range
    *editor <- put *editor, cursor-row:offset, cursor-row
    go-render? <- copy 1/true
    return
  }
  # otherwise move cursor one character right
  cursor-column <- add cursor-column, 1
  *editor <- put *editor, cursor-column:offset, cursor-column
  go-render? <- copy 0/false
]

scenario editor-moves-cursor-to-next-line-with-right-arrow [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # type right-arrow a few times to get to start of second line
  assume-console [
    press right-arrow
    press right-arrow
    press right-arrow
    press right-arrow  # next line
  ]
  run [
    editor-event-loop screen, console, e
  ]
  check-trace-count-for-label 0, [print-character]
  # type something and ensure it goes where it should
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0d        .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]  # new length of second line
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, screen, 1/left, 10/right
  editor-render screen, e
  assume-console [
    press right-arrow
    press right-arrow
    press right-arrow
    press right-arrow  # next line
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    . abc      .
    . 0d       .
    . ╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abcdef], screen, 0/left, 5/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 3
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .╌╌╌╌╌     .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-2 [
  local-scope
  assume-screen 10/width, 5/height
  # line just barely wrapping
  e:&:editor <- new-editor [abcde], screen, 0/left, 5/right
  editor-render screen, e
  $clear-trace
  # position cursor at last character before wrap and hit right-arrow
  assume-console [
    left-click 1, 3
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  # now hit right arrow again
  assume-console [
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-wrapped-line-with-right-arrow-3 [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abcdef], screen, 1/left, 6/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 4
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  screen-should-contain [
    .          .
    . abcd↩    .
    . ef       .
    . ╌╌╌╌╌    .
    .          .
  ]
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-next-line-with-right-arrow-at-end-of-line [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # move to end of line, press right-arrow, type a character
  assume-console [
    left-click 1, 3
    press right-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # new character should be in next line
  screen-should-contain [
    .          .
    .abc       .
    .0d        .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 2, [print-character]
]

# todo: ctrl-right: next word-end

# left arrow

scenario editor-moves-cursor-left-with-key [
  local-scope
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [abc], screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 2
    press left-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 3, [print-character]
]

after <handle-special-key> [
  {
    move-to-previous-character?:bool <- equal k, 65515/left-arrow
    break-unless move-to-previous-character?
    trace 10, [app], [left arrow]
    # if not at start of text (before-cursor at § sentinel)
    prev:&:duplex-list:char <- prev before-cursor
    go-render? <- copy 0/false
    return-unless prev
    <move-cursor-begin>
    editor, go-render? <- move-cursor-coordinates-left editor
    before-cursor <- copy prev
    *editor <- put *editor, before-cursor:offset, before-cursor
    undo-coalesce-tag:num <- copy 1/left-arrow
    <move-cursor-end>
    return
  }
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with two lines
  s:text <- new [abc
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # position cursor at start of second line (so there's no previous newline)
  assume-console [
    left-click 2, 0
    press left-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-2 [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with three lines
  s:text <- new [abc
def
g]
  e:&:editor <- new-editor s:text, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # position cursor further down (so there's a newline before the character at
  # the cursor)
  assume-console [
    left-click 3, 0
    press left-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def0      .
    .g         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
  check-trace-count-for-label 1, [print-character]  # just the '0'
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-3 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
def
g]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # position cursor at start of text, press left-arrow, then type a character
  assume-console [
    left-click 1, 0
    press left-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # left-arrow should have had no effect
  screen-should-contain [
    .          .
    .0abc      .
    .def       .
    .g         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
  check-trace-count-for-label 4, [print-character]  # length of first line
]

scenario editor-moves-cursor-to-previous-line-with-left-arrow-at-start-of-line-4 [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with text containing an empty line
  s:text <- new [abc

d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e:&:editor
  $clear-trace
  # position cursor right after empty line
  assume-console [
    left-click 3, 0
    press left-arrow
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0         .
    .d         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
  check-trace-count-for-label 1, [print-character]  # just the '0'
]

scenario editor-moves-across-screen-lines-across-wrap-with-left-arrow [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with a wrapping line
  e:&:editor <- new-editor [abcdef], screen, 0/left, 5/right
  editor-render screen, e
  $clear-trace
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .╌╌╌╌╌     .
    .          .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 2, 0
    press left-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # previous row
    4 <- 3  # right margin except wrap icon
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-across-screen-lines-to-wrapping-line-with-left-arrow [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with a wrapping line followed by a second line
  s:text <- new [abcdef
g]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  editor-render screen, e
  $clear-trace
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .g         .
    .╌╌╌╌╌     .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 3, 0
    press left-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 2  # previous row
    4 <- 2  # end of wrapped line
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-across-screen-lines-to-non-wrapping-line-with-left-arrow [
  local-scope
  assume-screen 10/width, 5/height
  # initialize editor with a line on the verge of wrapping, followed by a second line
  s:text <- new [abcd
e]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  editor-render screen, e
  $clear-trace
  screen-should-contain [
    .          .
    .abcd      .
    .e         .
    .╌╌╌╌╌     .
    .          .
  ]
  # position cursor right after empty line
  assume-console [
    left-click 2, 0
    press left-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    3 <- 1  # previous row
    4 <- 4  # end of wrapped line
  ]
  check-trace-count-for-label 0, [print-character]
]

# todo: ctrl-left: previous word-start

# up arrow

scenario editor-moves-to-previous-line-with-up-arrow [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
def]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 2, 1
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .a0bc      .
    .def       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

after <handle-special-key> [
  {
    move-to-previous-line?:bool <- equal k, 65517/up-arrow
    break-unless move-to-previous-line?
    <move-cursor-begin>
    editor, go-render? <- move-to-previous-line editor
    undo-coalesce-tag:num <- copy 3/up-arrow
    <move-cursor-end>
    return
  }
]

def move-to-previous-line editor:&:editor -> editor:&:editor, go-render?:bool [
  local-scope
  load-ingredients
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  already-at-top?:bool <- lesser-or-equal cursor-row, 1/top
  {
    # if cursor not at top, move it
    break-if already-at-top?
    # if not at newline, move to start of line (previous newline)
    # then scan back another line
    # if either step fails, give up without modifying cursor or coordinates
    curr:&:duplex-list:char <- copy before-cursor
    {
      old:&:duplex-list:char <- copy curr
      c2:char <- get *curr, value:offset
      at-newline?:bool <- equal c2, 10/newline
      break-if at-newline?
      curr:&:duplex-list:char <- before-previous-line curr, editor
      no-motion?:bool <- equal curr, old
      go-render? <- copy 0/false
      return-if no-motion?
    }
    {
      old <- copy curr
      curr <- before-previous-line curr, editor
      no-motion?:bool <- equal curr, old
      go-render? <- copy 0/false
      return-if no-motion?
    }
    before-cursor <- copy curr
    *editor <- put *editor, before-cursor:offset, before-cursor
    cursor-row <- subtract cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    # scan ahead to right column or until end of line
    target-column:num <- copy cursor-column
    cursor-column <- copy left
    *editor <- put *editor, cursor-column:offset, cursor-column
    {
      done?:bool <- greater-or-equal cursor-column, target-column
      break-if done?
      curr:&:duplex-list:char <- next before-cursor
      break-unless curr
      currc:char <- get *curr, value:offset
      at-newline?:bool <- equal currc, 10/newline
      break-if at-newline?
      #
      before-cursor <- copy curr
      *editor <- put *editor, before-cursor:offset, before-cursor
      cursor-column <- add cursor-column, 1
      *editor <- put *editor, cursor-column:offset, cursor-column
      loop
    }
    go-render? <- copy 0/false
    return
  }
  {
    # if cursor already at top, scroll up
    break-unless already-at-top?
    <scroll-up>
    go-render? <- copy 1/true
    return
  }
]

scenario editor-adjusts-column-at-previous-line [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [ab
def]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 2, 3
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .ab0       .
    .def       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-adjusts-column-at-empty-line [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [
def]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 2, 3
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .0         .
    .def       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-moves-to-previous-line-from-left-margin [
  local-scope
  assume-screen 10/width, 5/height
  # start out with three lines
  s:text <- new [abc
def
ghi]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # click on the third line and hit up-arrow, so you end up just after a newline
  assume-console [
    left-click 3, 0
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0def      .
    .ghi       .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
]

# down arrow

scenario editor-moves-to-next-line-with-down-arrow [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
def]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # cursor starts out at (1, 0)
  assume-console [
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .0def      .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

after <handle-special-key> [
  {
    move-to-next-line?:bool <- equal k, 65516/down-arrow
    break-unless move-to-next-line?
    <move-cursor-begin>
    editor, go-render? <- move-to-next-line editor, screen-height
    undo-coalesce-tag:num <- copy 4/down-arrow
    <move-cursor-end>
    return
  }
]

def move-to-next-line editor:&:editor, screen-height:num -> editor:&:editor, go-render?:bool [
  local-scope
  load-ingredients
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  last-line:num <- subtract screen-height, 1
  already-at-bottom?:bool <- greater-or-equal cursor-row, last-line
  {
    # if cursor not at bottom, move it
    break-if already-at-bottom?
    # scan to start of next line, then to right column or until end of line
    max:num <- subtract right, left
    next-line:&:duplex-list:char <- before-start-of-next-line before-cursor, max
    {
      # already at end of buffer? try to scroll up (so we can see more
      # warnings or sandboxes below)
      no-motion?:bool <- equal next-line, before-cursor
      break-unless no-motion?
      scroll?:bool <- greater-than cursor-row, 1
      break-if scroll?, +try-to-scroll:label
      go-render? <- copy 0/false
      return
    }
    cursor-row <- add cursor-row, 1
    *editor <- put *editor, cursor-row:offset, cursor-row
    before-cursor <- copy next-line
    *editor <- put *editor, before-cursor:offset, before-cursor
    target-column:num <- copy cursor-column
    cursor-column <- copy left
    *editor <- put *editor, cursor-column:offset, cursor-column
    {
      done?:bool <- greater-or-equal cursor-column, target-column
      break-if done?
      curr:&:duplex-list:char <- next before-cursor
      break-unless curr
      currc:char <- get *curr, value:offset
      at-newline?:bool <- equal currc, 10/newline
      break-if at-newline?
      #
      before-cursor <- copy curr
      *editor <- put *editor, before-cursor:offset, before-cursor
      cursor-column <- add cursor-column, 1
      *editor <- put *editor, cursor-column:offset, cursor-column
      loop
    }
    go-render? <- copy 0/false
    return
  }
  +try-to-scroll
  <scroll-down>
  go-render? <- copy 1/true
]

scenario editor-adjusts-column-at-next-line [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
de]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  assume-console [
    left-click 1, 3
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .de0       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

# ctrl-a/home - move cursor to start of line

scenario editor-moves-to-start-of-line-with-ctrl-a [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on second line, press ctrl-a
  assume-console [
    left-click 2, 3
    press ctrl-a
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 2
    5 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

after <handle-special-character> [
  {
    move-to-start-of-line?:bool <- equal c, 1/ctrl-a
    break-unless move-to-start-of-line?
    <move-cursor-begin>
    move-to-start-of-line editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    go-render? <- copy 0/false
    return
  }
]

after <handle-special-key> [
  {
    move-to-start-of-line?:bool <- equal k, 65521/home
    break-unless move-to-start-of-line?
    <move-cursor-begin>
    move-to-start-of-line editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    go-render? <- copy 0/false
    return
  }
]

def move-to-start-of-line editor:&:editor -> editor:&:editor [
  local-scope
  load-ingredients
  # update cursor column
  left:num <- get *editor, left:offset
  cursor-column:num <- copy left
  *editor <- put *editor, cursor-column:offset, cursor-column
  # update before-cursor
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  init:&:duplex-list:char <- get *editor, data:offset
  # while not at start of line, move 
  {
    at-start-of-text?:bool <- equal before-cursor, init
    break-if at-start-of-text?
    prev:char <- get *before-cursor, value:offset
    at-start-of-line?:bool <- equal prev, 10/newline
    break-if at-start-of-line?
    before-cursor <- prev before-cursor
    *editor <- put *editor, before-cursor:offset, before-cursor
    assert before-cursor, [move-to-start-of-line tried to move before start of text]
    loop
  }
]

scenario editor-moves-to-start-of-line-with-ctrl-a-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on first line (no newline before), press ctrl-a
  assume-console [
    left-click 1, 3
    press ctrl-a
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    4 <- 1
    5 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-start-of-line-with-home [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  $clear-trace
  # start on second line, press 'home'
  assume-console [
    left-click 2, 3
    press home
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves to start of line
  memory-should-contain [
    3 <- 2
    4 <- 0
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-start-of-line-with-home-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on first line (no newline before), press 'home'
  assume-console [
    left-click 1, 3
    press home
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on first line, press ctrl-e
  assume-console [
    left-click 1, 1
    press ctrl-e
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  memory-should-contain [
    4 <- 1
    5 <- 4
  ]
  screen-should-contain [
    .          .
    .123z      .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  check-trace-count-for-label 1, [print-character]
]

after <handle-special-character> [
  {
    move-to-end-of-line?:bool <- equal c, 5/ctrl-e
    break-unless move-to-end-of-line?
    <move-cursor-begin>
    move-to-end-of-line editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    go-render? <- copy 0/false
    return
  }
]

after <handle-special-key> [
  {
    move-to-end-of-line?:bool <- equal k, 65520/end
    break-unless move-to-end-of-line?
    <move-cursor-begin>
    move-to-end-of-line editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    go-render? <- copy 0/false
    return
  }
]

def move-to-end-of-line editor:&:editor -> editor:&:editor [
  local-scope
  load-ingredients
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  cursor-column:num <- get *editor, cursor-column:offset
  # while not at start of line, move 
  {
    next:&:duplex-list:char <- next before-cursor
    break-unless next  # end of text
    nextc:char <- get *next, value:offset
    at-end-of-line?:bool <- equal nextc, 10/newline
    break-if at-end-of-line?
    before-cursor <- copy next
    *editor <- put *editor, before-cursor:offset, before-cursor
    cursor-column <- add cursor-column, 1
    *editor <- put *editor, cursor-column:offset, cursor-column
    loop
  }
]

scenario editor-moves-to-end-of-line-with-ctrl-e-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on second line (no newline after), press ctrl-e
  assume-console [
    left-click 2, 1
    press ctrl-e
  ]
  run [
    editor-event-loop screen, console, e
    4:num/raw <- get *e, cursor-row:offset
    5:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    4 <- 2
    5 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-end-of-line-with-end [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on first line, press 'end'
  assume-console [
    left-click 1, 1
    press end
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves to end of line
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
]

scenario editor-moves-to-end-of-line-with-end-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # start on second line (no newline after), press 'end'
  assume-console [
    left-click 2, 1
    press end
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start on second line, press ctrl-u
  assume-console [
    left-click 2, 2
    press ctrl-u
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .123       .
    .6         .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

after <handle-special-character> [
  {
    delete-to-start-of-line?:bool <- equal c, 21/ctrl-u
    break-unless delete-to-start-of-line?
    <delete-to-start-of-line-begin>
    deleted-cells:&:duplex-list:char <- delete-to-start-of-line editor
    <delete-to-start-of-line-end>
    go-render? <- copy 1/true
    return
  }
]

def delete-to-start-of-line editor:&:editor -> result:&:duplex-list:char, editor:&:editor [
  local-scope
  load-ingredients
  # compute range to delete
  init:&:duplex-list:char <- get *editor, data:offset
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  start:&:duplex-list:char <- copy before-cursor
  end:&:duplex-list:char <- next before-cursor
  {
    at-start-of-text?:bool <- equal start, init
    break-if at-start-of-text?
    curr:char <- get *start, value:offset
    at-start-of-line?:bool <- equal curr, 10/newline
    break-if at-start-of-line?
    start <- prev start
    assert start, [delete-to-start-of-line tried to move before start of text]
    loop
  }
  # snip it out
  result:&:duplex-list:char <- next start
  remove-between start, end
  # adjust cursor
  before-cursor <- copy start
  *editor <- put *editor, before-cursor:offset, before-cursor
  left:num <- get *editor, left:offset
  *editor <- put *editor, cursor-column:offset, left
]

scenario editor-deletes-to-start-of-line-with-ctrl-u-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start on first line (no newline before), press ctrl-u
  assume-console [
    left-click 1, 2
    press ctrl-u
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .3         .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-start-of-line-with-ctrl-u-3 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start past end of line, press ctrl-u
  assume-console [
    left-click 1, 3
    press ctrl-u
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .          .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-start-of-final-line-with-ctrl-u [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start past end of final line, press ctrl-u
  assume-console [
    left-click 2, 3
    press ctrl-u
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to start of line
  screen-should-contain [
    .          .
    .123       .
    .          .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

# ctrl-k - delete text from cursor to end of line (but not the newline)

scenario editor-deletes-to-end-of-line-with-ctrl-k [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start on first line, press ctrl-k
  assume-console [
    left-click 1, 1
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .1         .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

after <handle-special-character> [
  {
    delete-to-end-of-line?:bool <- equal c, 11/ctrl-k
    break-unless delete-to-end-of-line?
    <delete-to-end-of-line-begin>
    deleted-cells:&:duplex-list:char <- delete-to-end-of-line editor
    <delete-to-end-of-line-end>
    go-render? <- copy 1/true
    return
  }
]

def delete-to-end-of-line editor:&:editor -> result:&:duplex-list:char, editor:&:editor [
  local-scope
  load-ingredients
  # compute range to delete
  start:&:duplex-list:char <- get *editor, before-cursor:offset
  end:&:duplex-list:char <- next start
  {
    at-end-of-text?:bool <- equal end, 0/null
    break-if at-end-of-text?
    curr:char <- get *end, value:offset
    at-end-of-line?:bool <- equal curr, 10/newline
    break-if at-end-of-line?
    end <- next end
    loop
  }
  # snip it out
  result <- next start
  remove-between start, end
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-2 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start on second line (no newline after), press ctrl-k
  assume-console [
    left-click 2, 1
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes to end of line
  screen-should-contain [
    .          .
    .123       .
    .4         .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-3 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start at end of line
  assume-console [
    left-click 1, 2
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes just last character
  screen-should-contain [
    .          .
    .12        .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-4 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start past end of line
  assume-console [
    left-click 1, 3
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes nothing
  screen-should-contain [
    .          .
    .123       .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-5 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start at end of text
  assume-console [
    left-click 2, 2
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes just the final character
  screen-should-contain [
    .          .
    .123       .
    .45        .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-deletes-to-end-of-line-with-ctrl-k-6 [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [123
456]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  # start past end of text
  assume-console [
    left-click 2, 3
    press ctrl-k
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor deletes nothing
  screen-should-contain [
    .          .
    .123       .
    .456       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

# cursor-down can scroll if necessary

scenario editor-can-scroll-down-using-arrow-keys [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen slides by one line
  screen-should-contain [
    .          .
    .b         .
    .c         .
    .d         .
  ]
]

after <scroll-down> [
  trace 10, [app], [scroll down]
  top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  max:num <- subtract right, left
  old-top:&:duplex-list:char <- copy top-of-screen
  top-of-screen <- before-start-of-next-line top-of-screen, max
  *editor <- put *editor, top-of-screen:offset, top-of-screen
  no-movement?:bool <- equal old-top, top-of-screen
  go-render? <- copy 0/false
  return-if no-movement?
]

# takes a pointer into the doubly-linked list, scans ahead at most 'max'
# positions until the next newline
# beware: never return null pointer.
def before-start-of-next-line original:&:duplex-list:char, max:num -> curr:&:duplex-list:char [
  local-scope
  load-ingredients
  count:num <- copy 0
  curr:&:duplex-list:char <- copy original
  # skip the initial newline if it exists
  {
    c:char <- get *curr, value:offset
    at-newline?:bool <- equal c, 10/newline
    break-unless at-newline?
    curr <- next curr
    count <- add count, 1
  }
  {
    return-unless curr, original
    done?:bool <- greater-or-equal count, max
    break-if done?
    c:char <- get *curr, value:offset
    at-newline?:bool <- equal c, 10/newline
    break-if at-newline?
    curr <- next curr
    count <- add count, 1
    loop
  }
  return-unless curr, original
  return curr
]

scenario editor-scrolls-down-past-wrapped-line-using-arrow-keys [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  s:text <- new [abcdef
g
h
i]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .g         .
  ]
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # editor starts with a long line wrapping twice
  s:text <- new [abcdefghij
k
l
m]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at last line, then try to move further down
  assume-console [
    left-click 3, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a long line in the third line
  s:text <- new [a
b
cdef]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at end, type a character
  assume-console [
    left-click 3, 4
    type [g]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  assume-screen 5/width, 4/height
  # position cursor after last line and type newline
  s:text <- new [a
b
c]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  assume-console [
    left-click 3, 4
    type [
]
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a wrapped line
  s:text <- new [a
b
cdefgh]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains more lines than can fit on screen
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press right-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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

scenario editor-scrolls-at-end-on-down-arrow [
  local-scope
  assume-screen 10/width, 5/height
  s:text <- new [abc
de]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  $clear-trace
  # try to move down past end of text
  assume-console [
    left-click 2, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # screen should scroll, moving cursor to end of text
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  assume-console [
    type [0]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .de0       .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
  # try to move down again
  $clear-trace
  assume-console [
    left-click 2, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # screen stops scrolling because cursor is already at top
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  check-trace-count-for-label 0, [print-character]
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .de01      .
    .╌╌╌╌╌╌╌╌╌╌.
    .          .
  ]
]

scenario editor-combines-page-and-line-scroll [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a few pages of lines
  s:text <- new [a
b
c
d
e
f
g]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # scroll down one page and one line
  assume-console [
    press page-down
    left-click 3, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at top of second page, then try to move up
  assume-console [
    press page-down
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen slides by one line
  screen-should-contain [
    .          .
    .b         .
    .c         .
    .d         .
  ]
]

after <scroll-up> [
  trace 10, [app], [scroll up]
  top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
  old-top:&:duplex-list:char <- copy top-of-screen
  top-of-screen <- before-previous-line top-of-screen, editor
  *editor <- put *editor, top-of-screen:offset, top-of-screen
  no-movement?:bool <- equal old-top, top-of-screen
  go-render? <- copy 0/false
  return-if no-movement?
]

# takes a pointer into the doubly-linked list, scans back to before start of
# previous *wrapped* line
# beware: never return null pointer
def before-previous-line in:&:duplex-list:char, editor:&:editor -> out:&:duplex-list:char [
  local-scope
  load-ingredients
  curr:&:duplex-list:char <- copy in
  c:char <- get *curr, value:offset
  # compute max, number of characters to skip
  #   1 + len%(width-1)
  #   except rotate second term to vary from 1 to width-1 rather than 0 to width-2
  left:num <- get *editor, left:offset
  right:num <- get *editor, right:offset
  max-line-length:num <- subtract right, left, -1/exclusive-right, 1/wrap-icon
  sentinel:&:duplex-list:char <- get *editor, data:offset
  len:num <- previous-line-length curr, sentinel
  {
    break-if len
    # empty line; just skip this newline
    prev:&:duplex-list:char <- prev curr
    return-unless prev, curr
    return prev
  }
  _, max:num <- divide-with-remainder len, max-line-length
  # remainder 0 => scan one width-worth
  {
    break-if max
    max <- copy max-line-length
  }
  max <- add max, 1
  count:num <- copy 0
  # skip 'max' characters
  {
    done?:bool <- greater-or-equal count, max
    break-if done?
    prev:&:duplex-list:char <- prev curr
    break-unless prev
    curr <- copy prev
    count <- add count, 1
    loop
  }
  return curr
]

scenario editor-scrolls-up-past-wrapped-line-using-arrow-keys [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  s:text <- new [abcdef
g
h
i]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  screen-should-contain [
    .          .
    .abcd↩     .
    .ef        .
    .g         .
  ]
  # position cursor at top of second page, just below wrapped line
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .g         .
    .h         .
    .i         .
  ]
  # now move up one line
  assume-console [
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 4 lines
  assume-screen 10/width, 5/height
  # editor starts with a long line wrapping twice, occupying 3 of the 4 lines
  s:text <- new [abcdefghij
k
l
m]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at top of second page
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .k         .
    .l         .
    .m         .
    .╌╌╌╌╌     .
  ]
  # move up one line
  assume-console [
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with a long, wrapped line and more than a screen of
  # other lines
  s:text <- new [abcdef
g
h
i]
  e:&:editor <- new-editor s, screen, 0/left, 6/right
  screen-should-contain [
    .          .
    .abcde↩    .
    .f         .
    .g         .
  ]
  # position cursor at top of second page, just below wrapped line
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .g         .
    .h         .
    .i         .
  ]
  # now move up one line
  assume-console [
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 4/height
  # initialize editor with some lines around an empty line
  s:text <- new [a
b

c
d
e]
  e:&:editor <- new-editor s, screen, 0/left, 6/right
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .          .
    .c         .
    .d         .
  ]
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .d         .
    .e         .
    .╌╌╌╌╌╌    .
  ]
  assume-console [
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .          .
    .c         .
    .d         .
  ]
]

scenario editor-scrolls-up-on-left-arrow [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains >3 lines
  s:text <- new [a
b
c
d
e]
  e:&:editor <- new-editor s, screen, 0/left, 5/right
  # position cursor at top of second page
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .     .
    .c    .
    .d    .
    .e    .
  ]
  # now try to move left
  assume-console [
    press left-arrow
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
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
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with >3 lines
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # position cursor at top of second page, then try to move up to start of
  # text
  assume-console [
    press page-down
    press up-arrow
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
    press up-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 4/height
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen shows next page
  screen-should-contain [
    .          .
    .c         .
    .d         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
]

after <handle-special-character> [
  {
    page-down?:bool <- equal c, 6/ctrl-f
    break-unless page-down?
    old-top:&:duplex-list:char <- get *editor, top-of-screen:offset
    <move-cursor-begin>
    page-down editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
    no-movement?:bool <- equal top-of-screen, old-top
    go-render? <- not no-movement?
    return
  }
]

after <handle-special-key> [
  {
    page-down?:bool <- equal k, 65518/page-down
    break-unless page-down?
    old-top:&:duplex-list:char <- get *editor, top-of-screen:offset
    <move-cursor-begin>
    page-down editor
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
    no-movement?:bool <- equal top-of-screen, old-top
    go-render? <- not no-movement?
    return
  }
]

# page-down skips entire wrapped lines, so it can't scroll past lines
# taking up the entire screen
def page-down editor:&:editor -> editor:&:editor [
  local-scope
  load-ingredients
  # if editor contents don't overflow screen, do nothing
  bottom-of-screen:&:duplex-list:char <- get *editor, bottom-of-screen:offset
  return-unless bottom-of-screen
  # if not, position cursor at final character
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  before-cursor:&:duplex-list:char <- prev bottom-of-screen
  *editor <- put *editor, before-cursor:offset, before-cursor
  # keep one line in common with previous page
  {
    last:char <- get *before-cursor, value:offset
    newline?:bool <- equal last, 10/newline
    break-unless newline?:bool
    before-cursor <- prev before-cursor
    *editor <- put *editor, before-cursor:offset, before-cursor
  }
  # move cursor and top-of-screen to start of that line
  move-to-start-of-line editor
  before-cursor <- get *editor, before-cursor:offset
  *editor <- put *editor, top-of-screen:offset, before-cursor
]

scenario editor-does-not-scroll-past-end [
  local-scope
  assume-screen 10/width, 4/height
  s:text <- new [a
b]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  editor-render screen, e
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen remains unmodified
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
]

scenario editor-starts-next-page-at-start-of-wrapped-line [
  local-scope
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a long last line
  s:text <- new [a
b
cdefgh]
  # editor screen triggers wrap of last line
  e:&:editor <- new-editor s, screen, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .cde↩      .
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen shows entire wrapped line
  screen-should-contain [
    .          .
    .cde↩      .
    .fgh       .
    .╌╌╌╌      .
  ]
]

scenario editor-starts-next-page-at-start-of-wrapped-line-2 [
  local-scope
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a very long line that occupies last two lines of screen
  # and still has something left over
  s:text <- new [a
bcdefgh]
  e:&:editor <- new-editor s, screen, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .bcd↩      .
    .efg↩      .
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 4/height
  s:text <- new [a
b
c
d]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen shows next page
  screen-should-contain [
    .          .
    .c         .
    .d         .
    .╌╌╌╌╌╌╌╌╌╌.
  ]
  # scroll back up
  assume-console [
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen shows original page again
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
]

after <handle-special-character> [
  {
    page-up?:bool <- equal c, 2/ctrl-b
    break-unless page-up?
    old-top:&:duplex-list:char <- get *editor, top-of-screen:offset
    <move-cursor-begin>
    editor <- page-up editor, screen-height
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
    no-movement?:bool <- equal top-of-screen, old-top
    go-render? <- not no-movement?
    return
  }
]

after <handle-special-key> [
  {
    page-up?:bool <- equal k, 65519/page-up
    break-unless page-up?
    old-top:&:duplex-list:char <- get *editor, top-of-screen:offset
    <move-cursor-begin>
    editor <- page-up editor, screen-height
    undo-coalesce-tag:num <- copy 0/never
    <move-cursor-end>
    top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
    no-movement?:bool <- equal top-of-screen, old-top
    # don't bother re-rendering if nothing changed. todo: test this
    go-render? <- not no-movement?
    return
  }
]

def page-up editor:&:editor, screen-height:num -> editor:&:editor [
  local-scope
  load-ingredients
  max:num <- subtract screen-height, 1/menu-bar, 1/overlapping-line
  count:num <- copy 0
  top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
  {
    done?:bool <- greater-or-equal count, max
    break-if done?
    prev:&:duplex-list:char <- before-previous-line top-of-screen, editor
    break-unless prev
    top-of-screen <- copy prev
    *editor <- put *editor, top-of-screen:offset, top-of-screen
    count <- add count, 1
    loop
  }
]

scenario editor-can-scroll-up-multiple-pages [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 10/width, 4/height
  # initialize editor with 8 lines
  s:text <- new [a
b
c
d
e
f
g
h]
  e:&:editor <- new-editor s, screen, 0/left, 10/right
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
  ]
  # scroll down two pages
  assume-console [
    press page-down
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
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
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
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
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 5 lines for text
  assume-screen 10/width, 6/height
  # editor contains a long line in the first page
  s:text <- new [a
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
  e:&:editor <- new-editor s, screen, 0/left, 4/right
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
    press page-down
    left-click 5, 0
    press down-arrow
  ]
  run [
    editor-event-loop screen, console, e
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
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # screen has 1 line for menu + 3 lines for text
  assume-screen 10/width, 4/height
  # editor contains a very long line that occupies last two lines of screen
  # and still has something left over
  s:text <- new [a
bcdefgh]
  e:&:editor <- new-editor s, screen, 0/left, 4/right
  # some part of last line is not displayed
  screen-should-contain [
    .          .
    .a         .
    .bcd↩      .
    .efg↩      .
  ]
  # scroll down
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
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
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  assume-screen 10/width, 4/height
  # text with empty line in second screen
  s:text <- new [axx
bxx
cxx
dxx
exx
fxx
gxx
hxx
]
  e:&:editor <- new-editor s, screen, 0/left, 4/right
  screen-should-contain [
    .          .
    .axx       .
    .bxx       .
    .cxx       .
  ]
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .cxx       .
    .dxx       .
    .exx       .
  ]
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .exx       .
    .fxx       .
    .gxx       .
  ]
  # scroll back up past empty line
  assume-console [
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .cxx       .
    .dxx       .
    .exx       .
  ]
]

scenario editor-can-scroll-up-past-empty-lines [
  local-scope
  assume-screen 10/width, 4/height
  # text with empty line in second screen
  s:text <- new [axy
bxy
cxy

dxy
exy
fxy
gxy
]
  e:&:editor <- new-editor s, screen, 0/left, 4/right
  screen-should-contain [
    .          .
    .axy       .
    .bxy       .
    .cxy       .
  ]
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .cxy       .
    .          .
    .dxy       .
  ]
  assume-console [
    press page-down
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .dxy       .
    .exy       .
    .fxy       .
  ]
  # scroll back up past empty line
  assume-console [
    press page-up
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .cxy       .
    .          .
    .dxy       .
  ]
]
