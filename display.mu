# example program: managing the display

def main [
  open-console
  print-character-to-display 97, 1/red, 2/green
  1:number/raw, 2:number/raw <- cursor-position-on-display
  wait-for-some-interaction
  clear-display
  move-cursor-on-display 0, 4
  print-character-to-display 98
  wait-for-some-interaction
  move-cursor-on-display 0, 0
  clear-line-on-display
  wait-for-some-interaction
  move-cursor-down-on-display
  wait-for-some-interaction
  move-cursor-right-on-display
  wait-for-some-interaction
  move-cursor-left-on-display
  wait-for-some-interaction
  move-cursor-up-on-display
  wait-for-some-interaction
  close-console
]
