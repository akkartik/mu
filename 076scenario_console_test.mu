# To check our support for consoles in scenarios, rewrite tests from
# scenario_console.mu
# Tests for console interface.

scenario read-key-in-mu [
  assume-console [
    type [abc]
  ]
  run [
    1:character, console:address:console, 2:boolean <- read-key console:address:console
    3:character, console:address:console, 4:boolean <- read-key console:address:console
    5:character, console:address:console, 6:boolean <- read-key console:address:console
    7:character, console:address:console, 8:boolean <- read-key console:address:console
  ]
  memory-should-contain [
    1 <- 97  # 'a'
    2 <- 1
    3 <- 98  # 'b'
    4 <- 1
    5 <- 99  # 'c'
    6 <- 1
    7 <- 0  # eof
    8 <- 1
  ]
]
