## undo/redo

# for every undoable event, create a type of *operation* that contains all the
# information needed to reverse it
exclusive-container operation [
  typing:insert-operation
  move:move-operation
  delete:delete-operation
]

container insert-operation [
  before-row:num
  before-column:num
  before-top-of-screen:&:duplex-list:char
  after-row:num
  after-column:num
  after-top-of-screen:&:duplex-list:char
  # inserted text is from 'insert-from' until 'insert-until'; list doesn't have to terminate
  insert-from:&:duplex-list:char
  insert-until:&:duplex-list:char
  tag:num  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (enter+indent)
    # 1: regular alphanumeric characters
]

container move-operation [
  before-row:num
  before-column:num
  before-top-of-screen:&:duplex-list:char
  after-row:num
  after-column:num
  after-top-of-screen:&:duplex-list:char
  tag:num  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (touch events, etc)
    # 1: left arrow
    # 2: right arrow
    # 3: up arrow
    # 4: down arrow
    # 5: line up
    # 6: line down
]

container delete-operation [
  before-row:num
  before-column:num
  before-top-of-screen:&:duplex-list:char
  after-row:num
  after-column:num
  after-top-of-screen:&:duplex-list:char
  deleted-text:&:duplex-list:char
  delete-from:&:duplex-list:char
  delete-until:&:duplex-list:char
  tag:num  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (ctrl-k, ctrl-u)
    # 1: backspace
    # 2: delete
]

# every editor accumulates a list of operations to undo/redo
container editor [
  undo:&:list:&:operation
  redo:&:list:&:operation
]

# ctrl-z - undo operation
after <handle-special-character> [
  {
    undo?:bool <- equal c, 26/ctrl-z
    break-unless undo?
    undo:&:list:&:operation <- get *editor, undo:offset
    break-unless undo
    op:&:operation <- first undo
    undo <- rest undo
    *editor <- put *editor, undo:offset, undo
    redo:&:list:&:operation <- get *editor, redo:offset
    redo <- push op, redo
    *editor <- put *editor, redo:offset, redo
    <handle-undo>
    return 1/go-render
  }
]

# ctrl-y - redo operation
after <handle-special-character> [
  {
    redo?:bool <- equal c, 25/ctrl-y
    break-unless redo?
    redo:&:list:&:operation <- get *editor, redo:offset
    break-unless redo
    op:&:operation <- first redo
    redo <- rest redo
    *editor <- put *editor, redo:offset, redo
    undo:&:list:&:operation <- get *editor, undo:offset
    undo <- push op, undo
    *editor <- put *editor, undo:offset, undo
    <handle-redo>
    return 1/go-render
  }
]

# undo typing

