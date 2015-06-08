recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  switch-to-display
  draw-bounding-box 0:literal/screen, 5:literal, 5:literal, 30:literal, 45:literal
  wait-for-key-from-keyboard
  return-to-console
]

recipe draw-bounding-box [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
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
