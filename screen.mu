# example program: managing the display using 'screen' objects
#
# The zero screen below means 'use the real screen'. Tests can also use fake
# screens.

recipe main [
  open-console
  print-character 0:literal/screen, 97:literal, 2:literal/red
  1:number/raw, 2:number/raw <- cursor-position 0:literal/screen
  wait-for-event 0:literal/console
  clear-screen 0:literal/screen
  move-cursor 0:literal/screen, 0:literal/row, 4:literal/column
  print-character 0:literal/screen, 98:literal
  wait-for-event 0:literal/console
  move-cursor 0:literal/screen, 0:literal/row, 0:literal/column
  clear-line 0:literal/screen
  wait-for-event 0:literal/console
  cursor-down 0:literal/screen
  wait-for-event 0:literal/console
  cursor-right 0:literal/screen
  wait-for-event 0:literal/console
  cursor-left 0:literal/screen
  wait-for-event 0:literal/console
  cursor-up 0:literal/screen
  wait-for-event 0:literal/console
  close-console
]
