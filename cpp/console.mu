recipe main [
  cursor-mode 0:literal/screen
  print-character-to-display 97:literal
  1:integer/raw, 2:integer/raw <- cursor-position-on-display
  $print 1:integer/raw
  $print [, ]
  $print 2:integer/raw
  $print [
]
  wait-for-key-from-keyboard
  clear-display
  move-cursor-on-display 0:literal, 4:literal
  print-character-to-display 98:literal
  wait-for-key-from-keyboard
  move-cursor-on-display 0:literal, 0:literal
  clear-line-on-display
  wait-for-key-from-keyboard
  retro-mode 0:literal/screen
]
