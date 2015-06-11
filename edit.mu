recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  switch-to-display
  width:number <- display-width
  {
    wide-enough?:boolean <- greater-than width:number, 100:literal
    break-if wide-enough?:boolean
    return-to-console
    assert wide-enough?:boolean, [screen too narrow; we don't support less than 100 characters yet]
  }
  divider:number, _ <- divide-with-remainder width:number, 2:literal
  draw-column 0:literal/screen, divider:number
  x:address:array:character <- new [1:integer <- add 2:literal, 2:literal]
  y:address:array:character <- edit x:address:array:character, 0:literal/screen, 0:literal, 0:literal, 5:literal, divider:number
#?   draw-bounding-box 0:literal/screen, 0:literal, 0:literal, 5:literal, divider:number
  left:number <- add divider:number, 1:literal
  y:address:array:character <- edit 0:literal, 0:literal/screen, 0:literal, left:number, 2:literal, width:number
  move-cursor 0:literal/screen, 0:literal, 0:literal
  wait-for-key-from-keyboard
  return-to-console
]

recipe draw-column [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  col:number <- next-ingredient
  curr:number <- copy 0:literal
  max:number <- screen-height screen:address
  {
    continue?:boolean <- lesser-than curr:number, max:number
    break-unless continue?:boolean
    move-cursor screen:address, curr:number, col:number
    print-character screen:address, 9474:literal/vertical, 245:literal/grey
    curr:number <- add curr:number, 1:literal
    loop
  }
  move-cursor screen:address, 0:literal, 0:literal
]

recipe edit [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:array:character <- next-ingredient
  screen:address <- next-ingredient
  top:number <- next-ingredient
  left:number <- next-ingredient
  bottom:number <- next-ingredient
  right:number <- next-ingredient
  # draw bottom boundary
  curr:number <- copy left:number
  {
    continue?:boolean <- lesser-than curr:number, right:number
    break-unless continue?:boolean
    move-cursor screen:address, bottom:number, curr:number
    print-character screen:address, 9472:literal/vertical, 245:literal/grey
    curr:number <- add curr:number, 1:literal
    loop
  }
  move-cursor screen:address, top:number, left:number
]

recipe draw-bounding-box [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  # sanity-check the box bounds
  top:number <- next-ingredient
  {
    out?:boolean <- lesser-than top:number, 0:literal
    break-unless out?:boolean
    top:number <- copy 0:literal
  }
  left:number <- next-ingredient
  {
    out?:boolean <- lesser-than left:number, 0:literal
    break-unless out?:boolean
    left:number <- copy 0:literal
  }
  bottom:number <- next-ingredient
  {
    height:number <- screen-height screen:address
    out?:boolean <- greater-or-equal bottom:number, height:number
    break-unless out?:boolean
    bottom:number <- subtract height:number, 1:literal
  }
  right:number <- next-ingredient
  {
    width:number <- screen-width screen:address
    out?:boolean <- greater-or-equal right:number, width:number
    break-unless out?:boolean
    right:number <- subtract width:number, 1:literal
  }
#?   print-integer screen:address, bottom:number
#?   print-character screen:address, 32:literal/space
#?   print-integer screen:address, right:number
  # top border
  move-cursor screen:address, top:number, left:number
  print-character screen:address, 9484:literal/down-right, 245:literal/grey
  x:number <- add left:number, 1:literal  # exclude corner
  {
    continue?:boolean <- lesser-than x:number, right:number
    break-unless continue?:boolean
    print-character screen:address, 9472:literal/horizontal, 245:literal/grey
    x:number <- add x:number, 1:literal
    loop
  }
  print-character screen:address, 9488:literal/down-left, 245:literal/grey
  # bottom border
  move-cursor screen:address, bottom:number, left:number
  print-character screen:address, 9492:literal/up-right, 245:literal/grey
  x:number <- add left:number, 1:literal  # exclude corner
  {
    continue?:boolean <- lesser-than x:number, right:number
    break-unless continue?:boolean
    print-character screen:address, 9472:literal/horizontal, 245:literal/grey
    x:number <- add x:number, 1:literal
    loop
  }
  print-character screen:address, 9496:literal/up-left, 245:literal/grey
  # left and right borders
  x:number <- add top:number, 1:literal  # exclude corner
  {
    continue?:boolean <- lesser-than x:number, bottom:number
    break-unless continue?:boolean
    move-cursor screen:address, x:number, left:number
    print-character screen:address, 9474:literal/vertical, 245:literal/grey
    move-cursor screen:address, x:number, right:number
    print-character screen:address, 9474:literal/vertical, 245:literal/grey
    x:number <- add x:number, 1:literal
    loop
  }
  # position cursor inside box
  move-cursor screen:address, top:number, left:number
  cursor-down screen:address
  cursor-right screen:address
]
