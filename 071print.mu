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

recipe new-fake-screen [
  local-scope
  result:address:screen <- new screen:type
  width:address:number <- get-address *result, num-columns:offset
  *width <- next-ingredient
  height:address:number <- get-address *result, num-rows:offset
  *height <- next-ingredient
  row:address:number <- get-address *result, cursor-row:offset
  *row <- copy 0
  column:address:number <- get-address *result, cursor-column:offset
  *column <- copy 0
  bufsize:number <- multiply *width, *height
  buf:address:address:array:screen-cell <- get-address *result, data:offset
  *buf <- new screen-cell:type, bufsize
  clear-screen result
  reply result
]

recipe clear-screen [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists
  {
    break-unless sc
    # clear fake screen
    buf:address:array:screen-cell <- get *sc, data:offset
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
    x:address:number <- get-address *sc, cursor-row:offset
    *x <- copy 0
    x <- get-address *sc, cursor-column:offset
    *x <- copy 0
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-display
  reply sc/same-as-ingredient:0
]

recipe sync-screen [
  local-scope
  sc:address:screen <- next-ingredient
  {
    break-if sc
    sync-display
  }
  # do nothing for fake screens
]

recipe fake-screen-is-empty? [
  local-scope
  sc:address:screen <- next-ingredient
  reply-unless sc, 1/true
  buf:address:array:screen-cell <- get *sc, data:offset
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

recipe print-character [
  local-scope
  sc:address:screen <- next-ingredient
  c:character <- next-ingredient
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
    break-unless sc
    width:number <- get *sc, num-columns:offset
    height:number <- get *sc, num-rows:offset
    # if cursor is out of bounds, silently exit
    row:address:number <- get-address *sc, cursor-row:offset
    legal?:boolean <- greater-or-equal *row, 0
    reply-unless legal?, sc
    legal? <- lesser-than *row, height
    reply-unless legal?, sc
    column:address:number <- get-address *sc, cursor-column:offset
    legal? <- greater-or-equal *column, 0
    reply-unless legal?, sc
    legal? <- lesser-than *column, width
    reply-unless legal?, sc
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
      reply sc/same-as-ingredient:0
    }
    # save character in fake screen
    index:number <- multiply *row, width
    index <- add index, *column
    buf:address:array:screen-cell <- get *sc, data:offset
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
      reply sc/same-as-ingredient:0
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
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  print-character-to-display c, color, bg-color
  reply sc/same-as-ingredient:0
]

scenario print-character-at-top-left [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
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

scenario print-character-color [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97/a, 1/red
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
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 8  # backspace
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
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 8  # backspace
    1:address:screen <- print-character 1:address:screen, 8  # backspace
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

scenario print-at-right-margin [
  run [
    1:address:screen <- new-fake-screen 2/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 98  # 'b'
    1:address:screen <- print-character 1:address:screen, 99  # 'c'
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
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 10/newline
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
    1:address:screen <- print-character 1:address:screen, 10/newline
    1:address:screen <- print-character 1:address:screen, 10/newline
    1:address:screen <- print-character 1:address:screen, 10/newline
    2:number <- get *1:address:screen, cursor-row:offset
    3:number <- get *1:address:screen, cursor-column:offset
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 0  # cursor column
  ]
]

scenario print-at-bottom-right [
  run [
    1:address:screen <- new-fake-screen 2/width, 2/height
    1:address:screen <- print-character 1:address:screen, 10/newline
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 98  # 'b'
    1:address:screen <- print-character 1:address:screen, 99  # 'c'
    1:address:screen <- print-character 1:address:screen, 10/newline
    1:address:screen <- print-character 1:address:screen, 100  # 'd'
    2:number <- get *1:address:screen, cursor-row:offset
    3:number <- get *1:address:screen, cursor-column:offset
    4:address:array:screen-cell <- get *1:address:screen, data:offset
    5:array:screen-cell <- copy *4:address:array:screen-cell
  ]
  memory-should-contain [
    2 <- 1  # cursor row
    3 <- 1  # cursor column
    5 <- 4  # width*height
    6 <- 0  # unused
    7 <- 7  # white
    8 <- 0  # unused
    9 <- 7  # white
    10 <- 97 # 'a'
    11 <- 7  # white
    12 <- 100  # 'd' over 'b' and 'c' and newline
    13 <- 7  # white
    14 <- 0
  ]
]

recipe clear-line [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, clear line in fake screen
  {
    break-unless sc
    width:number <- get *sc, num-columns:offset
    column:address:number <- get-address *sc, cursor-column:offset
    original-column:number <- copy *column
    # space over the entire line
    {
      right:number <- subtract width, 1
      done?:boolean <- greater-or-equal *column, right
      break-if done?
      print-character sc, [ ]  # implicitly updates 'column'
      loop
    }
    # now back to where the cursor was
    *column <- copy original-column
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-line-on-display
  reply sc/same-as-ingredient:0
]

recipe cursor-position [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, lookup cursor in fake screen
  {
    break-unless sc
    row:number <- get *sc, cursor-row:offset
    column:number <- get *sc, cursor-column:offset
    reply row, column, sc/same-as-ingredient:0
  }
  row, column <- cursor-position-on-display
  reply row, column, sc/same-as-ingredient:0
]

recipe move-cursor [
  local-scope
  sc:address:screen <- next-ingredient
  new-row:number <- next-ingredient
  new-column:number <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    row:address:number <- get-address *sc, cursor-row:offset
    *row <- copy new-row
    column:address:number <- get-address *sc, cursor-column:offset
    *column <- copy new-column
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-on-display new-row, new-column
  reply sc/same-as-ingredient:0
]

scenario clear-line-erases-printed-characters [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    # print a character
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    # move cursor to start of line
    1:address:screen <- move-cursor 1:address:screen, 0/row, 0/column
    # clear line
    1:address:screen <- clear-line 1:address:screen
    2:address:array:screen-cell <- get *1:address:screen, data:offset
    3:array:screen-cell <- copy *2:address:array:screen-cell
  ]
  # screen should be blank
  memory-should-contain [
    3 <- 6  # width*height
    4 <- 0
    5 <- 7
    6 <- 0
    7 <- 7
    8 <- 0
    9 <- 7
    10 <- 0
    11 <- 7
    12 <- 0
    13 <- 7
    14 <- 0
    15 <- 7
  ]
]

recipe cursor-down [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    {
      # increment row unless it's already all the way down
      height:number <- get *sc, num-rows:offset
      row:address:number <- get-address *sc, cursor-row:offset
      max:number <- subtract height, 1
      at-bottom?:boolean <- greater-or-equal *row, max
      break-if at-bottom?
      *row <- add *row, 1
    }
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-down-on-display
  reply sc/same-as-ingredient:0
]

recipe cursor-up [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    {
      # decrement row unless it's already all the way up
      row:address:number <- get-address *sc, cursor-row:offset
      at-top?:boolean <- lesser-or-equal *row, 0
      break-if at-top?
      *row <- subtract *row, 1
    }
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-up-on-display
  reply sc/same-as-ingredient:0
]

recipe cursor-right [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    {
      # increment column unless it's already all the way to the right
      width:number <- get *sc, num-columns:offset
      column:address:number <- get-address *sc, cursor-column:offset
      max:number <- subtract width, 1
      at-bottom?:boolean <- greater-or-equal *column, max
      break-if at-bottom?
      *column <- add *column, 1
    }
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-right-on-display
  reply sc/same-as-ingredient:0
]

recipe cursor-left [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    {
      # decrement column unless it's already all the way to the left
      column:address:number <- get-address *sc, cursor-column:offset
      at-top?:boolean <- lesser-or-equal *column, 0
      break-if at-top?
      *column <- subtract *column, 1
    }
    reply sc/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-left-on-display
  reply sc/same-as-ingredient:0
]

recipe cursor-to-start-of-line [
  local-scope
  sc:address:screen <- next-ingredient
  row:number, _, sc <- cursor-position sc
  column:number <- copy 0
  sc <- move-cursor sc, row, column
  reply sc/same-as-ingredient:0
]

recipe cursor-to-next-line [
  local-scope
  screen:address <- next-ingredient
  screen <- cursor-down screen
  screen <- cursor-to-start-of-line screen
  reply screen/same-as-ingredient:0
]

recipe screen-width [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    width:number <- get *sc, num-columns:offset
    reply width
  }
  # otherwise, real screen
  width:number <- display-width
  reply width
]

recipe screen-height [
  local-scope
  sc:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless sc
    height:number <- get *sc, num-rows:offset
    reply height
  }
  # otherwise, real screen
  height:number <- display-height
  reply height
]

recipe hide-cursor [
  local-scope
  screen:address <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless screen
    reply screen
  }
  # otherwise, real screen
  hide-cursor-on-display
  reply screen
]

recipe show-cursor [
  local-scope
  screen:address <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless screen
    reply screen
  }
  # otherwise, real screen
  show-cursor-on-display
  reply screen
]

recipe hide-screen [
  local-scope
  screen:address <- next-ingredient
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    reply screen
  }
  # otherwise, real screen
  hide-display
  reply screen
]

recipe show-screen [
  local-scope
  screen:address <- next-ingredient
  # if x exists (not real display), do nothing
  # todo: help test this
  {
    break-unless screen
    reply screen
  }
  # otherwise, real screen
  show-display
  reply screen
]

recipe print-string [
  local-scope
  screen:address:screen <- next-ingredient
  s:address:array:character <- next-ingredient
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
    print-character screen, c, color, bg-color
    i <- add i, 1
    loop
  }
  reply screen/same-as-ingredient:0
]

scenario print-string-stops-at-right-margin [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    2:address:array:character <- new [abcd]
    1:address:screen <- print-string 1:address:screen, 2:address:array:character
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

recipe print-integer [
  local-scope
  screen:address <- next-ingredient
  n:number <- next-ingredient
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
  s:address:array:character <- integer-to-decimal-string n
  print-string screen, s, color, bg-color
  reply screen/same-as-ingredient:0
]
