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
      x:address:character <- index-address buf:address:array:character/deref, i:integer
      x:address:character/deref <- copy [ ]
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
  {
    # if x exists
    break-unless x:address:screen
    # save character in fake screen
    row:address:integer <- get-address x:address:screen/deref, cursor-row:offset
    column:address:integer <- get-address x:address:screen/deref, cursor-column:offset
    width:integer <- get x:address:screen/deref, num-columns:offset
    index:integer <- multiply row:address:integer/deref, width:integer
    index:integer <- add index:integer, column:address:integer/deref
    buf:address:array:character <- get x:address:screen/deref, data:offset
    cursor:address:character <- index-address buf:address:array:character/deref, index:integer
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
    reply row:integer, column:integer
  }
  row:integer, column:integer <- cursor-position-on-display
  reply row:integer, column:integer
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
      row:address:integer/deref <- add row:address:integer, 1:literal
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
      row:address:integer/deref <- subtract row:address:integer, 1:literal
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
      column:address:integer/deref <- add column:address:integer, 1:literal
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
      column:address:integer/deref <- subtract column:address:integer, 1:literal
    }
    reply x:address:screen/same-as-ingredient:0
  }
  # otherwise, real screen
  move-cursor-left-on-display
  reply x:address:screen/same-as-ingredient:0
]