scenario editor-can-undo-typing [
  local-scope
  # create an editor and type a character
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [0]
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .1         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# save operation to undo
after <begin-insert-character> [
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
  cursor-before:&:duplex-list:char <- get *editor, before-cursor:offset
]
before <end-insert-character> [
  top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  undo:&:list:&:operation <- get *editor, undo:offset
  {
    # if previous operation was an insert, coalesce this operation with it
    break-unless undo
    op:&:operation <- first undo
    typing:insert-operation, is-insert?:bool <- maybe-convert *op, typing:variant
    break-unless is-insert?
    previous-coalesce-tag:num <- get typing, tag:offset
    break-unless previous-coalesce-tag
    before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
    insert-until:&:duplex-list:char <- next before-cursor
    typing <- put typing, insert-until:offset, insert-until
    typing <- put typing, after-row:offset, cursor-row
    typing <- put typing, after-column:offset, cursor-column
    typing <- put typing, after-top-of-screen:offset, top-after
    *op <- merge 0/insert-operation, typing
    break +done-adding-insert-operation
  }
  # if not, create a new operation
  insert-from:&:duplex-list:char <- next cursor-before
  insert-to:&:duplex-list:char <- next insert-from
  op:&:operation <- new operation:type
  *op <- merge 0/insert-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, insert-from, insert-to, 1/coalesce
  editor <- add-operation editor, op
  +done-adding-insert-operation
]

# enter operations never coalesce with typing before or after
after <begin-insert-enter> [
  cursor-row-before:num <- copy cursor-row
  cursor-column-before:num <- copy cursor-column
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
  cursor-before:&:duplex-list:char <- get *editor, before-cursor:offset
]
before <end-insert-enter> [
  top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-row:offset
  # never coalesce
  insert-from:&:duplex-list:char <- next cursor-before
  before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  insert-to:&:duplex-list:char <- next before-cursor
  op:&:operation <- new operation:type
  *op <- merge 0/insert-operation, cursor-row-before, cursor-column-before, top-before, cursor-row/after, cursor-column/after, top-after, insert-from, insert-to, 0/never-coalesce
  editor <- add-operation editor, op
]

# Everytime you add a new operation to the undo stack, be sure to clear the
# redo stack, because it's now obsolete.
# Beware: since we're counting cursor moves as operations, this means just
# moving the cursor can lose work on the undo stack.
def add-operation editor:&:editor, op:&:operation -> editor:&:editor [
  local-scope
  load-inputs
  undo:&:list:&:operation <- get *editor, undo:offset
  undo <- push op undo
  *editor <- put *editor, undo:offset, undo
  redo:&:list:&:operation <- get *editor, redo:offset
  redo <- copy 0
  *editor <- put *editor, redo:offset, redo
]

after <handle-undo> [
  {
    typing:insert-operation, is-insert?:bool <- maybe-convert *op, typing:variant
    break-unless is-insert?
    start:&:duplex-list:char <- get typing, insert-from:offset
    end:&:duplex-list:char <- get typing, insert-until:offset
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    before-cursor:&:duplex-list:char <- prev start
    *editor <- put *editor, before-cursor:offset, before-cursor
    remove-between before-cursor, end
    cursor-row <- get typing, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get typing, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get typing, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-can-undo-typing-multiple [
  local-scope
  # create an editor and type multiple characters
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [012]
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
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
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [a], 0/left, 10/right
  editor-render screen, e
  # type some characters
  assume-console [
    type [012]
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .012a      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .3a        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-can-undo-typing-enter [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [  abc], 0/left, 10/right
  editor-render screen, e
  # new line
  assume-console [
    left-click 1, 8
    press enter
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .  abc     .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # line is indented
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 5
  ]
  # back to original text
  screen-should-contain [
    .          .
    .  abc     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor should be at end of line
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .  abc1    .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# redo typing

scenario editor-redo-typing [
  local-scope
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [a], 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [012]
    press ctrl-z
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .0123a     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <handle-redo> [
  {
    typing:insert-operation, is-insert?:bool <- maybe-convert *op, typing:variant
    break-unless is-insert?
    before-cursor <- get *editor, before-cursor:offset
    insert-from:&:duplex-list:char <- get typing, insert-from:offset  # ignore insert-to because it's already been spliced away
    # assert insert-to matches next(before-cursor)
    splice before-cursor, insert-from
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get typing, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get typing, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get typing, after-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-redo-typing-empty [
  local-scope
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [012]
    press ctrl-z
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .0123      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-work-clears-redo-stack [
  local-scope
  # create an editor with some text, do some work, undo
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [1]
    press ctrl-z
  ]
  editor-event-loop screen, console, e
  # do some more work
  assume-console [
    type [0]
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .0abc      .
    .def       .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # nothing should happen
  screen-should-contain [
    .          .
    .0abc      .
    .def       .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-redo-typing-and-enter-and-tab [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  # insert some text and tabs, hit enter, some more text and tabs
  assume-console [
    press tab
    type [ab]
    press tab
    type [cd]
    press enter
    press tab
    type [efg]
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .  ab  cd  .
    .    efg   .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 7
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # typing in second line deleted, but not indent
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
  screen-should-contain [
    .          .
    .  ab  cd  .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # indent and newline deleted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 8
  ]
  screen-should-contain [
    .          .
    .  ab  cd  .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # empty screen
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 8
  ]
  screen-should-contain [
    .          .
    .  ab  cd  .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo again
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # newline and indent inserted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
  screen-should-contain [
    .          .
    .  ab  cd  .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo again
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # indent and newline deleted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 7
  ]
  screen-should-contain [
    .          .
    .  ab  cd  .
    .    efg   .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# undo cursor movement and scroll

scenario editor-can-undo-touch [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor
  assume-console [
    left-click 3, 1
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # click undone
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .1abc      .
    .def       .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after <begin-move-cursor> [
  cursor-row-before:num <- get *editor, cursor-row:offset
  cursor-column-before:num <- get *editor, cursor-column:offset
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
]
before <end-move-cursor> [
  top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
  cursor-row:num <- get *editor, cursor-row:offset
  cursor-column:num <- get *editor, cursor-column:offset
  {
    break-unless undo-coalesce-tag
    # if previous operation was also a move, and also had the same coalesce
    # tag, coalesce with it
    undo:&:list:&:operation <- get *editor, undo:offset
    break-unless undo
    op:&:operation <- first undo
    move:move-operation, is-move?:bool <- maybe-convert *op, move:variant
    break-unless is-move?
    previous-coalesce-tag:num <- get move, tag:offset
    coalesce?:bool <- equal undo-coalesce-tag, previous-coalesce-tag
    break-unless coalesce?
    move <- put move, after-row:offset, cursor-row
    move <- put move, after-column:offset, cursor-column
    move <- put move, after-top-of-screen:offset, top-after
    *op <- merge 1/move-operation, move
    break +done-adding-move-operation
  }
  op:&:operation <- new operation:type
  *op <- merge 1/move-operation, cursor-row-before, cursor-column-before, top-before, cursor-row/after, cursor-column/after, top-after, undo-coalesce-tag
  editor <- add-operation editor, op
  +done-adding-move-operation
]

after <handle-undo> [
  {
    move:move-operation, is-move?:bool <- maybe-convert *op, move:variant
    break-unless is-move?
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get move, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get move, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get move, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-can-undo-scroll [
  local-scope
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a wrapped line
  contents:text <- new [a
b
cdefgh]
  e:&:editor <- new-editor contents, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press right-arrow
  ]
  editor-event-loop screen, console, e
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
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
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moved back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
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
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .     .
    .b    .
    .cde1↩.
    .fgh  .
  ]
]

scenario editor-can-undo-left-arrow [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor
  assume-console [
    left-click 3, 1
    press left-arrow
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .g1hi      .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-up-arrow [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor
  assume-console [
    left-click 3, 1
    press up-arrow
  ]
  editor-event-loop screen, console, e
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .g1hi      .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-down-arrow [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor
  assume-console [
    left-click 2, 1
    press down-arrow
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .d1ef      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-ctrl-f [
  local-scope
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  contents:text <- new [a
b
c
d
e
f]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # scroll the page
  assume-console [
    press ctrl-f
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen should again show page 1
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
    .d         .
  ]
]

scenario editor-can-undo-page-down [
  local-scope
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  contents:text <- new [a
b
c
d
e
f]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # scroll the page
  assume-console [
    press page-down
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen should again show page 1
  screen-should-contain [
    .          .
    .a         .
    .b         .
    .c         .
    .d         .
  ]
]

scenario editor-can-undo-ctrl-b [
  local-scope
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  contents:text <- new [a
b
c
d
e
f]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # scroll the page down and up
  assume-console [
    press page-down
    press ctrl-b
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen should again show page 2
  screen-should-contain [
    .          .
    .d         .
    .e         .
    .f         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-page-up [
  local-scope
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  contents:text <- new [a
b
c
d
e
f]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # scroll the page down and up
  assume-console [
    press page-down
    press page-up
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # screen should again show page 2
  screen-should-contain [
    .          .
    .d         .
    .e         .
    .f         .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-ctrl-a [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press ctrl-a
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .d1ef      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-home [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press home
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .d1ef      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-ctrl-e [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press ctrl-e
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .d1ef      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-end [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press end
  ]
  editor-event-loop screen, console, e
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves back
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .d1ef      .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

scenario editor-can-undo-multiple-arrows-in-the-same-direction [
  local-scope
  # create an editor with some text
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # move the cursor
  assume-console [
    left-click 2, 1
    press right-arrow
    press right-arrow
    press up-arrow
  ]
  editor-event-loop screen, console, e
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # up-arrow is undone
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 3
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # both right-arrows are undone
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
]

# redo cursor movement and scroll

scenario editor-redo-touch [
  local-scope
  # create an editor with some text, click on a character, undo
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def
ghi]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  assume-console [
    left-click 3, 1
    press ctrl-z
  ]
  editor-event-loop screen, console, e
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # cursor moves to left-click
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .g1hi      .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after <handle-redo> [
  {
    move:move-operation, is-move?:bool <- maybe-convert *op, move:variant
    break-unless is-move?
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get move, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get move, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get move, after-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-separates-undo-insert-from-undo-cursor-move [
  local-scope
  # create an editor, type some text, move the cursor, type some more text
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  assume-console [
    type [abc]
    left-click 1, 1
    type [d]
  ]
  editor-event-loop screen, console, e
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  screen-should-contain [
    .          .
    .adbc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # last letter typed is deleted
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # no change to screen; cursor moves
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # screen empty
  screen-should-contain [
    .          .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # first insert
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  # redo again
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # cursor moves
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # cursor moves
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # redo again
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
    3:num/raw <- get *e, cursor-row:offset
    4:num/raw <- get *e, cursor-column:offset
  ]
  # second insert
  screen-should-contain [
    .          .
    .adbc      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
]

# undo backspace

scenario editor-can-undo-and-redo-backspace [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  # insert some text and hit backspace
  assume-console [
    type [abc]
    press backspace
    press backspace
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# save operation to undo
after <begin-backspace-character> [
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
]
before <end-backspace-character> [
  {
    break-unless backspaced-cell  # backspace failed; don't add an undo operation
    top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
    cursor-row:num <- get *editor, cursor-row:offset
    cursor-column:num <- get *editor, cursor-row:offset
    before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
    undo:&:list:&:operation <- get *editor, undo:offset
    {
      # if previous operation was an insert, coalesce this operation with it
      break-unless undo
      op:&:operation <- first undo
      deletion:delete-operation, is-delete?:bool <- maybe-convert *op, delete:variant
      break-unless is-delete?
      previous-coalesce-tag:num <- get deletion, tag:offset
      coalesce?:bool <- equal previous-coalesce-tag, 1/coalesce-backspace
      break-unless coalesce?
      deletion <- put deletion, delete-from:offset, before-cursor
      backspaced-so-far:&:duplex-list:char <- get deletion, deleted-text:offset
      splice backspaced-cell, backspaced-so-far
      deletion <- put deletion, deleted-text:offset, backspaced-cell
      deletion <- put deletion, after-row:offset, cursor-row
      deletion <- put deletion, after-column:offset, cursor-column
      deletion <- put deletion, after-top-of-screen:offset, top-after
      *op <- merge 2/delete-operation, deletion
      break +done-adding-backspace-operation
    }
    # if not, create a new operation
    op:&:operation <- new operation:type
    deleted-until:&:duplex-list:char <- next before-cursor
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, backspaced-cell/deleted, before-cursor/delete-from, deleted-until, 1/coalesce-backspace
    editor <- add-operation editor, op
    +done-adding-backspace-operation
  }
]

after <handle-undo> [
  {
    deletion:delete-operation, is-delete?:bool <- maybe-convert *op, delete:variant
    break-unless is-delete?
    anchor:&:duplex-list:char <- get deletion, delete-from:offset
    break-unless anchor
    deleted:&:duplex-list:char <- get deletion, deleted-text:offset
    old-cursor:&:duplex-list:char <- last deleted
    splice anchor, deleted
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    before-cursor <- copy old-cursor
    cursor-row <- get deletion, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get deletion, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get deletion, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

after <handle-redo> [
  {
    deletion:delete-operation, is-delete?:bool <- maybe-convert *op, delete:variant
    break-unless is-delete?
    start:&:duplex-list:char <- get deletion, delete-from:offset
    end:&:duplex-list:char <- get deletion, delete-until:offset
    data:&:duplex-list:char <- get *editor, data:offset
    remove-between start, end
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get deletion, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get deletion, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:&:duplex-list:char <- get deletion, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

# undo delete

scenario editor-can-undo-and-redo-delete [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  # insert some text and hit delete and backspace a few times
  assume-console [
    type [abcdef]
    left-click 1, 2
    press delete
    press backspace
    press delete
    press delete
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .af        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo deletes
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  screen-should-contain [
    .          .
    .adef      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # undo backspace
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  screen-should-contain [
    .          .
    .abdef     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # undo first delete
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen, console, e
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  screen-should-contain [
    .          .
    .abcdef    .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo first delete
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  screen-should-contain [
    .          .
    .abdef     .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo backspace
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  screen-should-contain [
    .          .
    .adef      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # redo deletes
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  screen-should-contain [
    .          .
    .af        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <begin-delete-character> [
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
]
before <end-delete-character> [
  {
    break-unless deleted-cell  # delete failed; don't add an undo operation
    top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
    cursor-row:num <- get *editor, cursor-row:offset
    cursor-column:num <- get *editor, cursor-column:offset
    before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
    undo:&:list:&:operation <- get *editor, undo:offset
    {
      # if previous operation was an insert, coalesce this operation with it
      break-unless undo
      op:&:operation <- first undo
      deletion:delete-operation, is-delete?:bool <- maybe-convert *op, delete:variant
      break-unless is-delete?
      previous-coalesce-tag:num <- get deletion, tag:offset
      coalesce?:bool <- equal previous-coalesce-tag, 2/coalesce-delete
      break-unless coalesce?
      delete-until:&:duplex-list:char <- next before-cursor
      deletion <- put deletion, delete-until:offset, delete-until
      deleted-so-far:&:duplex-list:char <- get deletion, deleted-text:offset
      deleted-so-far <- append deleted-so-far, deleted-cell
      deletion <- put deletion, deleted-text:offset, deleted-so-far
      deletion <- put deletion, after-row:offset, cursor-row
      deletion <- put deletion, after-column:offset, cursor-column
      deletion <- put deletion, after-top-of-screen:offset, top-after
      *op <- merge 2/delete-operation, deletion
      break +done-adding-delete-operation
    }
    # if not, create a new operation
    op:&:operation <- new operation:type
    deleted-until:&:duplex-list:char <- next before-cursor
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cell/deleted, before-cursor/delete-from, deleted-until, 2/coalesce-delete
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

# undo ctrl-k

scenario editor-can-undo-and-redo-ctrl-k [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # insert some text and hit delete and backspace a few times
  assume-console [
    left-click 1, 1
    press ctrl-k
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .a         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
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
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  screen-should-contain [
    .          .
    .a         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .a1        .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <begin-delete-to-end-of-line> [
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
]
before <end-delete-to-end-of-line> [
  {
    break-unless deleted-cells  # delete failed; don't add an undo operation
    top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
    cursor-row:num <- get *editor, cursor-row:offset
    cursor-column:num <- get *editor, cursor-column:offset
    deleted-until:&:duplex-list:char <- next before-cursor
    op:&:operation <- new operation:type
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cells/deleted, before-cursor/delete-from, deleted-until, 0/never-coalesce
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

# undo ctrl-u

scenario editor-can-undo-and-redo-ctrl-u [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  contents:text <- new [abc
def]
  e:&:editor <- new-editor contents, 0/left, 10/right
  editor-render screen, e
  # insert some text and hit delete and backspace a few times
  assume-console [
    left-click 1, 2
    press ctrl-u
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .c         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # undo
  assume-console [
    press ctrl-z
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
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen, console, e
  ]
  # first line inserted
  screen-should-contain [
    .          .
    .c         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:num/raw <- get *e, cursor-row:offset
  4:num/raw <- get *e, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen, console, e
  ]
  screen-should-contain [
    .          .
    .1c        .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <begin-delete-to-start-of-line> [
  top-before:&:duplex-list:char <- get *editor, top-of-screen:offset
]
before <end-delete-to-start-of-line> [
  {
    break-unless deleted-cells  # delete failed; don't add an undo operation
    top-after:&:duplex-list:char <- get *editor, top-of-screen:offset
    op:&:operation <- new operation:type
    before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
    deleted-until:&:duplex-list:char <- next before-cursor
    cursor-row:num <- get *editor, cursor-row:offset
    cursor-column:num <- get *editor, cursor-column:offset
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cells/deleted, before-cursor/delete-from, deleted-until, 0/never-coalesce
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

scenario editor-can-undo-and-redo-ctrl-u-2 [
  local-scope
  # create an editor
  assume-screen 10/width, 5/height
  e:&:editor <- new-editor [], 0/left, 10/right
  editor-render screen, e
  # insert some text and hit delete and backspace a few times
  assume-console [
    type [abc]
    press ctrl-u
    press ctrl-z
  ]
  editor-event-loop screen, console, e
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]
