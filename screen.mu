# example program: managing the display using 'screen' objects
#
# The zero screen below means 'use the real screen'. Tests can also use fake
# screens.

recipe main [
  open-console
  print-character 0/screen, 97/a, 2/red
  1:number/raw, 2:number/raw <- cursor-position 0/screen
  wait-for-event 0/console
  clear-screen 0/screen
  move-cursor 0/screen, 0/row, 4/column
  print-character 0/screen, 98/b
  wait-for-event 0/console
  move-cursor 0/screen, 0/row, 0/column
  clear-line 0/screen
  wait-for-event 0/console
  cursor-down 0/screen
  wait-for-event 0/console
  cursor-right 0/screen
  wait-for-event 0/console
  cursor-left 0/screen
  wait-for-event 0/console
  cursor-up 0/screen
  wait-for-event 0/console
  close-console
]
