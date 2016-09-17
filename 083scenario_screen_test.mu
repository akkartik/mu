# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left-2 [
  assume-screen 3/width, 2/height
  run [
    local-scope
    a:char <- copy 97/a
    screen:&:screen <- print screen:&:screen, a
  ]
  screen-should-contain [
    .a  .
    .   .
  ]
]

scenario clear-line-erases-printed-characters-2 [
  assume-screen 5/width, 3/height
  run [
    local-scope
    # print a character
    a:char <- copy 97/a
    screen:&:screen <- print screen:&:screen, a
    # move cursor to start of line
    screen:&:screen <- move-cursor screen:&:screen, 0/row, 0/column
    # clear line
    screen:&:screen <- clear-line screen:&:screen
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]
