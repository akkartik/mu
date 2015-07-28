# example program: communicating between routines using channels

recipe producer [
  # produce numbers 1 to 5 on a channel
  local-scope
  chan:address:channel <- next-ingredient
  # n = 0
  n:number <- copy 0
  {
    done?:boolean <- lesser-than n:number, 5
    break-unless done?:boolean
    # other threads might get between these prints
    $print [produce: ], n:number, [ 
]
    chan:address:channel <- write chan:address:channel, n:number
    n:number <- add n:number, 1
    loop
  }
]

recipe consumer [
  # consume and print integers from a channel
  local-scope
  chan:address:channel <- next-ingredient
  {
    # read an integer from the channel
    n:number, chan:address:channel <- read chan:address:channel
    # other threads might get between these prints
    $print [consume: ], n:number, [ 
]
    loop
  }
]

recipe main [
  local-scope
  chan:address:channel <- new-channel 3
  # create two background 'routines' that communicate by a channel
  routine1:number <- start-running producer:recipe, chan:address:channel
  routine2:number <- start-running consumer:recipe, chan:address:channel
  wait-for-routine routine1:number
  wait-for-routine routine2:number
]
