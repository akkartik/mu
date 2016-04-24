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
  before-top-of-screen:address:shared:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:shared:duplex-list:character
  # inserted text is from 'insert-from' until 'insert-until'; list doesn't have to terminate
  insert-from:address:shared:duplex-list:character
  insert-until:address:shared:duplex-list:character
  tag:number  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (enter+indent)
    # 1: regular alphanumeric characters
]

container move-operation [
  before-row:number
  before-column:number
  before-top-of-screen:address:shared:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:shared:duplex-list:character
  tag:number  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (touch events, etc)
    # 1: left arrow
    # 2: right arrow
    # 3: up arrow
    # 4: down arrow
]

container delete-operation [
  before-row:number
  before-column:number
  before-top-of-screen:address:shared:duplex-list:character
  after-row:number
  after-column:number
  after-top-of-screen:address:shared:duplex-list:character
  deleted-text:address:shared:duplex-list:character
  delete-from:address:shared:duplex-list:character
  delete-until:address:shared:duplex-list:character
  tag:number  # event causing this operation; might be used to coalesce runs of similar events
    # 0: no coalesce (ctrl-k, ctrl-u)
    # 1: backspace
    # 2: delete
]

# every editor accumulates a list of operations to undo/redo
container editor-data [
  undo:address:shared:list:address:shared:operation
  redo:address:shared:list:address:shared:operation
]

