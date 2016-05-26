# Wrappers around print primitives that take a 'screen' object and are thus
# easier to test.

container screen [
  num-rows:number
  num-columns:number
  cursor-row:number
  cursor-column:number
  data:address:array:screen-cell
]

container screen-cell [
  contents:character
  color:number
]

def new-fake-screen w:number, h:number -> result:address:screen [
  local-scope
  load-ingredients
  result <- new screen:type
  bufsize:number <- multiply w, h
  data:address:array:screen-cell <- new screen-cell:type, bufsize
  *result <- merge h/num-rows, w/num-columns, 0/cursor-row, 0/cursor-column, data
  result <- clear-screen result
]

def clear-screen screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists
  {
    break-unless screen
    # clear fake screen
    buf:address:array:screen-cell <- get *screen, data:offset
    max:number <- length *buf
    i:number <- copy 0
    {
      done?:boolean <- greater-or-equal i, max
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

def sync-screen screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  {
    break-if screen
    sync-display
  }
  # do nothing for fake screens
]

def fake-screen-is-empty? screen:address:screen -> result:boolean [
  local-scope
  load-ingredients
  return-unless screen, 1/true
  buf:address:array:screen-cell <- get *screen, data:offset
  i:number <- copy 0
  len:number <- length *buf
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    curr:screen-cell <- index *buf, i
    curr-contents:character <- get curr, contents:offset
    i <- add i, 1
    loop-unless curr-contents
    # not 0
    return 0/false
  }
  return 1/true
]

def print screen:address:screen, c:character -> screen:address:screen [
  local-scope
  load-ingredients
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  trace 90, [print-character], c
  {
    # if x exists
    # (handle special cases exactly like in the real screen)
    break-unless screen
    width:number <- get *screen, num-columns:offset
    height:number <- get *screen, num-rows:offset
    # if cursor is out of bounds, silently exit
    row:number <- get *screen, cursor-row:offset
    legal?:boolean <- greater-or-equal row, 0
    return-unless legal?
    legal? <- lesser-than row, height
    return-unless legal?
    column:number <- get *screen, cursor-column:offset
    legal? <- greater-or-equal column, 0
    return-unless legal?
    legal? <- lesser-than column, width
    return-unless legal?
#?     $print [print-character (], row, [, ], column, [): ], c, 10/newline
    # special-case: newline
    {
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      {
        # unless cursor is already at bottom
        bottom:number <- subtract height, 1
        at-bottom?:boolean <- greater-or-equal row, bottom
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
    index:number <- multiply row, width
    index <- add index, column
    buf:address:array:screen-cell <- get *screen, data:offset
    len:number <- length *buf
    # special-case: backspace
    {
      backspace?:boolean <- equal c, 8
      break-unless backspace?
      {
        # unless cursor is already at left margin
        at-left?:boolean <- lesser-or-equal column, 0
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
      right:number <- subtract width, 1
      at-right?:boolean <- greater-or-equal column, right
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a:character
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a:character, 1/red
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    backspace:character <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    10:number/raw <- get *fake-screen, cursor-column:offset
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    backspace:character <- copy 8/backspace
    fake-screen <- print fake-screen, backspace
    fake-screen <- print fake-screen, backspace
    1:number/raw <- get *fake-screen, cursor-column:offset
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 2/width, 2/height
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    b:character <- copy 98/b
    fake-screen <- print fake-screen, b
    c:character <- copy 99/c
    fake-screen <- print fake-screen, c
    10:number/raw <- get *fake-screen, cursor-column:offset
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    newline:character <- copy 10/newline
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    fake-screen <- print fake-screen, newline
    10:number/raw <- get *fake-screen, cursor-row:offset
    11:number/raw <- get *fake-screen, cursor-column:offset
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    newline:character <- copy 10/newline
    fake-screen <- print fake-screen, newline
    fake-screen <- print fake-screen, newline
    fake-screen <- print fake-screen, newline
    10:number/raw <- get *fake-screen, cursor-row:offset
    11:number/raw <- get *fake-screen, cursor-column:offset
  ]
  memory-should-contain [
    10 <- 1  # cursor row
    11 <- 0  # cursor column
  ]
]

scenario print-character-at-bottom-right [
  run [
    local-scope
    fake-screen:address:screen <- new-fake-screen 2/width, 2/height
    newline:character <- copy 10/newline
    fake-screen <- print fake-screen, newline
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    b:character <- copy 98/b
    fake-screen <- print fake-screen, b
    c:character <- copy 99/c
    fake-screen <- print fake-screen, c
    fake-screen <- print fake-screen, newline
    d:character <- copy 100/d
    fake-screen <- print fake-screen, d
    10:number/raw <- get *fake-screen, cursor-row:offset
    11:number/raw <- get *fake-screen, cursor-column:offset
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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

def clear-line screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  space:character <- copy 0/nul
  # if x exists, clear line in fake screen
  {
    break-unless screen
    width:number <- get *screen, num-columns:offset
    column:number <- get *screen, cursor-column:offset
    original-column:number <- copy column
    # space over the entire line
    {
      right:number <- subtract width, 1
      done?:boolean <- greater-or-equal column, right
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

def clear-line-until screen:address:screen, right:number/inclusive -> screen:address:screen [
  local-scope
  load-ingredients
  _, column:number <- cursor-position screen
  space:character <- copy 32/space
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  {
    done?:boolean <- greater-than column, right
    break-if done?
    screen <- print screen, space, 7/white, bg-color  # foreground color is mostly unused except if the cursor shows up at this cell
    column <- add column, 1
    loop
  }
]

def cursor-position screen:address:screen -> row:number, column:number [
  local-scope
  load-ingredients
  # if x exists, lookup cursor in fake screen
  {
    break-unless screen
    row:number <- get *screen, cursor-row:offset
    column:number <- get *screen, cursor-column:offset
    return
  }
  row, column <- cursor-position-on-display
]

def move-cursor screen:address:screen, new-row:number, new-column:number -> screen:address:screen [
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
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    # print a character
    a:character <- copy 97/a
    fake-screen <- print fake-screen, a
    # move cursor to start of line
    fake-screen <- move-cursor fake-screen, 0/row, 0/column
    # clear line
    fake-screen <- clear-line fake-screen
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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

def cursor-down screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment row unless it's already all the way down
      height:number <- get *screen, num-rows:offset
      row:number <- get *screen, cursor-row:offset
      max:number <- subtract height, 1
      at-bottom?:boolean <- greater-or-equal row, max
      break-if at-bottom?
      row <- add row, 1
      *screen <- put *screen, cursor-row:offset, row
    }
    return
  }
  # otherwise, real screen
  move-cursor-down-on-display
]

def cursor-up screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement row unless it's already all the way up
      row:number <- get *screen, cursor-row:offset
      at-top?:boolean <- lesser-or-equal row, 0
      break-if at-top?
      row <- subtract row, 1
      *screen <- put *screen, cursor-row:offset, row
    }
    return
  }
  # otherwise, real screen
  move-cursor-up-on-display
]

def cursor-right screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment column unless it's already all the way to the right
      width:number <- get *screen, num-columns:offset
      column:number <- get *screen, cursor-column:offset
      max:number <- subtract width, 1
      at-bottom?:boolean <- greater-or-equal column, max
      break-if at-bottom?
      column <- add column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # otherwise, real screen
  move-cursor-right-on-display
]

def cursor-left screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement column unless it's already all the way to the left
      column:number <- get *screen, cursor-column:offset
      at-top?:boolean <- lesser-or-equal column, 0
      break-if at-top?
      column <- subtract column, 1
      *screen <- put *screen, cursor-column:offset, column
    }
    return
  }
  # otherwise, real screen
  move-cursor-left-on-display
]

