# Wrappers around print primitives that take a 'screen' object and are thus
# easier to test.
#
# Screen objects are intended to exactly mimic the behavior of traditional
# terminals. Moving a cursor too far right wraps it to the next line,
# scrolling if necessary. The details are subtle:
#
# a) Rows can take unbounded values. When printing, large values for the row
# saturate to the bottom row (because scrolling).
#
# b) If you print to a square (row, right) on the right margin, the cursor
# position depends on whether 'row' is in range. If it is, the new cursor
# position is (row+1, 0). If it isn't, the new cursor position is (row, 0).
# Because scrolling.

container screen [
  num-rows:num
  num-columns:num
  cursor-row:num
  cursor-column:num
  data:&:@:screen-cell  # capacity num-rows*num-columns
  pending-scroll?:bool
  top-idx:num  # index inside data that corresponds to top-left of screen
               # modified on scroll, wrapping around to the top of data
]

container screen-cell [
  contents:char
  color:num
]

def new-fake-screen w:num, h:num -> result:&:screen [
  local-scope
  load-inputs
  result <- new screen:type
  non-zero-width?:bool <- greater-than w, 0
  assert non-zero-width?, [screen can't have zero width]
  non-zero-height?:bool <- greater-than h, 0
  assert non-zero-height?, [screen can't have zero height]
  bufsize:num <- multiply w, h
  data:&:@:screen-cell <- new screen-cell:type, bufsize
  *result <- merge h/num-rows, w/num-columns, 0/cursor-row, 0/cursor-column, data, false/pending-scroll?, 0/top-idx
  result <- clear-screen result
]

def clear-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [clear-screen]
  {
    break-if screen
    # real screen
    clear-display
    return
  }
  # fake screen
  buf:&:@:screen-cell <- get *screen, data:offset
  max:num <- length *buf
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, max
    break-if done?
    curr:screen-cell <- merge 0/empty, 7/white
    *buf <- put-index *buf, i, curr
    i <- add i, 1
    loop
  }
  # reset cursor
  *screen <- put *screen, cursor-row:offset, 0
  *screen <- put *screen, cursor-column:offset, 0
  *screen <- put *screen, top-idx:offset, 0
]

def fake-screen-is-empty? screen:&:screen -> result:bool [
  local-scope
  load-inputs
#?   stash [fake-screen-is-empty?]
  return-unless screen, true  # do nothing for real screens
  buf:&:@:screen-cell <- get *screen, data:offset
  i:num <- copy 0
  len:num <- length *buf
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    curr:screen-cell <- index *buf, i
    curr-contents:char <- get curr, contents:offset
    i <- add i, 1
    loop-unless curr-contents
    # not 0
    return false
  }
  return true
]

