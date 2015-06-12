# example program: managing the display

recipe main [
  switch-to-display
  {
    _, found?:boolean <- read-keyboard-or-mouse-event
    break-if found?:boolean
    loop
  }
  return-to-console
]
