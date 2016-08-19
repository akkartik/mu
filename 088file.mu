# Wrappers around file-system primitives that take a 'filesystem' object and
# are thus easier to test.

container filesystem [
  {data: (address table (address array character) (address array character))}
]

def start-reading fs:address:filesystem, filename:address:array:character -> contents:address:source:character [
  local-scope
  load-ingredients
  file:number <- $open-file-for-reading filename
  contents:address:source:character, sink:address:sink:character <- new-channel 30
  start-running transmit-from-file file, sink
]

def transmit-from-file file:number, sink:address:sink:character -> file:number, sink:address:sink:character [
  local-scope
  load-ingredients
  {
    c:character <- $read-from-file file
    break-unless c
    sink <- write sink, c
    loop
  }
  sink <- close sink
  $close-file file
]

def start-writing fs:address:filesystem, filename:address:array:character -> sink:address:sink:character, routine-id:number [
  local-scope
  load-ingredients
  file:number <- $open-file-for-writing filename
  source:address:source:character, sink:address:sink:character <- new-channel 30
  routine-id <- start-running transmit-to-file file, source
]

def transmit-to-file file:number, source:address:source:character -> file:number, source:address:source:character [
  local-scope
  load-ingredients
  {
    c:character, done?:boolean, source <- read source
    break-if done?
    $write-to-file file, c
    loop
  }
  $close-file file
]
