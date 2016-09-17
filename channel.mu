# example program: communicating between routines using channels

def producer sink:&:sink:char -> sink:&:sink:char [
  # produce characters 1 to 5 on a channel
  local-scope
  load-ingredients
  # n = 0
  n:char <- copy 0
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
  close sink
]

def consumer source:&:source:char -> source:&:source:char [
  # consume and print integers from a channel
  local-scope
  load-ingredients
  {
    # read an integer from the channel
    n:char, eof?:boolean, source <- read source
    break-if eof?
    # other threads might get between these prints
    $print [consume: ], n:char, [ 
]
    loop
  }
]

def main [
  local-scope
  source:&:source:char, sink:&:sink:char <- new-channel 3/capacity
  # create two background 'routines' that communicate by a channel
  routine1:num <- start-running producer, sink
  routine2:num <- start-running consumer, source
  wait-for-routine routine1
  wait-for-routine routine2
]
