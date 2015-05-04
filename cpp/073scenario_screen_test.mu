# To check our support for screens in scenarios, rewrite tests from print.mu

scenario print-character-at-top-left2 [
  assume-screen 3:literal/width, 2:literal/height
  run [
    screen:address <- print-character screen:address, 97:literal  # 'a'
  ]
  screen-should-contain [
    .a  .
    .   .
  ]
]

scenario clear-line-erases-printed-characters2 [
  assume-screen 5:literal/width, 3:literal/height
  run [
    # print a character
    screen:address <- print-character screen:address, 97:literal  # 'a'
    # move cursor to start of line
    screen:address <- move-cursor screen:address, 0:literal/row, 0:literal/column
    # clear line
    screen:address <- clear-line screen:address
  ]
  screen-should-contain [
    .     .
    .     .
    .     .
  ]
]
