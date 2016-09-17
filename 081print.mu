# Wrappers around print primitives that take a 'screen' object and are thus
# easier to test.

container screen [
  num-rows:num
  num-columns:num
  cursor-row:num
  cursor-column:num
  data:&:array:screen-cell
]

container screen-cell [
  contents:char
  color:num
]

def new-fake-screen w:num, h:num -> result:&:screen [
  local-scope
  load-ingredients
  result <- new screen:type
  bufsize:num <- multiply w, h
  data:&:array:screen-cell <- new screen-cell:type, bufsize
  *result <- merge h/num-rows, w/num-columns, 0/cursor-row, 0/cursor-column, data
  result <- clear-screen result
]

def clear-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists
  {
    break-unless screen
    # clear fake screen
    buf:&:array:screen-cell <- get *screen, data:offset
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
    return
  }
  # otherwise, real screen
  clear-display
]

def sync-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  {
    break-if screen
    sync-display
  }
  # do nothing for fake screens
]

def fake-screen-is-empty? screen:&:screen -> result:bool [
  local-scope
  load-ingredients
  return-unless screen, 1/true
  buf:&:array:screen-cell <- get *screen, data:offset
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
    return 0/false
  }
  return 1/true
]

def print screen:&:screen, c:char -> screen:&:screen [
  local-scope
  load-ingredients
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  c2:num <- character-to-code c
  trace 90, [print-character], c2
  {
    # if x exists
    # (handle special cases exactly like in the real screen)
    break-unless screen
    width:num <- get *screen, num-columns:offset
    height:num <- get *screen, num-rows:offset
    # if cursor is out of bounds, silently exit
    row:num <- get *screen, cursor-row:offset
    legal?:bool <- greater-or-equal row, 0
    return-unless legal?
    legal? <- lesser-than row, height
    return-unless legal?
    column:num <- get *screen, cursor-column:offset
    legal? <- greater-or-equal column, 0
    return-unless legal?
    legal? <- lesser-than column, width
    return-unless legal?
#?     $print [print-character (], row, [, ], column, [): ], c, 10/newline
    # special-case: newline
    {
      newline?:bool <- equal c, 10/newline
      break-unless newline?
      {
        # unless cursor is already at bottom
        bottom:num <- subtract height, 1
        at-bottom?:bool <- greater-or-equal row, bottom
        break-if at-bottom?
        # move it to the next row
        column <- copy 0
        *screen <- put *screen, cursor-column:offset, column
        row <- add row, 1
        *screen <- put *screen, cursor-row:offset, row
      }
      return
    }
    # save character in fake screen
    index:num <- multiply row, width
    index <- add index, column
    buf:&:array:screen-cell <- get *screen, data:offset
    len:num <- length *buf
    # special-case: backspace
    {
      backspace?:bool <- equal c, 8
      break-unless backspace?
      {
        # unless cursor is already at left margin
        at-left?:bool <- lesser-or-equal column, 0
        break-if at-left?
        # clear previous location
        column <- subtract column, 1
        *screen <- put *screen, cursor-column:offset, column
        index <- subtract index, 1
        cursor:screen-cell <- merge 32/space, 7/white
        *buf <- put-index *buf, index, cursor
      }
      return
    }
    cursor:screen-cell <- merge c, color
    *buf <- put-index *buf, index, cursor
    # increment column unless it's already all the way to the right
    {
      right:num <- subtract width, 1
      at-right?:bool <- greater-or-equal column, right
      break-if at-right?
      column <- add column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # otherwise, real screen
  print-character-to-display c, color, bg-color
]

scenario print-character-at-top-left [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a:char
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    1:array:screen-cell/raw <- copy *cell
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
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a:char, 1/red
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    1:array:screen-cell/raw <- copy *cell
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
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    backspace:char <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    10:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    11:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 0  # cursor column
    11 <- 6  # width*height
    12 <- 32  # space, not 'a'
    13 <- 7  # white
    # rest of screen is empty
    14 <- 0
  ]
]

scenario print-extra-backspace-character [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    backspace:char <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    fake-screen <- print fake-screen, backspace
    1:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    3:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    1 <- 0  # cursor column
    3 <- 6  # width*height
    4 <- 32  # space, not 'a'
    5 <- 7  # white
    # rest of screen is empty
    6 <- 0
  ]
]

