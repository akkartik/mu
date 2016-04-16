# Wrappers around print primitives that take a 'screen' object and are thus
# easier to test.

container screen [
  num-rows:number
  num-columns:number
  cursor-row:number
  cursor-column:number
  data:address:shared:array:screen-cell
]

container screen-cell [
  contents:character
  color:number
]

def new-fake-screen w:number, h:number -> result:address:shared:screen [
  local-scope
  load-ingredients
  result <- new screen:type
  bufsize:number <- multiply w, h
  data:address:shared:array:screen-cell <- new screen-cell:type, bufsize
  *result <- merge h/num-rows, w/num-columns, 0/cursor-row, 0/cursor-column, data
  result <- clear-screen result
]

def clear-screen screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists
  {
    break-unless screen
    # clear fake screen
    buf:address:shared:array:screen-cell <- get *screen, data:offset
    max:number <- length *buf
    i:number <- copy 0
    {
      done?:boolean <- greater-or-equal i, max
      break-if done?
      curr:address:screen-cell <- index-address *buf, i
      *curr <- merge 0/empty, 7/white
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

def sync-screen screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  {
    break-if screen
    sync-display
  }
  # do nothing for fake screens
]

def fake-screen-is-empty? screen:address:shared:screen -> result:boolean [
  local-scope
  load-ingredients
  return-unless screen, 1/true
  buf:address:shared:array:screen-cell <- get *screen, data:offset
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

def print screen:address:shared:screen, c:character -> screen:address:shared:screen [
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
    column:address:number <- get-address *screen, cursor-column:offset
    legal? <- greater-or-equal *column, 0
    return-unless legal?
    legal? <- lesser-than *column, width
    return-unless legal?
#?     $print [print-character (], row, [, ], *column, [): ], c, 10/newline
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
        *column <- copy 0
        row <- add row, 1
        *screen <- put *screen, cursor-row:offset, row
      }
      return
    }
    # save character in fake screen
    index:number <- multiply row, width
    index <- add index, *column
    buf:address:shared:array:screen-cell <- get *screen, data:offset
    len:number <- length *buf
    # special-case: backspace
    {
      backspace?:boolean <- equal c, 8
      break-unless backspace?
      {
        # unless cursor is already at left margin
        at-left?:boolean <- lesser-or-equal *column, 0
        break-if at-left?
        # clear previous location
        *column <- subtract *column, 1
        index <- subtract index, 1
        cursor:address:screen-cell <- index-address *buf, index
        cursor-contents:address:character <- get-address *cursor, contents:offset
        *cursor-contents <- copy 32/space
        cursor-color:address:number <- get-address *cursor, color:offset
        *cursor-color <- copy 7/white
      }
      return
    }
    cursor:address:screen-cell <- index-address *buf, index
    cursor-contents:address:character <- get-address *cursor, contents:offset
    *cursor-contents <- copy c
    cursor-color:address:number <- get-address *cursor, color:offset
    *cursor-color <- copy color
    # increment column unless it's already all the way to the right
    {
      right:number <- subtract width, 1
      at-right?:boolean <- greater-or-equal *column, right
      break-if at-right?
      *column <- add *column, 1
    }
    return
  }
  # otherwise, real screen
  print-character-to-display c, color, bg-color
]

scenario print-character-at-top-left [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    2:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    3:array:screen-cell <- copy *2:address:shared:array:screen-cell
  ]
  memory-should-contain [
    3 <- 6  # width*height
    4 <- 97  # 'a'
    5 <- 7  # white
    6 <- 0
  ]
]

scenario print-character-in-color [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a, 1/red
    2:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    3:array:screen-cell <- copy *2:address:shared:array:screen-cell
  ]
  memory-should-contain [
    3 <- 6  # width*height
    4 <- 97  # 'a'
    5 <- 1  # red
    6 <- 0
  ]
]

scenario print-backspace-character [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    12:character <- copy 8/backspace
    1:address:shared:screen <- print 1:address:shared:screen, 12:character/backspace
    2:number <- get *1:address:shared:screen, cursor-column:offset
    3:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    4:array:screen-cell <- copy *3:address:shared:array:screen-cell
  ]
  memory-should-contain [
    2 <- 0  # cursor column
    4 <- 6  # width*height
    5 <- 32  # space, not 'a'
    6 <- 7  # white
    7 <- 0
  ]
]