def print screen:&:screen, c:char -> screen:&:screen [
  local-scope
  load-inputs
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  c2:num <- character-to-code c
  trace 90, [print-character], c2
  {
    # real screen
    break-if screen
    print-character-to-display c, color, bg-color
    return
  }
  # fake screen
  # (handle special cases exactly like in the real screen)
  width:num <- get *screen, num-columns:offset
  height:num <- get *screen, num-rows:offset
  capacity:num <- multiply width, height
  row:num <- get *screen, cursor-row:offset
  column:num <- get *screen, cursor-column:offset
  buf:&:@:screen-cell <- get *screen, data:offset
  # some potentially slow sanity checks for preconditions {
  # eliminate fractions from column and row
  row <- round row
  column <- round column
  # if cursor is past left margin (error), reset to left margin
  {
    too-far-left?:bool <- lesser-than column, 0
    break-unless too-far-left?
    column <- copy 0
    *screen <- put *screen, cursor-column:offset, column
  }
  # if cursor is at or past right margin, wrap
  {
    at-right?:bool <- greater-or-equal column, width
    break-unless at-right?
    column <- copy 0
    *screen <- put *screen, cursor-column:offset, column
    row <- add row, 1
    *screen <- put *screen, cursor-row:offset, row
  }
  # }
  # if there's a pending scroll, perform it
  {
    pending-scroll?:bool <- get *screen, pending-scroll?:offset
    break-unless pending-scroll?
#?     stash [scroll]
    scroll-fake-screen screen
    *screen <- put *screen, pending-scroll?:offset, false
  }
#?     $print [print-character (], row, [, ], column, [): ], c, 10/newline
  # special-case: newline
  {
    newline?:bool <- equal c, 10/newline
    break-unless newline?
    cursor-down-on-fake-screen screen  # doesn't modify column
    return
  }
  # special-case: linefeed
  {
    linefeed?:bool <- equal c, 13/linefeed
    break-unless linefeed?
    *screen <- put *screen, cursor-column:offset, 0
    return
  }
  # special-case: backspace
  # moves cursor left but does not erase
  {
    backspace?:bool <- equal c, 8/backspace
    break-unless backspace?
    {
      break-unless column
      column <- subtract column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # save character in fake screen
  top-idx:num <- get *screen, top-idx:offset
  index:num <- data-index row, column, width, height, top-idx
  cursor:screen-cell <- merge c, color
  *buf <- put-index *buf, index, cursor
  # move cursor to next character, wrapping as necessary
  # however, don't scroll just yet
  column <- add column, 1
  {
    past-right?:bool <- greater-or-equal column, width
    break-unless past-right?
    column <- copy 0
    row <- add row, 1
    past-bottom?:bool <- greater-or-equal row, height
    break-unless past-bottom?
    # queue up a scroll
#?     stash [pending scroll]
    *screen <- put *screen, pending-scroll?:offset, true
    row <- subtract row, 1  # update cursor as if scroll already happened
  }
  *screen <- put *screen, cursor-row:offset, row
  *screen <- put *screen, cursor-column:offset, column
]

def cursor-down-on-fake-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-down]
  row:num <- get *screen, cursor-row:offset
  height:num <- get *screen, num-rows:offset
  bottom:num <- subtract height, 1
  at-bottom?:bool <- greater-or-equal row, bottom
  {
    break-if at-bottom?
    row <- add row, 1
    *screen <- put *screen, cursor-row:offset, row
  }
  {
    break-unless at-bottom?
    scroll-fake-screen screen  # does not modify row
  }
]

def scroll-fake-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [scroll-fake-screen]
  width:num <- get *screen, num-columns:offset
  height:num <- get *screen, num-rows:offset
  buf:&:@:screen-cell <- get *screen, data:offset
  # clear top line and 'rotate' it to the bottom
  top-idx:num <- get *screen, top-idx:offset  # 0 <= top-idx < len(buf)
  next-top-idx:num <- add top-idx, width  # 0 <= next-top-idx <= len(buf)
  empty-cell:screen-cell <- merge 0/empty, 7/white
  {
    done?:bool <- greater-or-equal top-idx, next-top-idx
    break-if done?
    put-index *buf, top-idx, empty-cell
    top-idx <- add top-idx, 1
    # no modulo; top-idx is always a multiple of width,
    # so it can never wrap around inside this loop
    loop
  }
  # top-idx now same as next-top-idx; wrap around if necessary
  capacity:num <- multiply width, height
  _, top-idx <- divide-with-remainder, top-idx, capacity
  *screen <- put *screen, top-idx:offset, top-idx
]

# translate from screen (row, column) coordinates to an index into data
# while accounting for scrolling (sliding top-idx)
def data-index row:num, column:num, width:num, height:num, top-idx:num -> result:num [
  local-scope
  load-inputs
  {
    overflow?:bool <- greater-or-equal row, height
    break-unless overflow?
    row <- subtract height, 1
  }
  result <- multiply width, row
  result <- add result, column, top-idx
  capacity:num <- multiply width, height
  _, result <- divide-with-remainder result, capacity
]

scenario print-character-at-top-left [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  run [
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a:char
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    1:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    1 <- 6  # width*height
    2 <- 97  # 'a'
    3 <- 7  # white
    # rest of screen is empty
    4 <- 0
  ]
]

scenario print-character-at-fractional-coordinate [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  a:char <- copy 97/a
  run [
    move-cursor fake-screen, 0.5, 0
    fake-screen <- print fake-screen, a:char
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    1:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    1 <- 6  # width*height
    2 <- 97  # 'a'
    3 <- 7  # white
    # rest of screen is empty
    4 <- 0
  ]
]

