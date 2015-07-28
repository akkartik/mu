# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left2 [
  assume-screen 3/width, 2/height
  run [
    screen:address <- print-character screen:address, 97/a
  ]
  screen-should-contain [
    .a  .
    .   .
  ]
]

scenario clear-line-erases-printed-characters2 [
  assume-screen 5/width, 3/height
  run [
    # print a character
    screen:address <- print-character screen:address, 97/a
    # move cursor to start of line
    screen:address <- move-cursor screen:address, 0/row, 0/column
    # clear line
    screen:address <- clear-line screen:address
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]