scenario print-extra-backspace-character [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    12:character <- copy 8/backspace
    1:address:shared:screen <- print 1:address:shared:screen, 12:character/backspace
    12:character <- copy 8/backspace
    1:address:shared:screen <- print 1:address:shared:screen, 12:character/backspace
    2:number <- get *1:address:shared:screen, cursor-column:offset
    3:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    4:array:screen-cell <- copy *3:address:shared:array:screen-cell
  ]
  memory-should-contain [
    2 <- 0  # cursor column
    4 <- 6  # width*height
    5 <- 32  # space, not 'a'
    6 <- 7  # white
    7 <- 0
  ]
]

scenario print-character-at-right-margin [
  run [
    1:address:shared:screen <- new-fake-screen 2/width, 2/height
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    12:character <- copy 98/b
    1:address:shared:screen <- print 1:address:shared:screen, 12:character/b
    13:character <- copy 99/b
    1:address:shared:screen <- print 1:address:shared:screen, 13:character/c
    2:number <- get *1:address:shared:screen, cursor-column:offset
    3:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    4:array:screen-cell <- copy *3:address:shared:array:screen-cell
  ]
  memory-should-contain [
    2 <- 1  # cursor column
    4 <- 4  # width*height
    5 <- 97  # 'a'
    6 <- 7  # white
    7 <- 99  # 'c' over 'b'
    8 <- 7  # white
    9 <- 0
  ]
]

scenario print-newline-character [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    10:character <- copy 10/newline
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    2:number <- get *1:address:shared:screen, cursor-row:offset
    3:number <- get *1:address:shared:screen, cursor-column:offset
    4:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    5:array:screen-cell <- copy *4:address:shared:array:screen-cell
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 0  # cursor column
    5 <- 6  # width*height
    6 <- 97  # 'a'
    7 <- 7  # white
    8 <- 0
  ]
]

scenario print-newline-at-bottom-line [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    10:character <- copy 10/newline
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    2:number <- get *1:address:shared:screen, cursor-row:offset
    3:number <- get *1:address:shared:screen, cursor-column:offset
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 0  # cursor column
  ]
]

scenario print-character-at-bottom-right [
  run [
    1:address:shared:screen <- new-fake-screen 2/width, 2/height
    10:character <- copy 10/newline
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    11:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 11:character/a
    12:character <- copy 98/b
    1:address:shared:screen <- print 1:address:shared:screen, 12:character/b
    13:character <- copy 99/c
    1:address:shared:screen <- print 1:address:shared:screen, 13:character/c
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/newline
    14:character <- copy 100/d
    1:address:shared:screen <- print 1:address:shared:screen, 14:character/d
    2:number <- get *1:address:shared:screen, cursor-row:offset
    3:number <- get *1:address:shared:screen, cursor-column:offset
    4:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    20:array:screen-cell <- copy *4:address:shared:array:screen-cell
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 1  # cursor column
    20 <- 4  # width*height
    21 <- 0  # unused
    22 <- 7  # white
    23 <- 0  # unused
    24 <- 7  # white
    25 <- 97 # 'a'
    26 <- 7  # white
    27 <- 100  # 'd' over 'b' and 'c' and newline
    28 <- 7  # white
    29 <- 0
  ]
]

def clear-line screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  space:character <- copy 0/nul
  # if x exists, clear line in fake screen
  {
    break-unless screen
    width:number <- get *screen, num-columns:offset
    column:address:number <- get-address *screen, cursor-column:offset
    original-column:number <- copy *column
    # space over the entire line
    {
      right:number <- subtract width, 1
      done?:boolean <- greater-or-equal *column, right
      break-if done?
      print screen, space  # implicitly updates 'column'
      loop
    }
    # now back to where the cursor was
    *column <- copy original-column
    return
  }
  # otherwise, real screen
  clear-line-on-display
]

def cursor-position screen:address:shared:screen -> row:number, column:number [
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

def move-cursor screen:address:shared:screen, new-row:number, new-column:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    row:address:number <- get-address *screen, cursor-row:offset
    *row <- copy new-row
    column:address:number <- get-address *screen, cursor-column:offset
    *column <- copy new-column
    return
  }
  # otherwise, real screen
  move-cursor-on-display new-row, new-column
]

