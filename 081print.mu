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

recipe new-fake-screen w:number, h:number -> result:address:screen [
  local-scope
  load-ingredients
  result <- new screen:type
  width:address:number <- get-address *result, num-columns:offset
  *width <- copy w
  height:address:number <- get-address *result, num-rows:offset
  *height <- copy h
  row:address:number <- get-address *result, cursor-row:offset
  *row <- copy 0
  column:address:number <- get-address *result, cursor-column:offset
  *column <- copy 0
  bufsize:number <- multiply *width, *height
  buf:address:address:array:screen-cell <- get-address *result, data:offset
  *buf <- new screen-cell:type, bufsize
  result <- clear-screen result
]

recipe clear-screen screen:address:screen -> screen:address:screen [
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
      curr:address:screen-cell <- index-address *buf, i
      curr-content:address:character <- get-address *curr, contents:offset
      *curr-content <- copy 0/empty
      curr-color:address:number <- get-address *curr, color:offset
      *curr-color <- copy 7/white
      i <- add i, 1
      loop
    }
    # reset cursor
    x:address:number <- get-address *screen, cursor-row:offset
    *x <- copy 0
    x <- get-address *screen, cursor-column:offset
    *x <- copy 0
    reply
  }
  # otherwise, real screen
  clear-display
]

recipe sync-screen screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  {
    break-if screen
    sync-display
  }
  # do nothing for fake screens
]

recipe fake-screen-is-empty? screen:address:screen -> result:boolean [
  local-scope
  load-ingredients
  reply-unless screen, 1/true
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
    reply 0/false
  }
  reply 1/true
]

recipe print screen:address:screen, c:character -> screen:address:screen [
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
    row:address:number <- get-address *screen, cursor-row:offset
    legal?:boolean <- greater-or-equal *row, 0
    reply-unless legal?
    legal? <- lesser-than *row, height
    reply-unless legal?
    column:address:number <- get-address *screen, cursor-column:offset
    legal? <- greater-or-equal *column, 0
    reply-unless legal?
    legal? <- lesser-than *column, width
    reply-unless legal?
    # special-case: newline
    {
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      {
        # unless cursor is already at bottom
        bottom:number <- subtract height, 1
        at-bottom?:boolean <- greater-or-equal *row, bottom
        break-if at-bottom?
        # move it to the next row
        *column <- copy 0
        *row <- add *row, 1
      }
      reply
    }
    # save character in fake screen
    index:number <- multiply *row, width
    index <- add index, *column
    buf:address:array:screen-cell <- get *screen, data:offset
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
      reply
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
    reply
  }
  # otherwise, real screen
  print-character-to-display c, color, bg-color
]

scenario print-character-at-top-left [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    2:address:array:screen-cell <- get *1:address:screen, data:offset
    3:array:screen-cell <- copy *2:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a, 1/red
    2:address:array:screen-cell <- get *1:address:screen, data:offset
    3:array:screen-cell <- copy *2:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    12:character <- copy 8/backspace
    1:address:screen <- print 1:address:screen, 12:character/backspace
    2:number <- get *1:address:screen, cursor-column:offset
    3:address:array:screen-cell <- get *1:address:screen, data:offset
    4:array:screen-cell <- copy *3:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    12:character <- copy 8/backspace
    1:address:screen <- print 1:address:screen, 12:character/backspace
    12:character <- copy 8/backspace
    1:address:screen <- print 1:address:screen, 12:character/backspace
    2:number <- get *1:address:screen, cursor-column:offset
    3:address:array:screen-cell <- get *1:address:screen, data:offset
    4:array:screen-cell <- copy *3:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 2/width, 2/height
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    12:character <- copy 98/b
    1:address:screen <- print 1:address:screen, 12:character/b
    13:character <- copy 99/b
    1:address:screen <- print 1:address:screen, 13:character/c
    2:number <- get *1:address:screen, cursor-column:offset
    3:address:array:screen-cell <- get *1:address:screen, data:offset
    4:array:screen-cell <- copy *3:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    10:character <- copy 10/newline
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    1:address:screen <- print 1:address:screen, 10:character/newline
    2:number <- get *1:address:screen, cursor-row:offset
    3:number <- get *1:address:screen, cursor-column:offset
    4:address:array:screen-cell <- get *1:address:screen, data:offset
    5:array:screen-cell <- copy *4:address:array:screen-cell
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    10:character <- copy 10/newline
    1:address:screen <- print 1:address:screen, 10:character/newline
    1:address:screen <- print 1:address:screen, 10:character/newline
    1:address:screen <- print 1:address:screen, 10:character/newline
    2:number <- get *1:address:screen, cursor-row:offset
    3:number <- get *1:address:screen, cursor-column:offset
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 0  # cursor column
  ]
]

