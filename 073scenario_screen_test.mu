# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left-2 [
  assume-screen 3/width, 2/height
  run [
    screen:address:screen <- print-character screen:address:screen, 97/a
  ]
  screen-should-contain [
    .a  .
    .   .
  ]
]

scenario clear-line-erases-printed-characters-2 [
  assume-screen 5/width, 3/height
  run [
    # print a character
    screen:address:screen <- print-character screen:address:screen, 97/a
    # move cursor to start of line
    screen:address:screen <- move-cursor screen:address:screen, 0/row, 0/column
    # clear line
    screen:address:screen <- clear-line screen:address:screen
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]