scenario print-character-in-color [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  run [
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a:char, 1/red
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    1:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    1 <- 6  # width*height
    2 <- 97  # 'a'
    3 <- 1  # red
    # rest of screen is empty
    4 <- 0
  ]
]

scenario print-backspace-character [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  run [
    backspace:char <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    10:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    11:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 0  # cursor column
    11 <- 6  # width*height
    12 <- 97  # still 'a'
    13 <- 7  # white
    # rest of screen is empty
    14 <- 0
  ]
]

scenario print-extra-backspace-character [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  run [
    backspace:char <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    fake-screen <- print fake-screen, backspace  # cursor already at left margin
    1:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    3:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    1 <- 0  # cursor column
    3 <- 6  # width*height
    4 <- 97  # still 'a'
    5 <- 7  # white
    # rest of screen is empty
    6 <- 0
  ]
]

scenario print-character-at-right-margin [
  # fill top row of screen with text
  local-scope
  fake-screen:&:screen <- new-fake-screen 2/width, 2/height
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  b:char <- copy 98/b
  fake-screen <- print fake-screen, b
  run [
    # cursor now at next row
    c:char <- copy 99/c
    fake-screen <- print fake-screen, c
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    12:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 1  # cursor column
    12 <- 4  # width*height
    13 <- 97  # 'a'
    14 <- 7  # white
    15 <- 98  # 'b'
    16 <- 7  # white
    17 <- 99  # 'c'
    18 <- 7  # white
    19 <- 0  # ' '
    20 <- 7  # white
  ]
]

scenario print-newline-character [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  run [
    newline:char <- copy 10/newline
    fake-screen <- print fake-screen, newline
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    12:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 1  # cursor column
    12 <- 6  # width*height
    13 <- 97  # 'a'
    14 <- 7  # white
    # rest of screen is empty
    15 <- 0
  ]
]

scenario print-newline-at-bottom-line [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  newline:char <- copy 10/newline
  fake-screen <- print fake-screen, newline
  fake-screen <- print fake-screen, newline
  run [
    # cursor now at bottom of screen
    fake-screen <- print fake-screen, newline
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
  ]
  # doesn't move further down
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 0  # cursor column
  ]
]

scenario print-character-at-bottom-right [
  local-scope
  fake-screen:&:screen <- new-fake-screen 2/width, 2/height
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  b:char <- copy 98/b
  fake-screen <- print fake-screen, b
  c:char <- copy 99/c
  fake-screen <- print fake-screen, c
  run [
    # cursor now at bottom right
    d:char <- copy 100/d
    fake-screen <- print fake-screen, d
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    12:num/raw <- get *fake-screen, top-idx:offset
    13:bool/raw <- get *fake-screen, pending-scroll?:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    20:@:screen-cell/raw <- copy *cell
  ]
  # cursor column wraps but the screen doesn't scroll yet
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 0  # cursor column -- outside screen
    12 <- 0  # top-idx -- not yet scrolled
    13 <- 1  # pending-scroll?
    20 <- 4  # screen size (width*height)
    21 <- 97  # 'a'
    22 <- 7  # white
    23 <- 98  # 'b'
    24 <- 7  # white
    25 <- 99 # 'c'
    26 <- 7  # white
    27 <- 100  # 'd'
    28 <- 7  # white
  ]
  run [
    e:char <- copy 101/e
    print fake-screen, e
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    12:num/raw <- get *fake-screen, top-idx:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    20:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    # text scrolls by 1, we lose the top line
    10 <- 1  # cursor row
    11 <- 1  # cursor column -- wrapped
    12 <- 2  # top-idx -- scrolled
    20 <- 4  # screen size (width*height)
    # screen now checked in rotated order
    25 <- 99 # 'c'
    26 <- 7  # white
    27 <- 100  # 'd'
    28 <- 7  # white
    # screen wraps; bottom line is cleared of old contents
    21 <- 101  # 'e'
    22 <- 7  # white
    23 <- 0  # unused
    24 <- 7  # white
  ]
]