def cursor-to-start-of-line screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  row:number <- cursor-position screen
  column:number <- copy 0
  screen <- move-cursor screen, row, column
]

def cursor-to-next-line screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
]

def move-cursor-to-column screen:address:screen, column:number -> screen:address:screen [
  local-scope
  load-ingredients
  row:number, _ <- cursor-position screen
  move-cursor screen, row, column
]

def screen-width screen:address:screen -> width:number [
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

def screen-height screen:address:screen -> height:number [
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

def hide-cursor screen:address:screen -> screen:address:screen [
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

def show-cursor screen:address:screen -> screen:address:screen [
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

def hide-screen screen:address:screen -> screen:address:screen [
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

def show-screen screen:address:screen -> screen:address:screen [
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

def print screen:address:screen, s:address:array:character -> screen:address:screen [
  local-scope
  load-ingredients
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  len:number <- length *s
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *s, i
    print screen, c, color, bg-color
    i <- add i, 1
    loop
  }
]

scenario print-text-stops-at-right-margin [
  run [
    local-scope
    fake-screen:address:screen <- new-fake-screen 3/width, 2/height
    s:address:array:character <- new [abcd]
    fake-screen <- print fake-screen, s:address:array:character
    cell:address:array:screen-cell <- get *fake-screen, data:offset
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

def print-integer screen:address:screen, n:number -> screen:address:screen [
  local-scope
  load-ingredients
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  # todo: other bases besides decimal
  s:address:array:character <- to-text n
  screen <- print screen, s, color, bg-color
]

# for now, we can only print integers
def print screen:address:screen, n:number -> screen:address:screen [
  local-scope
  load-ingredients
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  screen <- print-integer screen, n, color, bg-color
]

# addresses
def print screen:address:screen, n:address:_elem -> screen:address:screen [
  local-scope
  load-ingredients
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?
    bg-color <- copy 0/black
  }
  n2:number <- copy n
  screen <- print-integer screen, n2, color, bg-color
]
