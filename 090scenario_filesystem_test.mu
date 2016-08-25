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

scenario write-to-fake-file [
  local-scope
  assume-filesystem [
    #[a] <- []
  ]
  sink:address:sink:character, writer:number/routine <- start-writing filesystem:address:filesystem, [a]
  sink <- write sink, 120/x
  sink <- write sink, 121/y
  close sink
  wait-for-routine writer
  contents-read-back:address:array:character <- slurp filesystem, [a]
  10:boolean/raw <- equal contents-read-back, [xy]
  memory-should-contain [
    10 <- 1  # file contents read back exactly match what was written
  ]
]

def slurp fs:address:filesystem, filename:address:array:character -> contents:address:array:character [
  local-scope
  load-ingredients
  source:address:source:character <- start-reading fs, filename
  buf:address:buffer <- new-buffer 30/capacity
  {
    c:character, done?:boolean, source <- read source
    break-if done?
    buf <- append buf, c
    loop
  }
  contents <- buffer-to-array buf
]
