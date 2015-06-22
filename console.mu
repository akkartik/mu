# example program: reading events from keyboard or mouse
#
# Keeps printing 'a' until you press a key or click on the mouse.

recipe main [
  open-console
  {
    _, found?:boolean <- check-for-interaction
    break-if found?:boolean
    print-character-to-display 97:literal, 7:literal/white
    loop
  }
  close-console
]
