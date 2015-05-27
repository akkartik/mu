# interactive prompt for mu

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  switch-to-display
  msg:address:array:character <- new [ready! type in an instruction, then hit enter. ctrl-d exits.
]
  0:literal/real-screen <- print-string 0:literal/real-screen, msg:address:array:character
  {
    inst:address:array:character, 0:literal/real-keyboard, 0:literal/real-screen <- read-instruction 0:literal/real-keyboard, 0:literal/real-screen
    break-unless inst:address:array:character
    0:literal/real-screen <- print-string 0:literal/real-screen, inst:address:array:character
    loop
  }
  wait-for-key-from-keyboard
  return-to-console
]

# basic keyboard input; just text and enter
scenario read-instruction1 [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [x <- copy y
]
  run [
    1:address:array:character <- read-instruction keyboard:address, screen:address
    2:address:array:character <- new [=> ]
    print-string screen:address, 2:address:array:character
    print-string screen:address, 1:address:array:character
  ]
  screen-should-contain [
    .x <- copy y                   .
    .=> x <- copy y                .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .x <- copy y                   .
    .=> x <- copy y                .
    .                              .
  ]
]

recipe read-instruction [
  default-space:address:array:location <- new location:type, 60:literal
  k:address:keyboard <- next-ingredient
  x:address:screen <- next-ingredient
  result:address:buffer <- init-buffer 10:literal  # string to maybe add to
  {
    c:character, k:address:keyboard <- wait-for-key k:address:keyboard
#?     $print c:character, [ 
#? ] #? 1
    print-character x:address:screen, c:character
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      reply 0:literal, k:address:keyboard/same-as-ingredient:0, x:address:screen/same-as-ingredient:1
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      reply 0:literal, k:address:keyboard/same-as-ingredient:0, x:address:screen/same-as-ingredient:1
    }
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # done with this instruction?
    done?:boolean <- equal c:character, 10:literal/newline
    break-if done?:boolean
    loop
  }
  result2:address:array:character <- buffer-to-array result:address:buffer
  reply result2:address:array:character
]
