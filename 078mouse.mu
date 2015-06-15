exclusive-container event [
  # update the ASSUME_EVENTS handler if you add more variants
  keyboard:keyboard-event
  mouse:mouse-event
]

container keyboard-event [
  key:character
]

container mouse-event [
  type:character
  row:number
  column:number
]

container events [
  index:number
  data:address:array:event  
]

recipe read-event [
  default-space:address:array:location <- new location:type, 30:literal
  x:address:events <- next-ingredient
  {
    break-unless x:address:events
    idx:address:number <- get-address x:address:events/deref, index:offset
    buf:address:array:event <- get x:address:events/deref, data:offset
    {
      max:number <- length buf:address:array:event/deref
      done?:boolean <- greater-or-equal idx:address:number/deref, max:number
      break-unless done?:boolean
      dummy:address:event <- new event:type
      reply dummy:address:event/deref, x:address:events/same-as-ingredient:0
    }
    result:event <- index buf:address:array:event/deref, idx:address:number/deref
    idx:address:number/deref <- add idx:address:number/deref, 1:literal
    reply result:event, x:address:events/same-as-ingredient:0
  }
  # real event source
  result:event <- read-keyboard-or-mouse-event
  reply result:event
]
