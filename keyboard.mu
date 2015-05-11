# example program: reading keys from keyboard
#
# Keeps printing 'a' until you press a key. Then prints the key you pressed
# and exits.

recipe main [
  switch-to-display
  {
    c:character, found?:boolean <- read-key-from-keyboard
    break-if found?:boolean
    print-character-to-display 97:literal
    loop
  }
  return-to-console
]
