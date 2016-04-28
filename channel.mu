# example program: communicating between routines using channels

def producer sink:address:sink:character -> sink:address:sink:character [
  # produce characters 1 to 5 on a channel
  local-scope
  load-ingredients
  # n = 0
  n:character <- copy 0
  {
    done?:boolean <- lesser-than n, 5
    break-unless done?
    # other threads might get between these prints
    $print [produce: ], n, [ 
]
    sink <- write sink, n
    n <- add n, 1
    loop
  }
]

def consumer source:address:source:character -> source:address:source:character [
  # consume and print integers from a channel
  local-scope
  load-ingredients
  {
    # read an integer from the channel
    n:character, eof?:boolean, source <- read source
    break-if eof?
    # other threads might get between these prints
    $print [consume: ], n:character, [ 
]
    loop
  }
]

def main [
  local-scope
  source:address:source:character, sink:address:sink:character <- new-channel 3/capacity
  # create two background 'routines' that communicate by a channel
  routine1:number <- start-running producer, sink
  routine2:number <- start-running consumer, source
  wait-for-routine routine1
  wait-for-routine routine2
]
