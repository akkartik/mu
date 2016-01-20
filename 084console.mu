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
  current-event-index:number
  events:address:shared:array:event
]

recipe new-fake-console events:address:shared:array:event -> result:address:shared:console [
  local-scope
  load-ingredients
  result:address:shared:console <- new console:type
  buf:address:address:shared:array:event <- get-address *result, events:offset
  *buf <- copy events
  idx:address:number <- get-address *result, current-event-index:offset
  *idx <- copy 0
]

recipe read-event console:address:shared:console -> result:event, console:address:shared:console, found?:boolean, quit?:boolean [
  local-scope
  load-ingredients
  {
    break-unless console
    current-event-index:address:number <- get-address *console, current-event-index:offset
    buf:address:shared:array:event <- get *console, events:offset
    {
      max:number <- length *buf
      done?:boolean <- greater-or-equal *current-event-index, max
      break-unless done?
      dummy:address:shared:event <- new event:type
      reply *dummy, console/same-as-ingredient:0, 1/found, 1/quit
    }
    result <- index *buf, *current-event-index
    *current-event-index <- add *current-event-index, 1
    reply result, console/same-as-ingredient:0, 1/found, 0/quit
  }
  switch  # real event source is infrequent; avoid polling it too much
  result:event, found?:boolean <- check-for-interaction
  reply result, console/same-as-ingredient:0, found?, 0/quit
]

# variant of read-event for just keyboard events. Discards everything that
# isn't unicode, so no arrow keys, page-up/page-down, etc. But you still get
# newlines, tabs, ctrl-d..
recipe read-key console:address:shared:console -> result:character, console:address:shared:console, found?:boolean, quit?:boolean [
  local-scope
  load-ingredients
  x:event, console, found?:boolean, quit?:boolean <- read-event console
  reply-if quit?, 0, console/same-as-ingredient:0, found?, quit?
  reply-unless found?, 0, console/same-as-ingredient:0, found?, quit?
  c:address:character <- maybe-convert x, text:variant
  reply-unless c, 0, console/same-as-ingredient:0, 0/found, 0/quit
  reply *c, console/same-as-ingredient:0, 1/found, 0/quit
]

recipe send-keys-to-channel console:address:shared:console, chan:address:shared:channel, screen:address:shared:screen -> console:address:shared:console, chan:address:shared:channel, screen:address:shared:screen [
  local-scope
  load-ingredients
  {
    c:character, console, found?:boolean, quit?:boolean <- read-key console
    loop-unless found?
    break-if quit?
    assert c, [invalid event, expected text]
    screen <- print screen, c
    chan <- write chan, c
    loop
  }
]

recipe wait-for-event console:address:shared:console -> console:address:shared:console [
  local-scope
  load-ingredients
  {
    _, console, found?:boolean <- read-event console
    loop-unless found?
  }
]

# use this helper to skip rendering if there's lots of other events queued up
recipe has-more-events? console:address:shared:console -> result:boolean [
  local-scope
  load-ingredients
  {
    break-unless console
    # fake consoles should be plenty fast; never skip
    reply 0/false
  }
  result <- interactions-left?
]
