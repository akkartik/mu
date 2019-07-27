# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left-2 [
  local-scope
  assume-screen 3/width, 2/height
  run [
    a:char <- copy 97/a
    screen <- print screen, a
  ]
  screen-should-contain [
    .a  .
    .   .
  ]
]

scenario clear-line-erases-printed-characters-2 [
  local-scope
  assume-screen 5/width, 3/height
  # print a character
  a:char <- copy 97/a
  screen <- print screen, a
  # move cursor to start of line
  screen <- move-cursor screen, 0/row, 0/column
  run [
    screen <- clear-line screen
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]

scenario scroll-screen [
  local-scope
  assume-screen 3/width, 2/height
  run [
    a:char <- copy 97/a
    move-cursor screen, 1/row, 2/column
    screen <- print screen, a
    screen <- print screen, a
  ]
  screen-should-contain [
    .  a.
    .a  .
  ]
]
