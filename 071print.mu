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
  width:address:number <- get-address result:address:screen/deref, num-columns:offset
  width:address:number/deref <- next-ingredient
  height:address:number <- get-address result:address:screen/deref, num-rows:offset
  height:address:number/deref <- next-ingredient
#?   $print height:address:number/deref, 10/newline
  row:address:number <- get-address result:address:screen/deref, cursor-row:offset
  row:address:number/deref <- copy 0
  column:address:number <- get-address result:address:screen/deref, cursor-column:offset
  column:address:number/deref <- copy 0
  bufsize:number <- multiply width:address:number/deref, height:address:number/deref
  buf:address:address:array:screen-cell <- get-address result:address:screen/deref, data:offset
  buf:address:address:array:screen-cell/deref <- new screen-cell:type, bufsize:number
  clear-screen result:address:screen
  reply result:address:screen
]

recipe clear-screen [
  local-scope
  x:address:screen <- next-ingredient
#?   $print [clearing screen
#? ] #? 1
  # if x exists
  {
    break-unless x:address:screen
    # clear fake screen
    buf:address:array:screen-cell <- get x:address:screen/deref, data:offset
    max:number <- length buf:address:array:screen-cell/deref
    i:number <- copy 0
    {
      done?:boolean <- greater-or-equal i:number, max:number
      break-if done?:boolean
      curr:address:screen-cell <- index-address buf:address:array:screen-cell/deref, i:number
      curr-content:address:character <- get-address curr:address:screen-cell/deref, contents:offset
      curr-content:address:character/deref <- copy [ ]
      curr-color:address:character <- get-address curr:address:screen-cell/deref, color:offset
      curr-color:address:character/deref <- copy 7/white
      i:number <- add i:number, 1
      loop
    }
    # reset cursor
    cur:address:number <- get-address x:address:screen/deref, cursor-row:offset
    cur:address:number/deref <- copy 0
    cur:address:number <- get-address x:address:screen/deref, cursor-column:offset
    cur:address:number/deref <- copy 0
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-display
  reply x:address:screen/same-as-ingredient:0
]

recipe fake-screen-is-clear? [
  local-scope
  screen:address:screen <- next-ingredient
  reply-unless screen:address:screen, 1/true
  buf:address:array:screen-cell <- get screen:address:screen/deref, data:offset
  i:number <- copy 0
  len:number <- length buf:address:array:screen-cell/deref
  {
    done?:boolean <- greater-or-equal i:number, len:number
    break-if done?:boolean
    curr:screen-cell <- index buf:address:array:screen-cell/deref, i:number
    curr-contents:character <- get curr:screen-cell, contents:offset
    i:number <- add i:number, 1
    loop-unless curr-contents:character
    # not 0
    reply 0/false
  }
  reply 1/true
]

recipe print-character [
  local-scope
  x:address:screen <- next-ingredient
  c:character <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?:boolean
    bg-color:number <- copy 0/black
  }
#?   trace [app], [print character] #? 1
  {
    # if x exists
    # (handle special cases exactly like in the real screen)
    break-unless x:address:screen
    width:number <- get x:address:screen/deref, num-columns:offset
    height:number <- get x:address:screen/deref, num-rows:offset
    # if cursor is out of bounds, silently exit
    row:address:number <- get-address x:address:screen/deref, cursor-row:offset
    legal?:boolean <- greater-or-equal row:address:number/deref, 0
    reply-unless legal?:boolean, x:address:screen
    legal?:boolean <- lesser-than row:address:number/deref, height:number
    reply-unless legal?:boolean, x:address:screen
    column:address:number <- get-address x:address:screen/deref, cursor-column:offset
    legal?:boolean <- greater-or-equal column:address:number/deref, 0
    reply-unless legal?:boolean, x:address:screen
    legal?:boolean <- lesser-than column:address:number/deref, width:number
    reply-unless legal?:boolean, x:address:screen
    # special-case: newline
    {
      newline?:boolean <- equal c:character, 10/newline
#?       $print c:character, [ ], newline?:boolean, 10/newline
      break-unless newline?:boolean
      {
        # unless cursor is already at bottom
        bottom:number <- subtract height:number, 1
        at-bottom?:boolean <- greater-or-equal row:address:number/deref, bottom:number
        break-if at-bottom?:boolean
        # move it to the next row
        column:address:number/deref <- copy 0
        row:address:number/deref <- add row:address:number/deref, 1
      }
      reply x:address:screen/same-as-ingredient:0
    }
    # save character in fake screen
    index:number <- multiply row:address:number/deref, width:number
    index:number <- add index:number, column:address:number/deref
    buf:address:array:screen-cell <- get x:address:screen/deref, data:offset
    len:number <- length buf:address:array:screen-cell/deref
    # special-case: backspace
    {
      backspace?:boolean <- equal c:character, 8
      break-unless backspace?:boolean
      {
        # unless cursor is already at left margin
        at-left?:boolean <- lesser-or-equal column:address:number/deref, 0
        break-if at-left?:boolean
        # clear previous location
        column:address:number/deref <- subtract column:address:number/deref, 1
        index:number <- subtract index:number, 1
        cursor:address:screen-cell <- index-address buf:address:array:screen-cell/deref, index:number
        cursor-contents:address:character <- get-address cursor:address:screen-cell/deref, contents:offset
        cursor-color:address:number <- get-address cursor:address:screen-cell/deref, color:offset
        cursor-contents:address:character/deref <- copy 32/space
        cursor-color:address:number/deref <- copy 7/white
      }
      reply x:address:screen/same-as-ingredient:0
    }
#?     $print [saving character ], c:character, [ to fake screen ], cursor:address/screen, 10/newline
    cursor:address:screen-cell <- index-address buf:address:array:screen-cell/deref, index:number
    cursor-contents:address:character <- get-address cursor:address:screen-cell/deref, contents:offset
    cursor-color:address:number <- get-address cursor:address:screen-cell/deref, color:offset
    cursor-contents:address:character/deref <- copy c:character
    cursor-color:address:number/deref <- copy color:number
    # increment column unless it's already all the way to the right
    {
      right:number <- subtract width:number, 1
      at-right?:boolean <- greater-or-equal column:address:number/deref, right:number
      break-if at-right?:boolean
      column:address:number/deref <- add column:address:number/deref, 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  print-character-to-display c:character, color:number, bg-color:number
  reply x:address:screen/same-as-ingredient:0
]

scenario print-character-at-top-left [
  run [
#?     $start-tracing #? 3
    1:address:screen <- new-fake-screen 3/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    2:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    3:array:screen-cell <- copy 2:address:array:screen-cell/deref
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
    2:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    3:array:screen-cell <- copy 2:address:array:screen-cell/deref
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
#?     $start-tracing #? 3
    1:address:screen <- new-fake-screen 3/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 8  # backspace
    2:number <- get 1:address:screen/deref, cursor-column:offset
    3:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    4:array:screen-cell <- copy 3:address:array:screen-cell/deref
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
    2:number <- get 1:address:screen/deref, cursor-column:offset
    3:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    4:array:screen-cell <- copy 3:address:array:screen-cell/deref
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
    2:number <- get 1:address:screen/deref, cursor-column:offset
    3:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    4:array:screen-cell <- copy 3:address:array:screen-cell/deref
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
#?     $start-tracing #? 3
    1:address:screen <- new-fake-screen 3/width, 2/height
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    1:address:screen <- print-character 1:address:screen, 10/newline
    2:number <- get 1:address:screen/deref, cursor-row:offset
    3:number <- get 1:address:screen/deref, cursor-column:offset
    4:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    5:array:screen-cell <- copy 4:address:array:screen-cell/deref
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
    2:number <- get 1:address:screen/deref, cursor-row:offset
    3:number <- get 1:address:screen/deref, cursor-column:offset
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
    2:number <- get 1:address:screen/deref, cursor-row:offset
    3:number <- get 1:address:screen/deref, cursor-column:offset
    4:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    5:array:screen-cell <- copy 4:address:array:screen-cell/deref
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
  x:address:screen <- next-ingredient
  # if x exists, clear line in fake screen
  {
    break-unless x:address:screen
    width:number <- get x:address:screen/deref, num-columns:offset
    column:address:number <- get-address x:address:screen/deref, cursor-column:offset
    original-column:number <- copy column:address:number/deref
    # space over the entire line
#?     $start-tracing #? 1
    {
#?       $print column:address:number/deref, 10/newline
      right:number <- subtract width:number, 1
      done?:boolean <- greater-or-equal column:address:number/deref, right:number
      break-if done?:boolean
      print-character x:address:screen, [ ]  # implicitly updates 'column'
      loop
    }
    # now back to where the cursor was
    column:address:number/deref <- copy original-column:number
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-line-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-position [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, lookup cursor in fake screen
  {
    break-unless x:address:screen
    row:number <- get x:address:screen/deref, cursor-row:offset
    column:number <- get x:address:screen/deref, cursor-column:offset
    reply row:number, column:number, x:address:screen/same-as-ingredient:0
  }
  row:number, column:number <- cursor-position-on-display
  reply row:number, column:number, x:address:screen/same-as-ingredient:0
]

recipe move-cursor [
  local-scope
  x:address:screen <- next-ingredient
  new-row:number <- next-ingredient
  new-column:number <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    row:address:number <- get-address x:address:screen/deref, cursor-row:offset
    row:address:number/deref <- copy new-row:number
    column:address:number <- get-address x:address:screen/deref, cursor-column:offset
    column:address:number/deref <- copy new-column:number
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-on-display new-row:number, new-column:number
  reply x:address:screen/same-as-ingredient:0
]

scenario clear-line-erases-printed-characters [
  run [
#?     $start-tracing #? 4
    1:address:screen <- new-fake-screen 3/width, 2/height
    # print a character
    1:address:screen <- print-character 1:address:screen, 97  # 'a'
    # move cursor to start of line
    1:address:screen <- move-cursor 1:address:screen, 0/row, 0/column
    # clear line
    1:address:screen <- clear-line 1:address:screen
    2:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    3:array:screen-cell <- copy 2:address:array:screen-cell/deref
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
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if row < height-1
      height:number <- get x:address:screen/deref, num-rows:offset
      row:address:number <- get-address x:address:screen/deref, cursor-row:offset
      max:number <- subtract height:number, 1
      at-bottom?:boolean <- greater-or-equal row:address:number/deref, max:number
      break-if at-bottom?:boolean
      # row = row+1
#?       $print [AAA: ], row:address:number, [ -> ], row:address:number/deref, 10/newline
      row:address:number/deref <- add row:address:number/deref, 1
#?       $print [BBB: ], row:address:number, [ -> ], row:address:number/deref, 10/newline
#?       $start-tracing #? 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-down-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-up [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if row > 0
      row:address:number <- get-address x:address:screen/deref, cursor-row:offset
      at-top?:boolean <- lesser-or-equal row:address:number/deref, 0
      break-if at-top?:boolean
      # row = row-1
      row:address:number/deref <- subtract row:address:number/deref, 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-up-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-right [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if column < width-1
      width:number <- get x:address:screen/deref, num-columns:offset
      column:address:number <- get-address x:address:screen/deref, cursor-column:offset
      max:number <- subtract width:number, 1
      at-bottom?:boolean <- greater-or-equal column:address:number/deref, max:number
      break-if at-bottom?:boolean
      # column = column+1
      column:address:number/deref <- add column:address:number/deref, 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-right-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-left [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if column > 0
      column:address:number <- get-address x:address:screen/deref, cursor-column:offset
      at-top?:boolean <- lesser-or-equal column:address:number/deref, 0
      break-if at-top?:boolean
      # column = column-1
      column:address:number/deref <- subtract column:address:number/deref, 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-left-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-to-start-of-line [
  local-scope
  x:address:screen <- next-ingredient
  row:number, _, x:address:screen <- cursor-position x:address:screen
  column:number <- copy 0
  x:address:screen <- move-cursor x:address:screen, row:number, column:number
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-to-next-line [
  local-scope
  x:address:screen <- next-ingredient
  x:address:screen <- cursor-down x:address:screen
  x:address:screen <- cursor-to-start-of-line x:address:screen
  reply x:address:screen/same-as-ingredient:0
]

recipe screen-width [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    width:number <- get x:address:screen/deref, num-columns:offset
    reply width:number
  }
  # otherwise, real screen
  width:number <- display-width
  reply width:number
]

recipe screen-height [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    height:number <- get x:address:screen/deref, num-rows:offset
    reply height:number
  }
  # otherwise, real screen
  height:number <- display-height
  reply height:number
]

recipe hide-cursor [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless x:address:screen
    reply x:address:screen
  }
  # otherwise, real screen
  hide-cursor-on-display
  reply x:address:screen
]

recipe show-cursor [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless x:address:screen
    reply x:address:screen
  }
  # otherwise, real screen
  show-cursor-on-display
  reply x:address:screen
]

recipe hide-screen [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless x:address:screen
    reply x:address:screen
  }
  # otherwise, real screen
  hide-display
  reply x:address:screen
]

recipe show-screen [
  local-scope
  x:address:screen <- next-ingredient
  # if x exists (not real display), do nothing
  {
    break-unless x:address:screen
    reply x:address:screen
  }
  # otherwise, real screen
  show-display
  reply x:address:screen
]

recipe print-string [
  local-scope
  x:address:screen <- next-ingredient
  s:address:array:character <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?:boolean
    bg-color:number <- copy 0/black
  }
  len:number <- length s:address:array:character/deref
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i:number, len:number
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, i:number
    print-character x:address:screen, c:character, color:number, bg-color:number
    i:number <- add i:number, 1
    loop
  }
  reply x:address:screen/same-as-ingredient:0
]

scenario print-string-stops-at-right-margin [
  run [
    1:address:screen <- new-fake-screen 3/width, 2/height
    2:address:array:character <- new [abcd]
    1:address:screen <- print-string 1:address:screen, 2:address:array:character
    3:address:array:screen-cell <- get 1:address:screen/deref, data:offset
    4:array:screen-cell <- copy 3:address:array:screen-cell/deref
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
  x:address:screen <- next-ingredient
  n:number <- next-ingredient
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?:boolean
    color:number <- copy 7/white
  }
  bg-color:number, bg-color-found?:boolean <- next-ingredient
  {
    # default bg-color to black
    break-if bg-color-found?:boolean
    bg-color:number <- copy 0/black
  }
  # todo: other bases besides decimal
  s:address:array:character <- integer-to-decimal-string n:number
  print-string x:address:screen, s:address:array:character, color:number, bg-color:number
  reply x:address:screen/same-as-ingredient:0
]
