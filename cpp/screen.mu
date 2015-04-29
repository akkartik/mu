# example of recipes for working with screen objects
recipe main [
  switch-to-display
  print-character 0:literal/screen, 97:literal
  1:integer/raw, 2:integer/raw <- cursor-position 0:literal/screen
  wait-for-key-from-keyboard
  clear-screen 0:literal/screen
  move-cursor 0:literal/screen, 0:literal/row, 4:literal/column
  print-character 0:literal/screen, 98:literal
  wait-for-key-from-keyboard
  move-cursor 0:literal/screen, 0:literal/row, 0:literal/column
  clear-line 0:literal/screen
  wait-for-key-from-keyboard
  cursor-down 0:literal/screen
  wait-for-key-from-keyboard
  cursor-right 0:literal/screen
  wait-for-key-from-keyboard
  cursor-left 0:literal/screen
  wait-for-key-from-keyboard
  cursor-up 0:literal/screen
  wait-for-key-from-keyboard
  return-to-console
]