# ctrl-z - undo operation
after <handle-special-character> [
  {
    undo?:boolean <- equal c, 26/ctrl-z
    break-unless undo?
    undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
    break-unless undo
    op:address:shared:operation <- first undo
    undo <- rest undo
    *editor <- put *editor, undo:offset, undo
    redo:address:shared:list:address:shared:operation <- get *editor, redo:offset
    redo <- push op, redo
    *editor <- put *editor, redo:offset, redo
    <handle-undo>
    return screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# ctrl-y - redo operation
after <handle-special-character> [
  {
    redo?:boolean <- equal c, 25/ctrl-y
    break-unless redo?
    redo:address:shared:list:address:shared:operation <- get *editor, redo:offset
    break-unless redo
    op:address:shared:operation <- first redo
    redo <- rest redo
    *editor <- put *editor, redo:offset, redo
    undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
    undo <- push op, undo
    *editor <- put *editor, undo:offset, undo
    <handle-redo>
    return screen/same-as-ingredient:0, editor/same-as-ingredient:1, 1/go-render
  }
]

# undo typing

scenario editor-can-undo-typing [
  # create an editor and type a character
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [0]
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .1         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

# save operation to undo
after <insert-character-begin> [
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  cursor-before:address:shared:duplex-list:character <- get *editor, before-cursor:offset
]
before <insert-character-end> [
  top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
  {
    # if previous operation was an insert, coalesce this operation with it
    break-unless undo
    op:address:shared:operation <- first undo
    typing:insert-operation, is-insert?:boolean <- maybe-convert *op, typing:variant
    break-unless is-insert?
    previous-coalesce-tag:number <- get typing, tag:offset
    break-unless previous-coalesce-tag
    before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
    insert-until:address:shared:duplex-list:character <- next before-cursor
    typing <- put typing, insert-until:offset, insert-until
    typing <- put typing, after-row:offset, cursor-row
    typing <- put typing, after-column:offset, cursor-column
    typing <- put typing, after-top-of-screen:offset, top-after
    *op <- merge 0/insert-operation, typing
    break +done-adding-insert-operation:label
  }
  # if not, create a new operation
  insert-from:address:shared:duplex-list:character <- next cursor-before
  insert-to:address:shared:duplex-list:character <- next insert-from
  op:address:shared:operation <- new operation:type
  *op <- merge 0/insert-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, insert-from, insert-to, 1/coalesce
  editor <- add-operation editor, op
  +done-adding-insert-operation
]

# enter operations never coalesce with typing before or after
after <insert-enter-begin> [
  cursor-row-before:number <- copy cursor-row
  cursor-column-before:number <- copy cursor-column
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  cursor-before:address:shared:duplex-list:character <- get *editor, before-cursor:offset
]
before <insert-enter-end> [
  top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-row:offset
  # never coalesce
  insert-from:address:shared:duplex-list:character <- next cursor-before
  before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
  insert-to:address:shared:duplex-list:character <- next before-cursor
  op:address:shared:operation <- new operation:type
  *op <- merge 0/insert-operation, cursor-row-before, cursor-column-before, top-before, cursor-row/after, cursor-column/after, top-after, insert-from, insert-to, 0/never-coalesce
  editor <- add-operation editor, op
]

# Everytime you add a new operation to the undo stack, be sure to clear the
# redo stack, because it's now obsolete.
# Beware: since we're counting cursor moves as operations, this means just
# moving the cursor can lose work on the undo stack.
def add-operation editor:address:shared:editor-data, op:address:shared:operation -> editor:address:shared:editor-data [
  local-scope
  load-ingredients
  undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
  undo <- push op undo
  *editor <- put *editor, undo:offset, undo
  redo:address:shared:list:address:shared:operation <- get *editor, redo:offset
  redo <- copy 0
  *editor <- put *editor, redo:offset, redo
  return editor/same-as-ingredient:0
]

after <handle-undo> [
  {
    typing:insert-operation, is-insert?:boolean <- maybe-convert *op, typing:variant
    break-unless is-insert?
    start:address:shared:duplex-list:character <- get typing, insert-from:offset
    end:address:shared:duplex-list:character <- get typing, insert-until:offset
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    before-cursor:address:shared:duplex-list:character <- prev start
    *editor <- put *editor, before-cursor:offset, before-cursor
    remove-between before-cursor, end
    cursor-row <- get typing, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get typing, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get typing, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-can-undo-typing-multiple [
  # create an editor and type multiple characters
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [012]
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  1:address:shared:array:character <- new [a]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # type some characters
  assume-console [
    type [012]
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .3a        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-can-undo-typing-enter [
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [  abc]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # new line
  assume-console [
    left-click 1, 8
    press enter
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .  abc     .
    .          .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  # line is indented
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 2
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [a]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [012]
    press ctrl-z
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    typing:insert-operation, is-insert?:boolean <- maybe-convert *op, typing:variant
    break-unless is-insert?
    before-cursor <- get *editor, before-cursor:offset
    insert-from:address:shared:duplex-list:character <- get typing, insert-from:offset  # ignore insert-to because it's already been spliced away
    # assert insert-to matches next(before-cursor)
    insert-range before-cursor, insert-from
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get typing, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get typing, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get typing, after-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-redo-typing-empty [
  # create an editor, type something, undo
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [012]
    press ctrl-z
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .0123      .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

scenario editor-work-clears-redo-stack [
  # create an editor with some text, do some work, undo
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [1]
    press ctrl-z
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # do some more work
  assume-console [
    type [0]
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
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
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .  ab  cd  .
    .    efg   .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 7
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # typing in second line deleted, but not indent
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # indent and newline deleted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # empty screen
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # newline and indent inserted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # indent and newline deleted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor
  assume-console [
    left-click 3, 1
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .1abc      .
    .def       .
    .ghi       .
    .┈┈┈┈┈┈┈┈┈┈.
  ]
]

after <move-cursor-begin> [
  cursor-row-before:number <- get *editor, cursor-row:offset
  cursor-column-before:number <- get *editor, cursor-column:offset
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
]
before <move-cursor-end> [
  top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
  cursor-row:number <- get *editor, cursor-row:offset
  cursor-column:number <- get *editor, cursor-column:offset
  {
    break-unless undo-coalesce-tag
    # if previous operation was also a move, and also had the same coalesce
    # tag, coalesce with it
    undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
    break-unless undo
    op:address:shared:operation <- first undo
    move:move-operation, is-move?:boolean <- maybe-convert *op, move:variant
    break-unless is-move?
    previous-coalesce-tag:number <- get move, tag:offset
    coalesce?:boolean <- equal undo-coalesce-tag, previous-coalesce-tag
    break-unless coalesce?
    move <- put move, after-row:offset, cursor-row
    move <- put move, after-column:offset, cursor-column
    move <- put move, after-top-of-screen:offset, top-after
    *op <- merge 1/move-operation, move
    break +done-adding-move-operation:label
  }
  op:address:shared:operation <- new operation:type
  *op <- merge 1/move-operation, cursor-row-before, cursor-column-before, top-before, cursor-row/after, cursor-column/after, top-after, undo-coalesce-tag
  editor <- add-operation editor, op
  +done-adding-move-operation
]

after <handle-undo> [
  {
    move:move-operation, is-move?:boolean <- maybe-convert *op, move:variant
    break-unless is-move?
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get move, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get move, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get move, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-can-undo-scroll [
  # screen has 1 line for menu + 3 lines
  assume-screen 5/width, 4/height
  # editor contains a wrapped line
  1:address:shared:array:character <- new [a
b
cdefgh]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 5/right
  # position cursor at end of screen and try to move right
  assume-console [
    left-click 3, 3
    press right-arrow
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .     .
    .b    .
    .cde1↩.
    .fgh  .
  ]
]

scenario editor-can-undo-left-arrow [
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor
  assume-console [
    left-click 3, 1
    press left-arrow
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor
  assume-console [
    left-click 3, 1
    press up-arrow
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 3
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor
  assume-console [
    left-click 2, 1
    press down-arrow
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [a
b
c
d
e
f]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # scroll the page
  assume-console [
    press ctrl-f
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [a
b
c
d
e
f]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # scroll the page
  assume-console [
    press page-down
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [a
b
c
d
e
f]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # scroll the page down and up
  assume-console [
    press page-down
    press ctrl-b
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor with multiple pages of text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [a
b
c
d
e
f]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # scroll the page down and up
  assume-console [
    press page-down
    press page-up
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press ctrl-a
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press home
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press ctrl-e
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor, then to start of line
  assume-console [
    left-click 2, 1
    press end
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # cursor moves back
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
  # create an editor with some text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # move the cursor
  assume-console [
    left-click 2, 1
    press right-arrow
    press right-arrow
    press up-arrow
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 3
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # up-arrow is undone
  memory-should-contain [
    3 <- 2
    4 <- 3
  ]
  # undo again
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
  ]
  # both right-arrows are undone
  memory-should-contain [
    3 <- 2
    4 <- 1
  ]
]

# redo cursor movement and scroll

scenario editor-redo-touch [
  # create an editor with some text, click on a character, undo
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def
ghi]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    left-click 3, 1
    press ctrl-z
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
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
    move:move-operation, is-move?:boolean <- maybe-convert *op, move:variant
    break-unless is-move?
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get move, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get move, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get move, after-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

scenario editor-separates-undo-insert-from-undo-cursor-move [
  # create an editor, type some text, move the cursor, type some more text
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  assume-console [
    type [abc]
    left-click 1, 1
    type [d]
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:number <- get *2:address:shared:editor-data, cursor-row:offset
    4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # insert some text and hit backspace
  assume-console [
    type [abc]
    press backspace
    press backspace
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .a         .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
after <backspace-character-begin> [
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
]
before <backspace-character-end> [
  {
    break-unless backspaced-cell  # backspace failed; don't add an undo operation
    top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
    cursor-row:number <- get *editor, cursor-row:offset
    cursor-column:number <- get *editor, cursor-row:offset
    before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
    undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
    {
      # if previous operation was an insert, coalesce this operation with it
      break-unless *undo
      op:address:shared:operation <- first undo
      deletion:delete-operation, is-delete?:boolean <- maybe-convert *op, delete:variant
      break-unless is-delete?
      previous-coalesce-tag:number <- get deletion, tag:offset
      coalesce?:boolean <- equal previous-coalesce-tag, 1/coalesce-backspace
      break-unless coalesce?
      deletion <- put deletion, delete-from:offset, before-cursor
      backspaced-so-far:address:shared:duplex-list:character <- get deletion, deleted-text:offset
      insert-range backspaced-cell, backspaced-so-far
      deletion <- put deletion, deleted-text:offset, backspaced-cell
      deletion <- put deletion, after-row:offset, cursor-row
      deletion <- put deletion, after-column:offset, cursor-column
      deletion <- put deletion, after-top-of-screen:offset, top-after
      *op <- merge 2/delete-operation, deletion
      break +done-adding-backspace-operation:label
    }
    # if not, create a new operation
    op:address:shared:operation <- new operation:type
    deleted-until:address:shared:duplex-list:character <- next before-cursor
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, backspaced-cell/deleted, before-cursor/delete-from, deleted-until, 1/coalesce-backspace
    editor <- add-operation editor, op
    +done-adding-backspace-operation
  }
]

after <handle-undo> [
  {
    deletion:delete-operation, is-delete?:boolean <- maybe-convert *op, delete:variant
    break-unless is-delete?
    anchor:address:shared:duplex-list:character <- get deletion, delete-from:offset
    break-unless anchor
    deleted:address:shared:duplex-list:character <- get deletion, deleted-text:offset
    old-cursor:address:shared:duplex-list:character <- last deleted
    insert-range anchor, deleted
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    before-cursor <- copy old-cursor
    cursor-row <- get deletion, before-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get deletion, before-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get deletion, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

after <handle-redo> [
  {
    deletion:delete-operation, is-delete?:boolean <- maybe-convert *op, delete:variant
    break-unless is-delete?
    start:address:shared:duplex-list:character <- get deletion, delete-from:offset
    end:address:shared:duplex-list:character <- get deletion, delete-until:offset
    data:address:shared:duplex-list:character <- get *editor, data:offset
    remove-between start, end
    # assert cursor-row/cursor-column/top-of-screen match after-row/after-column/after-top-of-screen
    cursor-row <- get deletion, after-row:offset
    *editor <- put *editor, cursor-row:offset, cursor-row
    cursor-column <- get deletion, after-column:offset
    *editor <- put *editor, cursor-column:offset, cursor-column
    top:address:shared:duplex-list:character <- get deletion, before-top-of-screen:offset
    *editor <- put *editor, top-of-screen:offset, top
  }
]

# undo delete

scenario editor-can-undo-and-redo-delete [
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # insert some text and hit delete and backspace a few times
  assume-console [
    type [abcdef]
    left-click 1, 2
    press delete
    press backspace
    press delete
    press delete
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .af        .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo deletes
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
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

after <delete-character-begin> [
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
]
before <delete-character-end> [
  {
    break-unless deleted-cell  # delete failed; don't add an undo operation
    top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
    cursor-row:number <- get *editor, cursor-row:offset
    cursor-column:number <- get *editor, cursor-column:offset
    before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
    undo:address:shared:list:address:shared:operation <- get *editor, undo:offset
    {
      # if previous operation was an insert, coalesce this operation with it
      break-unless undo
      op:address:shared:operation <- first undo
      deletion:delete-operation, is-delete?:boolean <- maybe-convert *op, delete:variant
      break-unless is-delete?
      previous-coalesce-tag:number <- get deletion, tag:offset
      coalesce?:boolean <- equal previous-coalesce-tag, 2/coalesce-delete
      break-unless coalesce?
      delete-until:address:shared:duplex-list:character <- next before-cursor
      deletion <- put deletion, delete-until:offset, delete-until
      deleted-so-far:address:shared:duplex-list:character <- get deletion, deleted-text:offset
      deleted-so-far <- append deleted-so-far, deleted-cell
      deletion <- put deletion, deleted-text:offset, deleted-so-far
      deletion <- put deletion, after-row:offset, cursor-row
      deletion <- put deletion, after-column:offset, cursor-column
      deletion <- put deletion, after-top-of-screen:offset, top-after
      *op <- merge 2/delete-operation, deletion
      break +done-adding-delete-operation:label
    }
    # if not, create a new operation
    op:address:shared:operation <- new operation:type
    deleted-until:address:shared:duplex-list:character <- next before-cursor
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cell/deleted, before-cursor/delete-from, deleted-until, 2/coalesce-delete
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

# undo ctrl-k

scenario editor-can-undo-and-redo-ctrl-k [
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # insert some text and hit delete and backspace a few times
  assume-console [
    left-click 1, 1
    press ctrl-k
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .a         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  screen-should-contain [
    .          .
    .a         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 1
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .a1        .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <delete-to-end-of-line-begin> [
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
]
before <delete-to-end-of-line-end> [
  {
    break-unless deleted-cells  # delete failed; don't add an undo operation
    top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
    cursor-row:number <- get *editor, cursor-row:offset
    cursor-column:number <- get *editor, cursor-column:offset
    deleted-until:address:shared:duplex-list:character <- next before-cursor
    op:address:shared:operation <- new operation:type
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cells/deleted, before-cursor/delete-from, deleted-until, 0/never-coalesce
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

# undo ctrl-u

scenario editor-can-undo-and-redo-ctrl-u [
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc
def]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # insert some text and hit delete and backspace a few times
  assume-console [
    left-click 1, 2
    press ctrl-u
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .c         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # undo
  assume-console [
    press ctrl-z
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .abc       .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 2
  ]
  # redo
  assume-console [
    press ctrl-y
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  # first line inserted
  screen-should-contain [
    .          .
    .c         .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
  3:number <- get *2:address:shared:editor-data, cursor-row:offset
  4:number <- get *2:address:shared:editor-data, cursor-column:offset
  memory-should-contain [
    3 <- 1
    4 <- 0
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  ]
  screen-should-contain [
    .          .
    .1c        .
    .def       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]

after <delete-to-start-of-line-begin> [
  top-before:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
]
before <delete-to-start-of-line-end> [
  {
    break-unless deleted-cells  # delete failed; don't add an undo operation
    top-after:address:shared:duplex-list:character <- get *editor, top-of-screen:offset
    op:address:shared:operation <- new operation:type
    before-cursor:address:shared:duplex-list:character <- get *editor, before-cursor:offset
    deleted-until:address:shared:duplex-list:character <- next before-cursor
    cursor-row:number <- get *editor, cursor-row:offset
    cursor-column:number <- get *editor, cursor-column:offset
    *op <- merge 2/delete-operation, save-row/before, save-column/before, top-before, cursor-row/after, cursor-column/after, top-after, deleted-cells/deleted, before-cursor/delete-from, deleted-until, 0/never-coalesce
    editor <- add-operation editor, op
    +done-adding-delete-operation
  }
]

scenario editor-can-undo-and-redo-ctrl-u-2 [
  # create an editor
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new []
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  editor-render screen, 2:address:shared:editor-data
  # insert some text and hit delete and backspace a few times
  assume-console [
    type [abc]
    press ctrl-u
    press ctrl-z
  ]
  editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
  screen-should-contain [
    .          .
    .abc       .
    .┈┈┈┈┈┈┈┈┈┈.
    .          .
  ]
]
