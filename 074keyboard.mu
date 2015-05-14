# Wrappers around keyboard primitives that take a 'keyboard' object and are thus
# easier to test.

container keyboard [  # can't think of another word like screen/display, so real and fake keyboards use the same name
  index:number
  data:address:array:character
]

recipe init-fake-keyboard [
  default-space:address:array:location <- new location:type, 30:literal
  result:address:keyboard <- new keyboard:type
  buf:address:address:array:character <- get-address result:address:keyboard/deref, data:offset
#?   $start-tracing #? 1
  buf:address:address:array:character/deref <- next-ingredient
#?   $stop-tracing #? 1
  idx:address:number <- get-address result:address:keyboard/deref, index:offset
  idx:address:number/deref <- copy 0:literal
  reply result:address:keyboard
]

recipe read-key [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:keyboard <- next-ingredient
  {
    break-unless x:address:keyboard
    idx:address:number <- get-address x:address:keyboard/deref, index:offset
    buf:address:array:character <- get x:address:keyboard/deref, data:offset
    max:number <- length buf:address:array:character/deref
    {
      done?:boolean <- greater-or-equal idx:address:number/deref, max:number
      break-unless done?:boolean
      reply 0:literal/eof, 1:literal/found, x:address:keyboard/same-as-ingredient:0
    }
    c:character <- index buf:address:array:character/deref, idx:address:number/deref
    idx:address:number/deref <- add idx:address:number/deref, 1:literal
    reply c:character, 1:literal/found, x:address:keyboard/same-as-ingredient:0
  }
  # real keyboard input is infrequent; avoid polling it too much
  switch
  c:character, found?:boolean <- read-key-from-keyboard
  reply c:character, found?:boolean, x:address:keyboard/same-as-ingredient:0
]

recipe wait-for-key [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:keyboard <- next-ingredient
  {
    break-unless x:address:keyboard
    # on fake keyboards 'wait-for-key' behaves just like 'read-key'
    c:character, x:address:keyboard <- read-key x:address:keyboard
    reply c:character, x:address:keyboard/same-as-ingredient:0
  }
  c:character <- wait-for-key-from-keyboard
  reply c:character, x:address:keyboard/same-as-ingredient:0
]

recipe send-keys-to-channel [
  default-space:address:array:location <- new location:type, 30:literal
  keyboard:address <- next-ingredient
  chan:address:channel <- next-ingredient
  screen:address <- next-ingredient
  {
    c:character, found?:boolean <- read-key keyboard:address
    loop-unless found?:boolean
#?     print-integer screen:address, c:character #? 1
    print-character screen:address, c:character
    chan:address:channel <- write chan:address:channel, c:character
    # todo: eof
    loop
  }
]
