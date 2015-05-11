# example program: communicating between routines using channels

recipe producer [
  # produce numbers 1 to 5 on a channel
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  # n = 0
  n:integer <- copy 0:literal
  {
    done?:boolean <- lesser-than n:integer, 5:literal
    break-unless done?:boolean
    # other threads might get between these prints
    $print [produce: ], n:integer, [ 
]
    chan:address:channel <- write chan:address:channel, n:integer
    n:integer <- add n:integer, 1:literal
    loop
  }
]

recipe consumer [
  # consume and print integers from a channel
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  {
    # read an integer from the channel
    n:integer, chan:address:channel <- read chan:address:channel
    # other threads might get between these prints
    $print [consume: ], n:integer, [ 
]
    loop
  }
]

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- init-channel 3:literal
  # create two background 'routines' that communicate by a channel
  routine1:integer <- start-running producer:recipe, chan:address:channel
  routine2:integer <- start-running consumer:recipe, chan:address:channel
  wait-for-routine routine1:integer
  wait-for-routine routine2:integer
]
