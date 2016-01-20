# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left-2 [
  assume-screen 3/width, 2/height
  run [
    1:character <- copy 97/a
    screen:address:shared:screen <- print screen:address:shared:screen, 1:character/a
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
    1:character <- copy 97/a
    screen:address:shared:screen <- print screen:address:shared:screen, 1:character/a
    # move cursor to start of line
    screen:address:shared:screen <- move-cursor screen:address:shared:screen, 0/row, 0/column
    # clear line
    screen:address:shared:screen <- clear-line screen:address:shared:screen
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]
