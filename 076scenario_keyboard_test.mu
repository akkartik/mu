# To check our support for keyboards in scenarios, rewrite tests from
# scenario_keyboard.mu
# Tests for keyboard interface.

scenario read-key-in-mu [
  assume-keyboard [abc]
  run [
    1:character, 2:boolean, keyboard:address <- read-key keyboard:address
    3:character, 4:boolean, keyboard:address <- read-key keyboard:address
    5:character, 6:boolean, keyboard:address <- read-key keyboard:address
    7:character, 8:boolean, keyboard:address <- read-key keyboard:address
  ]
  memory-should-contain [
    1 <- 97  # 'a'
    2 <- 1  # first read-key call found a character
    3 <- 98  # 'b'
    4 <- 1  # second read-key call found a character
    5 <- 99  # 'c'
    6 <- 1  # third read-key call found a character
    7 <- 0
    8 <- 0  # fourth read-key call didn't find a character
  ]
]
