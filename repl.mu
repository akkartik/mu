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
  # certain keys may trigger a change in the color
  color:number <- copy 7:literal/white
  # use this to track when backspace should reset color
  current-color-count:number <- copy 0:literal
  {
    +next-character
    # read character
    c:character, k:address:keyboard <- wait-for-key k:address:keyboard
#?     $print [next character: ], c:character, [ 
#? ] #? 2
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
    # comment?
    {
      comment?:boolean <- equal c:character, 35:literal/hash
      break-unless comment?:boolean
      color:number <- copy 4:literal/blue
      # start new color count; don't need to save old color since it's guaranteed to be white
      current-color-count:number <- copy 0:literal
      # fall through
    }
    # print
    print-character x:address:screen, c:character, color:number
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # backspace? decrement
    {
      backspace?:boolean <- equal c:character, 8:literal/backspace
      break-unless backspace?:boolean
      current-color-count:number <- subtract current-color-count:number, 1:literal
#?       $print [decremented to ], current-color-count:number, [ 
#? ] #? 1
      {
        reset-color?:boolean <- lesser-or-equal current-color-count:number, 0:literal
        break-unless reset-color?:boolean
#?         $print [resetting color
#?   ] #? 1
        color:number <- copy 7:literal/white
        current-color-count:number <- copy 0:literal  # doesn't matter what count is when the color is white
      }
      loop +next-character:label
    }
    # otherwise increment
    current-color-count:number <- add current-color-count:number, 1:literal
#?     $print [incremented to ], current-color-count:number, [ 
#? ] #? 1
    # done with this instruction?
    done?:boolean <- equal c:character, 10:literal/newline
    break-if done?:boolean
    loop
  }
  result2:address:array:character <- buffer-to-array result:address:buffer
  reply result2:address:array:character, k:address:keyboard, x:address:screen
]

scenario read-instruction-color-comment [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [# comment
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .# comment                     .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                              .
    .                              .
  ]
]

scenario read-instruction-cancel-comment-on-backspace [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [#a<<z
]
  # setup: replace '<'s with backspace key since we can't represent backspace in strings
  run [
    buf:address:array:character <- get keyboard:address:keyboard/deref, data:offset
    first:address:character <- index-address buf:address:array:character/deref, 2:literal
    first:address:character/deref <- copy 8:literal/backspace
    second:address:character <- index-address buf:address:array:character/deref, 3:literal
    second:address:character/deref <- copy 8:literal/backspace
  ]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .                              .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .z                             .
    .                              .
  ]
]

scenario read-instruction-cancel-comment-on-backspace2 [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [#ab<<<z
]
  # setup: replace '<'s with backspace key since we can't represent backspace in strings
  run [
    buf:address:array:character <- get keyboard:address:keyboard/deref, data:offset
    first:address:character <- index-address buf:address:array:character/deref, 3:literal
    first:address:character/deref <- copy 8:literal/backspace
    second:address:character <- index-address buf:address:array:character/deref, 4:literal
    second:address:character/deref <- copy 8:literal/backspace
    third:address:character <- index-address buf:address:array:character/deref, 5:literal
    third:address:character/deref <- copy 8:literal/backspace
  ]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .                              .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .z                             .
    .                              .
  ]
]

scenario read-instruction-cancel-comment-on-backspace3 [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [#a<z
]
  # setup: replace '<'s with backspace key since we can't represent backspace in strings
  run [
    buf:address:array:character <- get keyboard:address:keyboard/deref, data:offset
    first:address:character <- index-address buf:address:array:character/deref, 2:literal
    first:address:character/deref <- copy 8:literal/backspace
  ]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .#z                            .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                              .
    .                              .
  ]
]