scenario print-character-at-right-margin [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 2/width, 2/height
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    b:char <- copy 98/b
    fake-screen <- print fake-screen, b
    c:char <- copy 99/c
    fake-screen <- print fake-screen, c
    10:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    11:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 1  # cursor column
    11 <- 4  # width*height
    12 <- 97  # 'a'
    13 <- 7  # white
    14 <- 99  # 'c' over 'b'
    15 <- 7  # white
    # rest of screen is empty
    16 <- 0
  ]
]

scenario print-newline-character [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    newline:char <- copy 10/newline
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    fake-screen <- print fake-screen, newline
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    12:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 0  # cursor column
    12 <- 6  # width*height
    13 <- 97  # 'a'
    14 <- 7  # white
    # rest of screen is empty
    15 <- 0
  ]
]

scenario print-newline-at-bottom-line [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    newline:char <- copy 10/newline
    fake-screen <- print fake-screen, newline
    fake-screen <- print fake-screen, newline
    fake-screen <- print fake-screen, newline
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 0  # cursor column
  ]
]

scenario print-character-at-bottom-right [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 2/width, 2/height
    newline:char <- copy 10/newline
    fake-screen <- print fake-screen, newline
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    b:char <- copy 98/b
    fake-screen <- print fake-screen, b
    c:char <- copy 99/c
    fake-screen <- print fake-screen, c
    fake-screen <- print fake-screen, newline
    d:char <- copy 100/d
    fake-screen <- print fake-screen, d
    10:num/raw <- get *fake-screen, cursor-row:offset
    11:num/raw <- get *fake-screen, cursor-column:offset
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    20:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 1  # cursor column
    20 <- 4  # width*height
    21 <- 0  # unused
    22 <- 7  # white
    23 <- 0  # unused
    24 <- 7  # white
    25 <- 97 # 'a'
    26 <- 7  # white
    27 <- 100  # 'd' over 'b' and 'c' and newline
    28 <- 7  # white
    # rest of screen is empty
    29 <- 0
  ]
]

def clear-line screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  space:char <- copy 0/nul
  # if x exists, clear line in fake screen
  {
    break-unless screen
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
    return
  }
  # otherwise, real screen
  clear-line-on-display
]

def clear-line-until screen:&:screen, right:num/inclusive -> screen:&:screen [
  local-scope
  load-ingredients
  _, column:num <- cursor-position screen
  space:char <- copy 32/space
  bg-color:num, bg-color-found?:bool <- next-ingredient
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
  load-ingredients
  # if x exists, lookup cursor in fake screen
  {
    break-unless screen
    row:num <- get *screen, cursor-row:offset
    column:num <- get *screen, cursor-column:offset
    return
  }
  row, column <- cursor-position-on-display
]

def move-cursor screen:&:screen, new-row:num, new-column:num -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    *screen <- put *screen, cursor-row:offset, new-row
    *screen <- put *screen, cursor-column:offset, new-column
    return
  }
  # otherwise, real screen
  move-cursor-on-display new-row, new-column
]

scenario clear-line-erases-printed-characters [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    # print a character
    a:char <- copy 97/a
    fake-screen <- print fake-screen, a
    # move cursor to start of line
    fake-screen <- move-cursor fake-screen, 0/row, 0/column
    # clear line
    fake-screen <- clear-line fake-screen
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    10:array:screen-cell/raw <- copy *cell
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
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment row unless it's already all the way down
      height:num <- get *screen, num-rows:offset
      row:num <- get *screen, cursor-row:offset
      max:num <- subtract height, 1
      at-bottom?:bool <- greater-or-equal row, max
      break-if at-bottom?
      row <- add row, 1
      *screen <- put *screen, cursor-row:offset, row
    }
    return
  }
  # otherwise, real screen
  move-cursor-down-on-display
]