scenario print-character-at-bottom-right [
  run [
    1:address:screen <- new-fake-screen 2/width, 2/height
    10:character <- copy 10/newline
    1:address:screen <- print 1:address:screen, 10:character/newline
    11:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 11:character/a
    12:character <- copy 98/b
    1:address:screen <- print 1:address:screen, 12:character/b
    13:character <- copy 99/c
    1:address:screen <- print 1:address:screen, 13:character/c
    1:address:screen <- print 1:address:screen, 10:character/newline
    14:character <- copy 100/d
    1:address:screen <- print 1:address:screen, 14:character/d
    2:number <- get *1:address:screen, cursor-row:offset
    3:number <- get *1:address:screen, cursor-column:offset
    4:address:array:screen-cell <- get *1:address:screen, data:offset
    20:array:screen-cell <- copy *4:address:array:screen-cell
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

recipe clear-line screen:address:screen -> screen:address:screen [
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
    reply
  }
  # otherwise, real screen
  clear-line-on-display
]

recipe cursor-position screen:address:screen -> row:number, column:number [
  local-scope
  load-ingredients
  # if x exists, lookup cursor in fake screen
  {
    break-unless screen
    row:number <- get *screen, cursor-row:offset
    column:number <- get *screen, cursor-column:offset
    reply
  }
  row, column <- cursor-position-on-display
]

recipe move-cursor screen:address:screen, new-row:number, new-column:number -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    row:address:number <- get-address *screen, cursor-row:offset
    *row <- copy new-row
    column:address:number <- get-address *screen, cursor-column:offset
    *column <- copy new-column
    reply
  }
  # otherwise, real screen
  move-cursor-on-display new-row, new-column
]

scenario clear-line-erases-printed-characters [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    # print a character
    10:character <- copy 97/a
    1:address:screen <- print 1:address:screen, 10:character/a
    # move cursor to start of line
    1:address:screen <- move-cursor 1:address:screen, 0/row, 0/column
    # clear line
    1:address:screen <- clear-line 1:address:screen
    2:address:array:screen-cell <- get *1:address:screen, data:offset
    20:array:screen-cell <- copy *2:address:array:screen-cell
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

recipe cursor-down screen:address:screen -> screen:address:screen [
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
    reply
  }
  # otherwise, real screen
  move-cursor-down-on-display
]

recipe cursor-up screen:address:screen -> screen:address:screen [
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
    reply
  }
  # otherwise, real screen
  move-cursor-up-on-display
]

recipe cursor-right screen:address:screen -> screen:address:screen [
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
    reply
  }
  # otherwise, real screen
  move-cursor-right-on-display
]

recipe cursor-left screen:address:screen -> screen:address:screen [
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
    reply
  }
  # otherwise, real screen
  move-cursor-left-on-display
]

recipe cursor-to-start-of-line screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  row:number <- cursor-position screen
  column:number <- copy 0
  screen <- move-cursor screen, row, column
]

recipe cursor-to-next-line screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
]

recipe screen-width screen:address:screen -> width:number [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    width <- get *screen, num-columns:offset
    reply
  }
  # otherwise, real screen
  width <- display-width
]

recipe screen-height screen:address:screen -> height:number [
  local-scope
  load-ingredients
  # if x exists, move cursor in fake screen
  {
    break-unless screen
    height <- get *screen, num-rows:offset
    reply
  }
  # otherwise, real screen
  height <- display-height
]

recipe hide-cursor screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  {
    break-unless screen
    reply
  }
  # otherwise, real screen
  hide-cursor-on-display
]

recipe show-cursor screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  {
    break-unless screen
    reply
  }
  # otherwise, real screen
  show-cursor-on-display
]

recipe hide-screen screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    reply
  }
  # otherwise, real screen
  hide-display
]

recipe show-screen screen:address:screen -> screen:address:screen [
  local-scope
  load-ingredients
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    reply
  }
  # otherwise, real screen
  show-display
]

recipe print screen:address:screen, s:address:array:character -> screen:address:screen [
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
    1:address:screen <- new-fake-screen 3/width, 2/height
    2:address:array:character <- new [abcd]
    1:address:screen <- print 1:address:screen, 2:address:array:character
    3:address:array:screen-cell <- get *1:address:screen, data:offset
    4:array:screen-cell <- copy *3:address:array:screen-cell
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

recipe print-integer screen:address:screen, n:number -> screen:address:screen [
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
recipe print screen:address:screen, n:number -> screen:address:screen [
  local-scope
  load-ingredients
  screen <- print-integer screen, n
]
