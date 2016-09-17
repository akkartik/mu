# Check our support for fake file systems in scenarios.

scenario read-from-fake-file [
  local-scope
  assume-filesystem [
    [a] <- [
      |xyz|
    ]
  ]
  contents:address:source:char <- start-reading filesystem:address:filesystem, [a]
  1:char/raw <- read contents
  2:char/raw <- read contents
  3:char/raw <- read contents
  4:char/raw <- read contents
  _, 5:bool/raw <- read contents
  memory-should-contain [
    1 <- 120  # x
    2 <- 121  # y
    3 <- 122  # z
    4 <- 10  # newline
    5 <- 1  # eof
  ]
]

scenario write-to-fake-file [
  local-scope
  assume-filesystem [
  ]
  sink:address:sink:char, writer:num/routine <- start-writing filesystem:address:filesystem, [a]
  sink <- write sink, 120/x
  sink <- write sink, 121/y
  close sink
  wait-for-routine writer
  contents-read-back:text <- slurp filesystem, [a]
  10:bool/raw <- equal contents-read-back, [xy]
  memory-should-contain [
    10 <- 1  # file contents read back exactly match what was written
  ]
]

scenario write-to-fake-file-that-exists [
  local-scope
  assume-filesystem [
    [a] <- []
  ]
  sink:address:sink:char, writer:num/routine <- start-writing filesystem:address:filesystem, [a]
  sink <- write sink, 120/x
  sink <- write sink, 121/y
  close sink
  wait-for-routine writer
  contents-read-back:text <- slurp filesystem, [a]
  10:bool/raw <- equal contents-read-back, [xy]
  memory-should-contain [
    10 <- 1  # file contents read back exactly match what was written
  ]
]

scenario write-to-existing-file-preserves-other-files [
  local-scope
  assume-filesystem [
    [a] <- []
    [b] <- [
      |bcd|
    ]
  ]
  sink:address:sink:char, writer:num/routine <- start-writing filesystem:address:filesystem, [a]
  sink <- write sink, 120/x
  sink <- write sink, 121/y
  close sink
  wait-for-routine writer
  contents-read-back:text <- slurp filesystem, [a]
  10:bool/raw <- equal contents-read-back, [xy]
  other-file-contents:text <- slurp filesystem, [b]
  11:bool/raw <- equal other-file-contents, [bcd
]
  memory-should-contain [
    10 <- 1  # file contents read back exactly match what was written
    11 <- 1  # other files also continue to persist unchanged
  ]
]

def slurp fs:address:filesystem, filename:text -> contents:text [
  local-scope
  load-ingredients
  source:address:source:char <- start-reading fs, filename
  buf:address:buffer <- new-buffer 30/capacity
  {
    c:char, done?:bool, source <- read source
    break-if done?
    buf <- append buf, c
    loop
  }
  contents <- buffer-to-array buf
]