# even though our screen supports scrolling, some apps may want to avoid
# scrolling
# these helpers help check for scrolling at development time
def save-top-idx screen:&:screen -> result:num [
  local-scope
  load-inputs
  return-unless screen, 0  # check is only for fake screens
  result <- get *screen, top-idx:offset
]
def assert-no-scroll screen:&:screen, old-top-idx:num [
  local-scope
  load-inputs
  return-unless screen
  new-top-idx:num <- get *screen, top-idx:offset
  no-scroll?:bool <- equal old-top-idx, new-top-idx
  assert no-scroll?, [render should never use screen's scrolling capabilities]
]

def clear-line screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [clear-line]
  space:char <- copy 0/nul
  {
    break-if screen
    # real screen
    clear-line-on-display
    return
  }
  # fake screen
  width:num <- get *screen, num-columns:offset
  column:num <- get *screen, cursor-column:offset
  original-column:num <- copy column
  # space over the entire line
  {
    right:num <- subtract width, 1
    done?:bool <- greater-or-equal column, right
    break-if done?
    print screen, space
    column <- add column, 1
    loop
  }
  # now back to where the cursor was
  *screen <- put *screen, cursor-column:offset, original-column
]

# only for non-scrolling apps
def clear-line-until screen:&:screen, right:num/inclusive -> screen:&:screen [
  local-scope
  load-inputs
  row:num, column:num <- cursor-position screen
#?   stash [clear-line-until] row column
  height:num <- screen-height screen
  past-bottom?:bool <- greater-or-equal row, height
  return-if past-bottom?
  space:char <- copy 32/space
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  {
    done?:bool <- greater-than column, right
    break-if done?
    screen <- print screen, space, 7/white, bg-color  # foreground color is mostly unused except if the cursor shows up at this cell
    column <- add column, 1
    loop
  }
]

def cursor-position screen:&:screen -> row:num, column:num [
  local-scope
  load-inputs
  {
    break-if screen
    # real screen
    row, column <- cursor-position-on-display
    return
  }
  # fake screen
  row:num <- get *screen, cursor-row:offset
  column:num <- get *screen, cursor-column:offset
]

def move-cursor screen:&:screen, new-row:num, new-column:num -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [move-cursor] new-row new-column
  {
    break-if screen
    # real screen
    move-cursor-on-display new-row, new-column
    return
  }
  # fake screen
  *screen <- put *screen, cursor-row:offset, new-row
  *screen <- put *screen, cursor-column:offset, new-column
  # if cursor column is within bounds, reset 'pending-scroll?'
  {
    width:num <- get *screen, num-columns:offset
    scroll?:bool <- greater-or-equal new-column, width
    break-if scroll?
#?     stash [resetting pending-scroll?]
    *screen <- put *screen, pending-scroll?:offset, false
  }
]

scenario clear-line-erases-printed-characters [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  # print a character
  a:char <- copy 97/a
  fake-screen <- print fake-screen, a
  # move cursor to start of line
  fake-screen <- move-cursor fake-screen, 0/row, 0/column
  run [
    fake-screen <- clear-line fake-screen
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    10:@:screen-cell/raw <- copy *cell
  ]
  # screen should be blank
  memory-should-contain [
    10 <- 6  # width*height
    11 <- 0
    12 <- 7
    13 <- 0
    14 <- 7
    15 <- 0
    16 <- 7
    17 <- 0
    18 <- 7
    19 <- 0
    20 <- 7
    21 <- 0
    22 <- 7
  ]
]

def cursor-down screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-down]
  {
    break-if screen
    # real screen
    move-cursor-down-on-display
    return
  }
  # fake screen
  cursor-down-on-fake-screen screen
]

scenario cursor-down-scrolls [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  # print something to screen and scroll
  run [
    print fake-screen, [abc]
    cursor-to-next-line fake-screen
    cursor-to-next-line fake-screen
    data:&:@:screen-cell <- get *fake-screen, data:offset
    10:@:screen-cell/raw <- copy *data
  ]
  # screen is now blank
  memory-should-contain [
    10 <- 6  # width*height
    11 <- 0
    12 <- 7  # white
    13 <- 0
    14 <- 7  # white
    15 <- 0
    16 <- 7  # white
    17 <- 0
    18 <- 7  # white
    19 <- 0
    20 <- 7  # white
    21 <- 0
    22 <- 7  # white
  ]
]

