# Wrappers around interaction primitives that take a potentially fake object
# and are thus easier to test.

exclusive-container event [
  text:character
  keycode:number  # keys on keyboard without a unicode representation
  touch:touch-event  # mouse, track ball, etc.
  # update the assume-console handler if you add more variants
]

container touch-event [
  type:number
  row:number
  column:number
]

container console [
  index:number
  data:address:array:event
]

recipe new-fake-console [
  local-scope
  result:address:console <- new console:type
  buf:address:address:array:character <- get-address result:address:console/lookup, data:offset
#?   $start-tracing #? 1
  buf:address:address:array:character/lookup <- next-ingredient
#?   $stop-tracing #? 1
  idx:address:number <- get-address result:address:console/lookup, index:offset
  idx:address:number/lookup <- copy 0
  reply result:address:console
]

recipe read-event [
  local-scope
  x:address:console <- next-ingredient
  {
    break-unless x:address:console
    idx:address:number <- get-address x:address:console/lookup, index:offset
    buf:address:array:event <- get x:address:console/lookup, data:offset
    {
      max:number <- length buf:address:array:event/lookup
      done?:boolean <- greater-or-equal idx:address:number/lookup, max:number
      break-unless done?:boolean
      dummy:address:event <- new event:type
      reply dummy:address:event/lookup, x:address:console/same-as-ingredient:0, 1/found, 1/quit
    }
    result:event <- index buf:address:array:event/lookup, idx:address:number/lookup
    idx:address:number/lookup <- add idx:address:number/lookup, 1
    reply result:event, x:address:console/same-as-ingredient:0, 1/found, 0/quit
  }
  # real event source is infrequent; avoid polling it too much
  switch
  result:event, found?:boolean <- check-for-interaction
  reply result:event, x:address:console/same-as-ingredient:0, found?:boolean, 0/quit
]

# variant of read-event for just keyboard events. Discards everything that
# isn't unicode, so no arrow keys, page-up/page-down, etc. But you still get
# newlines, tabs, ctrl-d..
recipe read-key [
  local-scope
#?   $print default-space:address:array:location #? 1
#?   $exit #? 1
#?   $start-tracing #? 1
  console:address <- next-ingredient
  x:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
#?   $print [aaa 1] #? 1
  reply-if quit?:boolean, 0, console:address/same-as-ingredient:0, found?:boolean, quit?:boolean
#?   $print [aaa 2] #? 1
  reply-unless found?:boolean, 0, console:address/same-as-ingredient:0, found?:boolean, quit?:boolean
#?   $print [aaa 3] #? 1
  c:address:character <- maybe-convert x:event, text:variant
  reply-unless c:address:character, 0, console:address/same-as-ingredient:0, 0/found, 0/quit
#?   $print [aaa 4] #? 1
  reply c:address:character/lookup, console:address/same-as-ingredient:0, 1/found, 0/quit
]

recipe send-keys-to-channel [
  local-scope
  console:address <- next-ingredient
  chan:address:channel <- next-ingredient
  screen:address <- next-ingredient
  {
    c:character, console:address, found?:boolean, quit?:boolean <- read-key console:address
    loop-unless found?:boolean
    break-if quit?:boolean
    assert c:character, [invalid event, expected text]
    print-character screen:address, c:character
    chan:address:channel <- write chan:address:channel, c:character
    loop
  }
]

recipe wait-for-event [
  local-scope
  console:address <- next-ingredient
  {
    _, console:address, found?:boolean <- read-event console:address
    loop-unless found?:boolean
  }
]

# use this helper to skip rendering if there's lots of other events queued up
recipe has-more-events? [
  local-scope
  console:address <- next-ingredient
  {
    break-unless console:address
    # fake consoles should be plenty fast; never skip
    reply 0/false
  }
  result:boolean <- interactions-left?
  reply result:boolean
]
