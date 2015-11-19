# example program: communicating between routines using channels

recipe producer chan:address:channel -> chan:address:channel [
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
    chan:address:channel <- write chan, n
    n <- add n, 1
    loop
  }
]

recipe consumer chan:address:channel -> chan:address:channel [
  # consume and print integers from a channel
  local-scope
  load-ingredients
  {
    # read an integer from the channel
    n:character, chan:address:channel <- read chan
    # other threads might get between these prints
    $print [consume: ], n:character, [ 
]
    loop
  }
]

recipe main [
  local-scope
  chan:address:channel <- new-channel 3
  # create two background 'routines' that communicate by a channel
  routine1:character <- start-running producer:recipe, chan
  routine2:character <- start-running consumer:recipe, chan
  wait-for-routine routine1
  wait-for-routine routine2
]