def cursor-up screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement row unless it's already all the way up
      row:num <- get *screen, cursor-row:offset
      at-top?:bool <- lesser-or-equal row, 0
      break-if at-top?
      row <- subtract row, 1
      *screen <- put *screen, cursor-row:offset, row
    }
    return
  }
  # otherwise, real screen
  move-cursor-up-on-display
]

def cursor-right screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment column unless it's already all the way to the right
      width:num <- get *screen, num-columns:offset
      column:num <- get *screen, cursor-column:offset
      max:num <- subtract width, 1
      at-bottom?:bool <- greater-or-equal column, max
      break-if at-bottom?
      column <- add column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # otherwise, real screen
  move-cursor-right-on-display
]

def cursor-left screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement column unless it's already all the way to the left
      column:num <- get *screen, cursor-column:offset
      at-top?:bool <- lesser-or-equal column, 0
      break-if at-top?
      column <- subtract column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # otherwise, real screen
  move-cursor-left-on-display
]

def cursor-to-start-of-line screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  row:num <- cursor-position screen
  column:num <- copy 0
  screen <- move-cursor screen, row, column
]

def cursor-to-next-line screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
]

def move-cursor-to-column screen:&:screen, column:num -> screen:&:screen [
  local-scope
  load-ingredients
  row:num, _ <- cursor-position screen
  move-cursor screen, row, column
]

def screen-width screen:&:screen -> width:num [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    width <- get *screen, num-columns:offset
    return
  }
  # otherwise, real screen
  width <- display-width
]

def screen-height screen:&:screen -> height:num [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    height <- get *screen, num-rows:offset
    return
  }
  # otherwise, real screen
  height <- display-height
]

def hide-cursor screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  {
    break-unless screen
    return
  }
  # otherwise, real screen
  hide-cursor-on-display
]

def show-cursor screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  {
    break-unless screen
    return
  }
  # otherwise, real screen
  show-cursor-on-display
]

def hide-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    return
  }
  # otherwise, real screen
  hide-display
]

def show-screen screen:&:screen -> screen:&:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    return
  }
  # otherwise, real screen
  show-display
]

def print screen:&:screen, s:text -> screen:&:screen [
  local-scope
  load-ingredients
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
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

scenario print-text-stops-at-right-margin [
  run [
    local-scope
    fake-screen:&:screen <- new-fake-screen 3/width, 2/height
    s:text <- new [abcd]
    fake-screen <- print fake-screen, s:text
    cell:&:array:screen-cell <- get *fake-screen, data:offset
    10:array:screen-cell/raw <- copy *cell
  ]
  memory-should-contain [
    10 <- 6  # width*height
    11 <- 97  # 'a'
    12 <- 7  # white
    13 <- 98  # 'b'
    14 <- 7  # white
    15 <- 100  # 'd' overwrites 'c'
    16 <- 7  # white
    # rest of screen is empty
    17 <- 0
  ]
]

def print-integer screen:&:screen, n:num -> screen:&:screen [
  local-scope
  load-ingredients
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  # todo: other bases besides decimal
  s:text <- to-text n
  screen <- print screen, s, color, bg-color
]

# for now, we can only print integers
def print screen:&:screen, n:num -> screen:&:screen [
  local-scope
  load-ingredients
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  screen <- print-integer screen, n, color, bg-color
]

# addresses
def print screen:&:screen, n:&:_elem -> screen:&:screen [
  local-scope
  load-ingredients
  color:num, color-found?:bool <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:num, bg-color-found?:bool <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  n2:num <- copy n
  screen <- print-integer screen, n2, color, bg-color
]
