# example program: managing the display

recipe main [
  switch-to-display
  print-character-to-display 97:literal, 2:literal/red
  1:number/raw, 2:number/raw <- cursor-position-on-display
  wait-for-key-from-keyboard
  clear-display
  move-cursor-on-display 0:literal, 4:literal
  print-character-to-display 98:literal
  wait-for-key-from-keyboard
  move-cursor-on-display 0:literal, 0:literal
  clear-line-on-display
  wait-for-key-from-keyboard
  move-cursor-down-on-display
  wait-for-key-from-keyboard
  move-cursor-right-on-display
  wait-for-key-from-keyboard
  move-cursor-left-on-display
  wait-for-key-from-keyboard
  move-cursor-up-on-display
  wait-for-key-from-keyboard
  return-to-console
]
