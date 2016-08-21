# Check our support for fake file systems in scenarios.

scenario read-from-fake-file [
  local-scope
  assume-filesystem [
    [a] <- [
      |xyz|
    ]
  ]
  contents:address:source:character <- start-reading filesystem:address:filesystem, [a]
  1:character/raw <- read contents
  2:character/raw <- read contents
  3:character/raw <- read contents
  4:character/raw <- read contents
  _, 5:boolean/raw <- read contents
  memory-should-contain [
    1 <- 120  # x
    2 <- 121  # y
    3 <- 122  # z
    4 <- 10  # newline
    5 <- 1  # eof
  ]
]