def cursor-up screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-up]
  {
    break-if screen
    # real screen
    move-cursor-up-on-display
    return
  }
  # fake screen
  row:num <- get *screen, cursor-row:offset
  at-top?:bool <- lesser-or-equal row, 0
  return-if at-top?
  row <- subtract row, 1
  *screen <- put *screen, cursor-row:offset, row
]

def cursor-right screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-right]
  {
    break-if screen
    # real screen
    move-cursor-right-on-display
    return
  }
  # fake screen
  width:num <- get *screen, num-columns:offset
  column:num <- get *screen, cursor-column:offset
  max:num <- subtract width, 1
  at-bottom?:bool <- greater-or-equal column, max
  return-if at-bottom?
  column <- add column, 1
  *screen <- put *screen, cursor-column:offset, column
]

def cursor-left screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-left]
  {
    break-if screen
    # real screen
    move-cursor-left-on-display
    return
  }
  # fake screen
  column:num <- get *screen, cursor-column:offset
  at-top?:bool <- lesser-or-equal column, 0
  return-if at-top?
  column <- subtract column, 1
  *screen <- put *screen, cursor-column:offset, column
]

def cursor-to-start-of-line screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-to-start-of-line]
  row:num <- cursor-position screen
  screen <- move-cursor screen, row, 0/column
]

def cursor-to-next-line screen:&:screen -> screen:&:screen [
  local-scope
  load-inputs
#?   stash [cursor-to-next-line]
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
]

def move-cursor-to-column screen:&:screen, column:num -> screen:&:screen [
  local-scope
  load-inputs
  row:num, _ <- cursor-position screen
#?   stash [move-cursor-to-column] row
  move-cursor screen, row, column
]

def screen-width screen:&:screen -> width:num [
  local-scope
  load-inputs
#?   stash [screen-width]
  {
    break-unless screen
    # fake screen
    width <- get *screen, num-columns:offset
    return
  }
  # real screen
  width <- display-width
]

def screen-height screen:&:screen -> height:num [
  local-scope
  load-inputs
#?   stash [screen-height]
  {
    break-unless screen
    # fake screen
    height <- get *screen, num-rows:offset
    return
  }
  # real screen
  height <- display-height
]

def print screen:&:screen, s:text -> screen:&:screen [
  local-scope
  load-inputs
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  len:num <- length *s
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    c:char <- index *s, i
    print screen, c, color, bg-color
    i <- add i, 1
    loop
  }
]

scenario print-text-wraps-past-right-margin [
  local-scope
  fake-screen:&:screen <- new-fake-screen 3/width, 2/height
  run [
    fake-screen <- print fake-screen, [abcd]
    5:num/raw <- get *fake-screen, cursor-row:offset
    6:num/raw <- get *fake-screen, cursor-column:offset
    7:num/raw <- get *fake-screen, top-idx:offset
    cell:&:@:screen-cell <- get *fake-screen, data:offset
    10:@:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    5 <- 1  # cursor-row
    6 <- 1  # cursor-column
    7 <- 0  # top-idx
    10 <- 6  # width*height
    11 <- 97  # 'a'
    12 <- 7  # white
    13 <- 98  # 'b'
    14 <- 7  # white
    15 <- 99  # 'c'
    16 <- 7  # white
    17 <- 100  # 'd'
    18 <- 7  # white
    # rest of screen is empty
    19 <- 0
  ]
]

def print screen:&:screen, n:num -> screen:&:screen [
  local-scope
  load-inputs
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  # todo: other bases besides decimal
  s:text <- to-text n
  screen <- print screen, s, color, bg-color
]

def print screen:&:screen, n:bool -> screen:&:screen [
  local-scope
  load-inputs
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  {
    break-if n
    screen <- print screen, [false], color, bg-color
  }
  {
    break-unless n
    screen <- print screen, [true], color, bg-color
  }
]

def print screen:&:screen, n:&:_elem -> screen:&:screen [
  local-scope
  load-inputs
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-input
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  n2:num <- deaddress n
  screen <- print screen, n2, color, bg-color
]