scenario clear-line-erases-printed-characters [
  run [
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    # print a character
    10:character <- copy 97/a
    1:address:shared:screen <- print 1:address:shared:screen, 10:character/a
    # move cursor to start of line
    1:address:shared:screen <- move-cursor 1:address:shared:screen, 0/row, 0/column
    # clear line
    1:address:shared:screen <- clear-line 1:address:shared:screen
    2:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    20:array:screen-cell <- copy *2:address:shared:array:screen-cell
  ]
  # screen should be blank
  memory-should-contain [
    20 <- 6  # width*height
    21 <- 0
    22 <- 7
    23 <- 0
    24 <- 7
    25 <- 0
    26 <- 7
    27 <- 0
    28 <- 7
    29 <- 0
    30 <- 7
    31 <- 0
    32 <- 7
  ]
]

def cursor-down screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment row unless it's already all the way down
      height:number <- get *screen, num-rows:offset
      row:address:number <- get-address *screen, cursor-row:offset
      max:number <- subtract height, 1
      at-bottom?:boolean <- greater-or-equal *row, max
      break-if at-bottom?
      *row <- add *row, 1
    }
    return
  }
  # otherwise, real screen
  move-cursor-down-on-display
]

def cursor-up screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement row unless it's already all the way up
      row:address:number <- get-address *screen, cursor-row:offset
      at-top?:boolean <- lesser-or-equal *row, 0
      break-if at-top?
      *row <- subtract *row, 1
    }
    return
  }
  # otherwise, real screen
  move-cursor-up-on-display
]

def cursor-right screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # increment column unless it's already all the way to the right
      width:number <- get *screen, num-columns:offset
      column:address:number <- get-address *screen, cursor-column:offset
      max:number <- subtract width, 1
      at-bottom?:boolean <- greater-or-equal *column, max
      break-if at-bottom?
      *column <- add *column, 1
    }
    return
  }
  # otherwise, real screen
  move-cursor-right-on-display
]

def cursor-left screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    {
      # decrement column unless it's already all the way to the left
      column:address:number <- get-address *screen, cursor-column:offset
      at-top?:boolean <- lesser-or-equal *column, 0
      break-if at-top?
      *column <- subtract *column, 1
    }
    return
  }
  # otherwise, real screen
  move-cursor-left-on-display
]

def cursor-to-start-of-line screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  row:number <- cursor-position screen
  column:number <- copy 0
  screen <- move-cursor screen, row, column
]

def cursor-to-next-line screen:address:shared:screen -> screen:address:shared:screen [
  local-scope
  load-ingredients
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
]

def screen-width screen:address:shared:screen -> width:number [
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

def screen-height screen:address:shared:screen -> height:number [
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

def hide-cursor screen:address:shared:screen -> screen:address:shared:screen [
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

def show-cursor screen:address:shared:screen -> screen:address:shared:screen [
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

def hide-screen screen:address:shared:screen -> screen:address:shared:screen [
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

def show-screen screen:address:shared:screen -> screen:address:shared:screen [
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

def print screen:address:shared:screen, s:address:shared:array:character -> screen:address:shared:screen [
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
    1:address:shared:screen <- new-fake-screen 3/width, 2/height
    2:address:shared:array:character <- new [abcd]
    1:address:shared:screen <- print 1:address:shared:screen, 2:address:shared:array:character
    3:address:shared:array:screen-cell <- get *1:address:shared:screen, data:offset
    4:array:screen-cell <- copy *3:address:shared:array:screen-cell
  ]
  memory-should-contain [
    4 <- 6  # width*height
    5 <- 97  # 'a'
    6 <- 7  # white
    7 <- 98  # 'b'
    8 <- 7  # white
    9 <- 100  # 'd' overwrites 'c'
    10 <- 7  # white
    11 <- 0  # unused
  ]
]

def print-integer screen:address:shared:screen, n:number -> screen:address:shared:screen [
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
  s:address:shared:array:character <- to-text n
  screen <- print screen, s, color, bg-color
]

# for now, we can only print integers
def print screen:address:shared:screen, n:number -> screen:address:shared:screen [
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
def print screen:address:shared:screen, n:address:_elem -> screen:address:shared:screen [
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
