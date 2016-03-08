# example program: managing the display using 'screen' objects
#
# The zero screen below means 'use the real screen'. Tests can also use fake
# screens.

def main [
  open-console
  10:character <- copy 97/a
  print 0/screen, 10:character/a, 2/red
  1:number/raw, 2:number/raw <- cursor-position 0/screen
  wait-for-event 0/console
  clear-screen 0/screen
  move-cursor 0/screen, 0/row, 4/column
  10:character <- copy 98/b
  print 0/screen, 10:character
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
