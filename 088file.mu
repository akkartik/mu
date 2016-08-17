# Wrappers around file-system primitives that take a 'filesystem' object and
# are thus easier to test.

container filesystem [
  {data: (address table (address array character) (address array character))}
]

def start-reading fs:address:filesystem, filename:address:array:character -> contents:address:source:character [
  local-scope
  load-ingredients
  x:number/file <- $open-file-for-reading filename
  contents:address:source:character, sink:address:sink:character <- new-channel 30
  $print [sink: ], sink, 10/newline
  chan:address:channel:character <- get *sink, chan:offset
  $print [chan in start-reading: ], chan, 10/newline
  start-running transmit x, sink
]

def transmit file:number, sink:address:sink:character -> file:number, sink:address:sink:character [
  local-scope
  load-ingredients
  {
    c:character <- $read-from-file file
    break-unless c
    sink <- write sink, c
    loop
  }
  $print [closing chan after reading file], 10/newline
  sink <- close sink
  $print [returning from 'transmit'], 10/newline
]
