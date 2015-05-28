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
  {
    +next-character
    # read character
    c:character, k:address:keyboard <- wait-for-key k:address:keyboard
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
      print-character x:address:screen, c:character, 4:literal/blue
      result:address:buffer <- buffer-append result:address:buffer, c:character
      result:address:buffer, k:address:keyboard, x:address:screen <- slurp-comment result:address:buffer, k:address:keyboard, x:address:screen
      # continue appending to this instruction, whether comment ended or was backspaced out of
      loop +next-character:label
    }
    # string
    {
      string?:boolean <- equal c:character, 91:literal/open-bracket
      break-unless string?:boolean
      print-character x:address:screen, c:character, 6:literal/cyan
      result:address:buffer <- buffer-append result:address:buffer, c:character
      result:address:buffer, _, k:address:keyboard, x:address:screen <- slurp-string result:address:buffer, k:address:keyboard, x:address:screen
      loop +next-character:label
    }
    # print
    print-character x:address:screen, c:character  # default color
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # done with this instruction?
    done?:boolean <- equal c:character, 10:literal/newline
    break-if done?:boolean
    loop
  }
  result2:address:array:character <- buffer-to-array result:address:buffer
  reply result2:address:array:character, k:address:keyboard/same-as-ingredient:0, x:address:screen/same-as-ingredient:1
]

# Simpler version of read-instruction that prints in the comment color and
# doesn't handle comments or strings. Tracks an extra count in case we
# backspace out of it
recipe slurp-comment [
  default-space:address:array:location <- new location:type, 60:literal
  result:address:buffer <- next-ingredient
  k:address:keyboard <- next-ingredient
  x:address:screen <- next-ingredient
  # use this to track when backspace should reset color
  characters-slurped:number <- copy 1:literal  # for the initial '#' that's already appended to result
  {
    +next-character
    # read character
    c:character, k:address:keyboard <- wait-for-key k:address:keyboard
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      reply 0:literal, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      reply 0:literal, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
    }
    # print
    print-character x:address:screen, c:character, 4:literal/blue
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # backspace? decrement
    {
      backspace?:boolean <- equal c:character, 8:literal/backspace
      break-unless backspace?:boolean
      characters-slurped:number <- subtract characters-slurped:number, 1:literal
      {
        reset-color?:boolean <- lesser-or-equal characters-slurped:number, 0:literal
        break-unless reset-color?:boolean
        reply result:address:buffer, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
      }
      loop +next-character:label
    }
    # otherwise increment
    characters-slurped:number <- add characters-slurped:number, 1:literal
    # done with this instruction?
    done?:boolean <- equal c:character, 10:literal/newline
    break-if done?:boolean
    loop
  }
  reply result:address:buffer, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
]

# Version of read-instruction that prints in the string color and doesn't
# handle comments. Does handle nested strings. Tracks an extra count in case
# we backspace out of it, which it needs to return because recursion.
recipe slurp-string [
  default-space:address:array:location <- new location:type, 60:literal
  result:address:buffer <- next-ingredient
  k:address:keyboard <- next-ingredient
  x:address:screen <- next-ingredient
  # use this to track when backspace should reset color
  characters-slurped:number <- copy 1:literal  # for the initial '[' that's already appended to result
  {
    +next-character
    # read character
    c:character, k:address:keyboard <- wait-for-key k:address:keyboard
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      reply 0:literal, 0:literal, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      reply 0:literal, 0:literal, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
    }
    # string
    {
      string?:boolean <- equal c:character, 91:literal/open-bracket
      break-unless string?:boolean
      print-character x:address:screen, c:character, 6:literal/cyan
      result:address:buffer <- buffer-append result:address:buffer, c:character
      # make a recursive call to handle nested strings
      result:address:buffer, tmp:number, k:address:keyboard, x:address:screen <- slurp-string result:address:buffer, k:address:keyboard, x:address:screen
      # but if we backspace over a completed string handle it in the caller
      characters-slurped:number <- add characters-slurped:number, tmp:number, 1:literal  # for the leading '['
      loop +next-character:label
    }
    # print
    print-character x:address:screen, c:character, 6:literal/cyan
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # backspace? decrement
    {
      backspace?:boolean <- equal c:character, 8:literal/backspace
      break-unless backspace?:boolean
      characters-slurped:number <- subtract characters-slurped:number, 1:literal
      {
        reset-color?:boolean <- lesser-or-equal characters-slurped:number, 0:literal
        break-unless reset-color?:boolean
        reply result:address:buffer/same-as-ingredient:0, 0:literal, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
      }
      loop +next-character:label
    }
    # otherwise increment
    characters-slurped:number <- add characters-slurped:number, 1:literal
    # done with this instruction?
    done?:boolean <- equal c:character, 93:literal/close-bracket
    break-if done?:boolean
    loop
  }
  reply result:address:buffer/same-as-ingredient:0, characters-slurped:number, k:address:keyboard/same-as-ingredient:1, x:address:screen/same-as-ingredient:2
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

