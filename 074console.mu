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
  default-space:address:array:location <- new location:type, 30:literal
  result:address:console <- new console:type
  buf:address:address:array:character <- get-address result:address:console/deref, data:offset
#?   $start-tracing #? 1
  buf:address:address:array:character/deref <- next-ingredient
#?   $stop-tracing #? 1
  idx:address:number <- get-address result:address:console/deref, index:offset
  idx:address:number/deref <- copy 0:literal
  reply result:address:console
]

recipe read-event [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:console <- next-ingredient
  {
    break-unless x:address:console
    idx:address:number <- get-address x:address:console/deref, index:offset
    buf:address:array:event <- get x:address:console/deref, data:offset
    {
      max:number <- length buf:address:array:event/deref
      done?:boolean <- greater-or-equal idx:address:number/deref, max:number
      break-unless done?:boolean
      dummy:address:event <- new event:type
      reply dummy:address:event/deref, x:address:console/same-as-ingredient:0, 1:literal/found, 1:literal/quit
    }
    result:event <- index buf:address:array:event/deref, idx:address:number/deref
    idx:address:number/deref <- add idx:address:number/deref, 1:literal
    reply result:event, x:address:console/same-as-ingredient:0, 1:literal/found, 0:literal/quit
  }
  # real event source is infrequent; avoid polling it too much
  switch
  result:event, found?:boolean <- check-for-interaction
  reply result:event, x:address:console/same-as-ingredient:0, found?:boolean, 0:literal/quit
]

# variant of read-event for just keyboard events. Discards everything that
# isn't unicode, so no arrow keys, page-up/page-down, etc. But you still get
# newlines, tabs, ctrl-d..
recipe read-key [
  default-space:address:array:location <- new location:type, 30:literal
#?   $print default-space:address:array:location #? 1
#?   $exit #? 1
#?   $start-tracing #? 1
  console:address <- next-ingredient
  x:event, console:address, found?:boolean, quit?:boolean <- read-event console:address
#?   $print [aaa 1] #? 1
  reply-if quit?:boolean, 0:literal, console:address/same-as-ingredient:0, found?:boolean, quit?:boolean
#?   $print [aaa 2] #? 1
  reply-unless found?:boolean, 0:literal, console:address/same-as-ingredient:0, found?:boolean, quit?:boolean
#?   $print [aaa 3] #? 1
  c:address:character <- maybe-convert x:event, text:variant
  reply-unless c:address:character, 0:literal, console:address/same-as-ingredient:0, 0:literal/found, 0:literal/quit
#?   $print [aaa 4] #? 1
  reply c:address:character/deref, console:address/same-as-ingredient:0, 1:literal/found, 0:literal/quit
]

recipe send-keys-to-channel [
  default-space:address:array:location <- new location:type, 30:literal
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
  default-space:address:array:location <- new location:type, 30:literal
  console:address <- next-ingredient
  {
    _, console:address, found?:boolean <- read-event console:address
    loop-unless found?:boolean
  }
]

# use this helper to skip rendering if there's lots of other events queued up
recipe has-more-events? [
  default-space:address:array:location <- new location:type, 30:literal
  console:address <- next-ingredient
  {
    break-unless console:address
    # fake consoles should be plenty fast; never skip
    reply 0:literal/false
  }
  result:boolean <- interactions-left?
  reply result:boolean
]
