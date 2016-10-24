# Wrappers around interaction primitives that take a potentially fake object
# and are thus easier to test.

exclusive-container event [
  text:char
  keycode:num  # keys on keyboard without a unicode representation
  touch:touch-event  # mouse, track ball, etc.
  resize:resize-event
  # update the assume-console handler if you add more variants
]

container touch-event [
  type:num
  row:num
  column:num
]

container resize-event [
  width:num
  height:num
]

container console [
  current-event-index:num
  events:&:@:event
]

def new-fake-console events:&:@:event -> result:&:console [
  local-scope
  load-ingredients
  result:&:console <- new console:type
  *result <- put *result, events:offset, events
]

def read-event console:&:console -> result:event, found?:bool, quit?:bool, console:&:console [
  local-scope
  load-ingredients
  {
    break-unless console
    current-event-index:num <- get *console, current-event-index:offset
    buf:&:@:event <- get *console, events:offset
    {
      max:num <- length *buf
      done?:bool <- greater-or-equal current-event-index, max
      break-unless done?
      dummy:&:event <- new event:type
      return *dummy, 1/found, 1/quit
    }
    result <- index *buf, current-event-index
    current-event-index <- add current-event-index, 1
    *console <- put *console, current-event-index:offset, current-event-index
    return result, 1/found, 0/quit
  }
  switch  # real event source is infrequent; avoid polling it too much
  result:event, found?:bool <- check-for-interaction
  return result, found?, 0/quit
]

# variant of read-event for just keyboard events. Discards everything that
# isn't unicode, so no arrow keys, page-up/page-down, etc. But you still get
# newlines, tabs, ctrl-d..
def read-key console:&:console -> result:char, found?:bool, quit?:bool, console:&:console [
  local-scope
  load-ingredients
  x:event, found?:bool, quit?:bool, console <- read-event console
  return-if quit?, 0, found?, quit?
  return-unless found?, 0, found?, quit?
  c:char, converted?:bool <- maybe-convert x, text:variant
  return-unless converted?, 0, 0/found, 0/quit
  return c, 1/found, 0/quit
]

def send-keys-to-channel console:&:console, chan:&:sink:char, screen:&:screen -> console:&:console, chan:&:sink:char, screen:&:screen [
  local-scope
  load-ingredients
  {
    c:char, found?:bool, quit?:bool, console <- read-key console
    loop-unless found?
    break-if quit?
    assert c, [invalid event, expected text]
    screen <- print screen, c
    chan <- write chan, c
    loop
  }
  chan <- close chan
]

def wait-for-event console:&:console -> console:&:console [
  local-scope
  load-ingredients
  {
    _, found?:bool <- read-event console
    break-if found?
    switch
    loop
  }
]

# use this helper to skip rendering if there's lots of other events queued up
def has-more-events? console:&:console -> result:bool [
  local-scope
  load-ingredients
  return-if console, 0/false  # fake consoles should be plenty fast; never skip
  result <- interactions-left?
]
