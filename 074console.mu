# Wrappers around interaction primitives that take a potentially fake object
# and are thus easier to test.

exclusive-container event [
  text:character
  keycode:number  # keys on keyboard without a unicode representation
  touch:touch-event  # mouse, track ball, etc.
  resize:resize-event
  # update the assume-console handler if you add more variants
]

container touch-event [
  type:number
  row:number
  column:number
]

container resize-event [
  width:number
  height:number
]

container console [
  index:number
  data:address:array:event
]

recipe new-fake-console [
  local-scope
  result:address:console <- new console:type
  buf:address:address:array:character <- get-address *result, data:offset
  *buf <- next-ingredient
  idx:address:number <- get-address *result, index:offset
  *idx <- copy 0
  reply result
]

recipe read-event [
  local-scope
  x:address:console <- next-ingredient
  {
    break-unless x
    idx:address:number <- get-address *x, index:offset
    buf:address:array:event <- get *x, data:offset
    {
      max:number <- length *buf
      done?:boolean <- greater-or-equal *idx, max
      break-unless done?
      dummy:address:event <- new event:type
      reply *dummy, x/same-as-ingredient:0, 1/found, 1/quit
    }
    result:event <- index *buf, *idx
    *idx <- add *idx, 1
    reply result, x/same-as-ingredient:0, 1/found, 0/quit
  }
  # real event source is infrequent; avoid polling it too much
  switch
  result:event, found?:boolean <- check-for-interaction
  reply result, x/same-as-ingredient:0, found?, 0/quit
]

# variant of read-event for just keyboard events. Discards everything that
# isn't unicode, so no arrow keys, page-up/page-down, etc. But you still get
# newlines, tabs, ctrl-d..
recipe read-key [
  local-scope
  console:address <- next-ingredient
  x:event, console, found?:boolean, quit?:boolean <- read-event console
  reply-if quit?, 0, console/same-as-ingredient:0, found?, quit?
  reply-unless found?, 0, console/same-as-ingredient:0, found?, quit?
  c:address:character <- maybe-convert x, text:variant
  reply-unless c, 0, console/same-as-ingredient:0, 0/found, 0/quit
  reply *c, console/same-as-ingredient:0, 1/found, 0/quit
]

recipe send-keys-to-channel [
  local-scope
  console:address <- next-ingredient
  chan:address:channel <- next-ingredient
  screen:address <- next-ingredient
  {
    c:character, console, found?:boolean, quit?:boolean <- read-key console
    loop-unless found?
    break-if quit?
    assert c, [invalid event, expected text]
    screen <- print-character screen, c
    chan <- write chan, c
    loop
  }
  reply console/same-as-ingredient:0, chan/same-as-ingredient:1, screen/same-as-ingredient:2
]

recipe wait-for-event [
  local-scope
  console:address <- next-ingredient
  {
    _, console, found?:boolean <- read-event console
    loop-unless found?
  }
  reply console/same-as-ingredient:0
]

# use this helper to skip rendering if there's lots of other events queued up
recipe has-more-events? [
  local-scope
  console:address <- next-ingredient
  {
    break-unless console
    # fake consoles should be plenty fast; never skip
    reply 0/false
  }
  result:boolean <- interactions-left?
  reply result
]
