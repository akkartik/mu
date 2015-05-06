# Wrappers around print primitives that take a 'screen' object and are thus
# easier to test.

container screen [
  num-rows:integer
  num-columns:integer
  cursor-row:integer
  cursor-column:integer
  data:address:array:character
]

recipe init-fake-screen [
  default-space:address:array:location <- new location:type, 30:literal/capacity
  result:address:screen <- new screen:type
  width:address:integer <- get-address result:address:screen/deref, num-columns:offset
  width:address:integer/deref <- next-ingredient
  height:address:integer <- get-address result:address:screen/deref, num-rows:offset
  height:address:integer/deref <- next-ingredient
  row:address:integer <- get-address result:address:screen/deref, cursor-row:offset
  row:address:integer/deref <- copy 0:literal
  column:address:integer <- get-address result:address:screen/deref, cursor-column:offset
  column:address:integer/deref <- copy 0:literal
  bufsize:integer <- multiply width:address:integer/deref, height:address:integer/deref
  buf:address:address:array:character <- get-address result:address:screen/deref, data:offset
  buf:address:address:array:character/deref <- new character:literal, bufsize:integer
  clear-screen result:address:screen
  reply result:address:screen
]

recipe clear-screen [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists
  {
    break-unless x:address:screen
    # clear fake screen
    buf:address:array:character <- get x:address:screen/deref, data:offset
    max:integer <- length buf:address:array:character/deref
    i:integer <- copy 0:literal
    {
      done?:boolean <- greater-or-equal i:integer, max:integer
      break-if done?:boolean
      c:address:character <- index-address buf:address:array:character/deref, i:integer
      c:address:character/deref <- copy [ ]
      i:integer <- add i:integer, 1:literal
      loop
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-display
  reply x:address:screen/same-as-ingredient:0
]

recipe print-character [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  c:character <- next-ingredient
#?   $print x:address:character #? 1
#?   $print [ print-character #? 1
#? ] #? 1
  {
    # if x exists
    break-unless x:address:screen
#?   $print [print-character2 #? 1
#? ] #? 1
    # save character in fake screen
    row:address:integer <- get-address x:address:screen/deref, cursor-row:offset
#?     $print [CCC: ] #? 1
#?     $print row:address:integer #? 1
#?     $print [ -> ] #? 1
#?     $print row:address:integer/deref #? 1
#?     $print [ #? 1
#? ] #? 1
#?     $stop-tracing #? 1
    column:address:integer <- get-address x:address:screen/deref, cursor-column:offset
    width:integer <- get x:address:screen/deref, num-columns:offset
    index:integer <- multiply row:address:integer/deref, width:integer
    index:integer <- add index:integer, column:address:integer/deref
    buf:address:array:character <- get x:address:screen/deref, data:offset
    cursor:address:character <- index-address buf:address:array:character/deref, index:integer
#?     $print cursor:address:character #? 1
#?     $print [ #? 1
#? ] #? 1
    cursor:address:character/deref <- copy c:character  # todo: newline, etc.
    # increment column unless it's already all the way to the right
    {
      at-right?:boolean <- equal column:address:integer/deref, width:integer
      break-if at-right?:boolean
      column:address:integer/deref <- add column:address:integer/deref, 1:literal
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  print-character-to-display c:character
  reply x:address:screen/same-as-ingredient:0
]

scenario print-character-at-top-left [
  run [
#?     $start-tracing #? 3
    1:address:screen <- init-fake-screen 3:literal/width, 2:literal/height
    1:address:screen <- print-character 1:address:screen, 97:literal  # 'a'
    2:address:array:character <- get 1:address:screen/deref, data:offset
    3:array:character <- copy 2:address:array:character/deref
  ]
  memory-should-contain [
    3 <- 6  # width*height
    4 <- 97  # 'a'
    5 <- 0
  ]
]

recipe clear-line [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, clear line in fake screen
  {
    break-unless x:address:screen
    n:integer <- get x:address:screen/deref, num-columns:offset
    column:address:integer <- get-address x:address:screen/deref, cursor-column:offset
    original-column:integer <- copy column:address:integer/deref
    # space over the entire line
    {
      done?:boolean <- greater-or-equal column:address:integer/deref, n:integer
      break-if done?:boolean
      print-character x:address:screen, [ ]  # implicitly updates 'column'
      loop
    }
    # now back to where the cursor was
    column:address:integer/deref <- copy original-column:integer
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  clear-line-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-position [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, lookup cursor in fake screen
  {
    break-unless x:address:screen
    row:integer <- get x:address:screen/deref, cursor-row:offset
    column:integer <- get x:address:screen/deref, cursor-column:offset
    reply row:integer, column:integer, x:address:screen/same-as-ingredient:0
  }
  row:integer, column:integer <- cursor-position-on-display
  reply row:integer, column:integer, x:address:screen/same-as-ingredient:0
]

recipe move-cursor [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  new-row:integer <- next-ingredient
  new-column:integer <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    row:address:integer <- get-address x:address:screen/deref cursor-row:offset
    row:address:integer/deref <- copy new-row:integer
    column:address:integer <- get-address x:address:screen/deref cursor-column:offset
    column:address:integer/deref <- copy new-column:integer
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-on-display new-row:integer, new-column:integer
  reply x:address:screen/same-as-ingredient:0
]

scenario clear-line-erases-printed-characters [
  run [
#?     $start-tracing #? 3
    1:address:screen <- init-fake-screen 3:literal/width, 2:literal/height
    # print a character
    1:address:screen <- print-character 1:address:screen, 97:literal  # 'a'
    # move cursor to start of line
    1:address:screen <- move-cursor 1:address:screen, 0:literal/row, 0:literal/column
    # clear line
    1:address:screen <- clear-line 1:address:screen
    2:address:array:character <- get 1:address:screen/deref, data:offset
    3:array:character <- copy 2:address:array:character/deref
  ]
  # screen should be blank
  memory-should-contain [
    3 <- 6  # width*height
    4 <- 0
    5 <- 0
    6 <- 0
    7 <- 0
    8 <- 0
    9 <- 0
  ]
]

recipe cursor-down [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if row < height
      height:integer <- get x:address:screen/deref, num-rows:offset
      row:address:integer <- get-address x:address:screen/deref cursor-row:offset
      at-bottom?:boolean <- greater-or-equal row:address:integer/deref, height:integer
      break-if at-bottom?:boolean
      # row = row+1
#?       $print [AAA: ] #? 1
#?       $print row:address:integer #? 1
#?       $print [ -> ] #? 1
#?       $print row:address:integer/deref #? 1
#?       $print [ #? 1
#? ] #? 1
      row:address:integer/deref <- add row:address:integer/deref, 1:literal
#?       $print [BBB: ] #? 1
#?       $print row:address:integer #? 1
#?       $print [ -> ] #? 1
#?       $print row:address:integer/deref #? 1
#?       $print [ #? 1
#? ] #? 1
#?       $start-tracing #? 1
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-down-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-up [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if row >= 0
      row:address:integer <- get-address x:address:screen/deref cursor-row:offset
      at-top?:boolean <- lesser-than row:address:integer/deref, 0:literal
      break-if at-top?:boolean
      # row = row-1
      row:address:integer/deref <- subtract row:address:integer/deref, 1:literal
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-up-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-right [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if column < width
      width:integer <- get x:address:screen/deref, num-columns:offset
      column:address:integer <- get-address x:address:screen/deref cursor-column:offset
      at-bottom?:boolean <- greater-or-equal column:address:integer/deref, width:integer
      break-if at-bottom?:boolean
      # column = column+1
      column:address:integer/deref <- add column:address:integer/deref, 1:literal
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-right-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-left [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  # if x exists, move cursor in fake screen
  {
    break-unless x:address:screen
    {
      # if column >= 0
      column:address:integer <- get-address x:address:screen/deref cursor-column:offset
      at-top?:boolean <- lesser-than column:address:integer/deref, 0:literal
      break-if at-top?:boolean
      # column = column-1
      column:address:integer/deref <- subtract column:address:integer/deref, 1:literal
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-left-on-display
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-to-start-of-line [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  row:integer, _, x:address:screen <- cursor-position x:address:screen
  column:integer <- copy 0:literal
  x:address:screen <- move-cursor x:address:screen, row:integer, column:integer
  reply x:address:screen/same-as-ingredient:0
]

recipe cursor-to-next-line [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  x:address:screen <- cursor-down x:address:screen
  x:address:screen <- cursor-to-start-of-line x:address:screen
  reply x:address:screen/same-as-ingredient:0
]

recipe print-string [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  s:address:array:character <- next-ingredient
  len:integer <- length s:address:array:character/deref
  i:integer <- copy 0:literal
  {
    done?:boolean <- greater-or-equal i:integer, len:integer
    break-if done?:boolean
    c:character <- index s:address:array:character/deref, i:integer
    print-character x:address:screen c:character
    i:integer <- add i:integer, 1:literal
    loop
  }
  reply x:address:screen/same-as-ingredient:0
]

recipe print-integer [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:screen <- next-ingredient
  n:integer <- next-ingredient
  # todo: other bases besides decimal
  s:address:array:character <- integer-to-decimal-string n:integer
  print-string x:address:screen, s:address:array:character
  reply x:address:screen/same-as-ingredient:0
]
