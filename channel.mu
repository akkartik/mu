# example program: communicating between routines using channels

def producer chan:address:shared:channel -> chan:address:shared:channel [
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
    chan:address:shared:channel <- write chan, n
    n <- add n, 1
    loop
  }
]

def consumer chan:address:shared:channel -> chan:address:shared:channel [
  # consume and print integers from a channel
  local-scope
  load-ingredients
  {
    # read an integer from the channel
    n:character, chan:address:shared:channel <- read chan
    # other threads might get between these prints
    $print [consume: ], n:character, [ 
]
    loop
  }
]

def main [
  local-scope
  chan:address:shared:channel <- new-channel 3
  # create two background 'routines' that communicate by a channel
  routine1:number <- start-running producer, chan
  routine2:number <- start-running consumer, chan
  wait-for-routine routine1
  wait-for-routine routine2
]