scenario read-instruction-color-string [
#?   $start-tracing #? 1
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc [string]
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc [string]                  .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .    [string]                  .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
  ]
]

scenario read-instruction-color-string-multiline [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc [line1
line2]
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc [line1                    .
    .line2]                        .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .    [line1                    .
    .line2]                        .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
    .                              .
  ]
]

scenario read-instruction-color-string-and-comment [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc [string]  # comment
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc [string]  # comment       .
    .                              .
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .              # comment       .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .    [string]                  .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
  ]
]

scenario read-instruction-ignore-comment-inside-string [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc [string # not a comment]
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc [string # not a comment]  .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .    [string # not a comment]  .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .                              .
    .                              .
  ]
]

scenario read-instruction-ignore-string-inside-comment [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc # comment [not a string]
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc # comment [not a string]  .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .                              .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
  ]
  screen-should-contain-in-color 4:literal/blue, [
    .    # comment [not a string]  .
    .                              .
  ]
]

scenario read-instruction-color-string-inside-string [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [abc [string [inner string]]
]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain [
    .abc [string [inner string]]   .
    .                              .
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .    [string [inner string]]   .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .abc                           .
    .                              .
  ]
]

scenario read-instruction-cancel-string-on-backspace [
  assume-screen 30:literal/width, 5:literal/height
  # need to escape the '[' once for 'scenario' and once for 'assume-keyboard'
  assume-keyboard [\\\[a<<z
]
  # setup: replace '<'s with backspace key since we can't represent backspace in strings
  run [
    buf:address:array:character <- get keyboard:address:keyboard/deref, data:offset
    first-backspace:address:character <- index-address buf:address:array:character/deref, 2:literal
    first-backspace:address:character/deref <- copy 8:literal/backspace
    second-backspace:address:character <- index-address buf:address:array:character/deref, 3:literal
    second-backspace:address:character/deref <- copy 8:literal/backspace
  ]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .                              .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .z                             .
    .                              .
  ]
]

scenario read-instruction-cancel-string-inside-string-on-backspace [
  assume-screen 30:literal/width, 5:literal/height
  assume-keyboard [\[a\[b\]<<<b\]
]
  # setup: replace '<'s with backspace key since we can't represent backspace in strings
  run [
    buf:address:array:character <- get keyboard:address:keyboard/deref, data:offset
    first-backspace:address:character <- index-address buf:address:array:character/deref, 5:literal
    first-backspace:address:character/deref <- copy 8:literal/backspace
    second-backspace:address:character <- index-address buf:address:array:character/deref, 6:literal
    second-backspace:address:character/deref <- copy 8:literal/backspace
    third-backspace:address:character <- index-address buf:address:array:character/deref, 7:literal
    third-backspace:address:character/deref <- copy 8:literal/backspace
  ]
  run [
    read-instruction keyboard:address, screen:address
  ]
  screen-should-contain-in-color 6:literal/cyan, [
    .[ab]                          .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                              .
    .                              .
  ]
]
