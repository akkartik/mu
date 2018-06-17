# example program: managing the display using 'screen' objects

# The zero screen below means 'use the real screen'. Tests can also use fake
# screens.
def main [
  open-console
  clear-screen null/screen  # non-scrolling app
  10:char <- copy 97/a
  print null/screen, 10:char/a, 1/red, 2/green
  1:num/raw, 2:num/raw <- cursor-position null/screen
  wait-for-event null/console
  clear-screen null/screen
  move-cursor null/screen, 0/row, 4/column
  10:char <- copy 98/b
  print null/screen, 10:char
  wait-for-event null/console
  move-cursor null/screen, 0/row, 0/column
  clear-line null/screen
  wait-for-event null/console
  cursor-down null/screen
  wait-for-event null/console
  cursor-right null/screen
  wait-for-event null/console
  cursor-left null/screen
  wait-for-event null/console
  cursor-up null/screen
  wait-for-event null/console
  close-console
]
