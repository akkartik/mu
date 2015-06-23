# interactive prompt for mu

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  open-console
  msg:address:array:character <- new [ready! type in an instruction, then hit enter. ctrl-d exits.
]
  0:literal/real-screen <- print-string 0:literal/real-screen, msg:address:array:character, 245:literal/grey
  0:literal/real-console, 0:literal/real-screen <- color-session 0:literal/real-console, 0:literal/real-screen
  close-console
]

recipe color-session [
  default-space:address:array:location <- new location:type, 30:literal
  console:address <- next-ingredient
  screen:address <- next-ingredient
  {
    inst:address:array:character, console:address, screen:address <- read-instruction console:address, screen:address
    break-unless inst:address:array:character
    run-interactive inst:address:array:character
    loop
  }
  reply console:address/same-as-ingredient:0, screen:address/same-as-ingredient:1
]

# basic console input; just text and enter
scenario read-instruction1 [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [x <- copy y
]
  ]
  run [
    1:address:array:character <- read-instruction console:address, screen:address
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
    .x    copy y                   .
    .=> x <- copy y                .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <-                          .
    .                              .
  ]
]

# Read characters as they're typed at the console, print them to the screen,
# accumulate them in a string, return the string at the end.
# Most of the complexity is for the printing to screen, to highlight strings
# and comments specially. Especially in the presence of backspacing.
recipe read-instruction [
  default-space:address:array:location <- new location:type, 60:literal
  console:address <- next-ingredient
  screen:address <- next-ingredient
  result:address:buffer <- new-buffer 10:literal  # string to maybe add to
  trace [app], [read-instruction]
  # start state machine by calling slurp-regular-characters, which will return
  # by calling the complete continuation
  complete:continuation <- current-continuation
  # If result is not empty, we've run slurp-regular-characters below, called
  # the continuation and so bounced back here. We're done.
  len:number <- get result:address:buffer/deref, length:offset
  completed?:boolean <- greater-than len:number, 0:literal
  jump-if completed?:boolean, +completed:label
  # Otherwise we're just getting started.
  result:address:buffer, console:address, screen:address <- slurp-regular-characters result:address:buffer, console:address, screen:address, complete:continuation
#?   $print [aaa: ], result:address:buffer #? 1
#?   move-cursor-down-on-display #? 1
  trace [error], [slurp-regular-characters should never return normally]
  +completed
  result2:address:array:character <- buffer-to-array result:address:buffer
#?   $print [bbb: ], result2:address:array:character #? 1
#?   move-cursor-down-on-display #? 1
  trace [app], [exiting read-instruction]
  reply result2:address:array:character, console:address/same-as-ingredient:0, screen:address/same-as-ingredient:1
]

# read characters from the console, print them to the screen in *white*.
# Transition to other routines for comments and strings.
recipe slurp-regular-characters [
  default-space:address:array:location <- new location:type, 30:literal
  result:address:buffer <- next-ingredient
  console:address <- next-ingredient
  screen:address <- next-ingredient
  complete:continuation <- next-ingredient
  trace [app], [slurp-regular-characters]
  characters-slurped:number <- copy 0:literal
#?   $run-depth #? 1
  {
    +next-character
    trace [app], [slurp-regular-characters: next]
#?     $print [a0 #? 1
#? ] #? 1
#?     move-cursor-down-on-display #? 1
    # read character
    c:character, console:address found?:boolean <- read-key console:address
    loop-unless found?:boolean +next-character:label
#?     print-character screen:address, c:character #? 1
#?     move-cursor-down-on-display #? 1
    # quit?
    {
#?       $print [aaa] #? 1
#?       move-cursor-down-on-display #? 1
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
#?       $print [ctrl-d] #? 1
#?       move-cursor-down-on-display #? 1
      trace [app], [slurp-regular-characters: ctrl-d]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      trace [app], [slurp-regular-characters: null]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    # comment?
    {
      comment?:boolean <- equal c:character, 35:literal/hash
      break-unless comment?:boolean
      print-character screen:address, c:character, 4:literal/blue
      result:address:buffer <- buffer-append result:address:buffer, c:character
      result:address:buffer, console:address, screen:address <- slurp-comment result:address:buffer, console:address, screen:address, complete:continuation
      # continue appending to this instruction, whether comment ended or was backspaced out of
      loop +next-character:label
    }
    # string
    {
      string?:boolean <- equal c:character, 91:literal/open-bracket
      break-unless string?:boolean
      print-character screen:address, c:character, 6:literal/cyan
      result:address:buffer <- buffer-append result:address:buffer, c:character
      result:address:buffer, _, console:address, screen:address <- slurp-string result:address:buffer, console:address, screen:address, complete:continuation
      loop +next-character:label
    }
    # assignment
    {
      assign?:boolean <- equal c:character, 60:literal/less-than
      break-unless assign?:boolean
      print-character screen:address, c:character, 1:literal/red
      trace [app], [start of assignment: <]
      result:address:buffer <- buffer-append result:address:buffer, c:character
      result:address:buffer, console:address, screen:address <- slurp-assignment result:address:buffer, console:address, screen:address, complete:continuation
      loop +next-character:label
    }
    # print
    print-character screen:address, c:character  # default color
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
#?     $print [a1 #? 1
#? ] #? 1
#?     move-cursor-down-on-display #? 1
    # backspace? decrement and maybe return
    {
#?       $print [a2 #? 1
#? ] #? 1
#?       move-cursor-down-on-display #? 1
      backspace?:boolean <- equal c:character, 8:literal/backspace
      break-unless backspace?:boolean
#?       $print [a3 #? 1
#? ] #? 1
#?       move-cursor-down-on-display #? 1
      characters-slurped:number <- subtract characters-slurped:number, 1:literal
      {
#?         $print [a4 #? 1
#? ] #? 1
#?         move-cursor-down-on-display #? 1
        done?:boolean <- lesser-or-equal characters-slurped:number, -1:literal
        break-unless done?:boolean
#?         $print [a5 #? 1
#? ] #? 1
#?         move-cursor-down-on-display #? 1
        trace [app], [slurp-regular-characters: too many backspaces; returning]
#?         $print [a6 #? 1
#? ] #? 1
#?         move-cursor-down-on-display #? 1
        reply result:address:buffer, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
      }
      loop +next-character:label
    }
#?     $print [a9 #? 1
#? ] #? 1
#?     move-cursor-down-on-display #? 1
    # otherwise increment
    characters-slurped:number <- add characters-slurped:number, 1:literal
    # done with this instruction?
    done?:boolean <- equal c:character, 10:literal/newline
    break-if done?:boolean
    loop
  }
  # newline encountered; terminate all recursive calls
#?   xx:address:array:character <- new [completing!] #? 1
#?   print-string screen:address, xx:address:array:character #? 1
  trace [app], [slurp-regular-characters: newline encountered; unwinding stack]
  continue-from complete:continuation
]

# read characters from console, print them to screen in the comment color.
#
# Simpler version of slurp-regular-characters; doesn't handle comments or
# strings. Tracks an extra count in case we backspace out of it
recipe slurp-comment [
  default-space:address:array:location <- new location:type, 30:literal
  result:address:buffer <- next-ingredient
  console:address <- next-ingredient
  screen:address <- next-ingredient
  complete:continuation <- next-ingredient
  trace [app], [slurp-comment]
  # use this to track when backspace should reset color
  characters-slurped:number <- copy 1:literal  # for the initial '#' that's already appended to result
  {
    +next-character
    # read character
    c:character, console:address, found?:boolean <- read-key console:address
    loop-unless found?:boolean +next-character:label
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      trace [app], [slurp-comment: ctrl-d]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      trace [app], [slurp-comment: null]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    # print
    print-character screen:address, c:character, 4:literal/blue
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
        trace [app], [slurp-comment: too many backspaces; returning]
        reply result:address:buffer, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
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
  trace [app], [slurp-regular-characters: newline encountered; unwinding stack]
  continue-from complete:continuation
]

# read characters from console, print them to screen in the string color and
# accumulate them into a buffer.
#
# Version of slurp-regular-characters that:
#   a) doesn't handle comments
#   b) handles nested strings using recursive calls to itself. Tracks an extra
#   count in case we backspace out of it.
recipe slurp-string [
  default-space:address:array:location <- new location:type, 30:literal
  result:address:buffer <- next-ingredient
  console:address <- next-ingredient
  screen:address <- next-ingredient
  complete:continuation <- next-ingredient
  nested-string?:boolean <- next-ingredient
  trace [app], [slurp-string]
  # use this to track when backspace should reset color
  characters-slurped:number <- copy 1:literal  # for the initial '[' that's already appended to result
  {
    +next-character
    # read character
    c:character, console:address, found?:boolean <- read-key console:address
    loop-unless found?:boolean +next-character:label
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      trace [app], [slurp-string: ctrl-d]
      reply 0:literal, 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      trace [app], [slurp-string: null]
      reply 0:literal, 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    # string
    {
      string?:boolean <- equal c:character, 91:literal/open-bracket
      break-unless string?:boolean
      trace [app], [slurp-string: open-bracket encountered; recursing]
      print-character screen:address, c:character, 6:literal/cyan
      result:address:buffer <- buffer-append result:address:buffer, c:character
      # make a recursive call to handle nested strings
      result:address:buffer, tmp:number, console:address, screen:address <- slurp-string result:address:buffer, console:address, screen:address, complete:continuation, 1:literal/nested?
      # but if we backspace over a completed nested string, handle it in the caller
      characters-slurped:number <- add characters-slurped:number, tmp:number, 1:literal  # for the leading '['
      loop +next-character:label
    }
    # print
    print-character screen:address, c:character, 6:literal/cyan
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
        trace [app], [slurp-string: too many backspaces; returning]
        reply result:address:buffer/same-as-ingredient:0, 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
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
  {
    break-unless nested-string?:boolean
    # nested string? return like a normal recipe
    reply result:address:buffer, characters-slurped:number, console:address, screen:address
  }
  # top-level string call? recurse
  trace [app], [slurp-string: close-bracket encountered; recursing to regular characters]
  result:address:buffer, console:address, screen:address <- slurp-regular-characters result:address:buffer, console:address, screen:address, complete:continuation
  # backspaced back into this string
  trace [app], [slurp-string: backspaced back into string; restarting]
  jump +next-character:label
]

recipe slurp-assignment [
  default-space:address:array:location <- new location:type, 30:literal
  result:address:buffer <- next-ingredient
  console:address <- next-ingredient
  screen:address <- next-ingredient
  complete:continuation <- next-ingredient
  {
    +next-character
    # read character
    c:character, console:address, found?:boolean <- read-key console:address
    loop-unless found?:boolean +next-character:label
    # quit?
    {
      ctrl-d?:boolean <- equal c:character, 4:literal/ctrl-d/eof
      break-unless ctrl-d?:boolean
      trace [app], [slurp-assignment: ctrl-d]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    {
      null?:boolean <- equal c:character, 0:literal/null
      break-unless null?:boolean
      trace [app], [slurp-assignment: null]
      reply 0:literal, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
    # print
    print-character screen:address, c:character, 1:literal/red
    trace [app], [slurp-assignment: saved one character]
    # append
    result:address:buffer <- buffer-append result:address:buffer, c:character
    # backspace? return
    {
      backspace?:boolean <- equal c:character, 8:literal/backspace
      break-unless backspace?:boolean
      trace [app], [slurp-assignment: backspace; returning]
      reply result:address:buffer/same-as-ingredient:0, console:address/same-as-ingredient:1, screen:address/same-as-ingredient:2
    }
  }
  trace [app], [slurp-assignment: done, recursing to regular characters]
  result:address:buffer, console:address, screen:address <- slurp-regular-characters result:address:buffer, console:address, screen:address, complete:continuation
  # backspaced back into this string
  trace [app], [slurp-assignment: backspaced back into assignment; restarting]
  jump +next-character:label
]

scenario read-instruction-color-comment [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [# comment]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [#a]
    press 8  # backspace
    press 8  # backspace
    type [z]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [#ab]
    press 8  # backspace
    press 8  # backspace
    press 8  # backspace
    type [z]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [#a]
    press 8  # backspace
    type [z]
  ]
  run [
    read-instruction console:address, screen:address
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

scenario read-instruction-stop-after-comment [
  assume-screen 30:literal/width, 5:literal/height
  # console contains comment and then a second line
  assume-console [
    type [#abc
3]
  ]
  run [
    read-instruction console:address, screen:address
  ]
  # check that read-instruction reads just the comment
  screen-should-contain [
    .#abc                          .
    .                              .
  ]
]

scenario read-instruction-color-string [
#?   $start-tracing #? 1
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [abc [string]]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [abc [line1
line2]]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [abc [string]  # comment]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [abc [string # not a comment]]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [abc # comment [not a string]]
  ]
  run [
    read-instruction console:address, screen:address
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
  assume-console [
    type [abc [string [inner string]]]
  ]
  run [
#?     $start-tracing #? 1
    read-instruction console:address, screen:address
#?     $stop-tracing #? 1
#?     $browse-trace #? 1
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
  # need to escape the '[' once for 'scenario' and once for 'assume-console'
  assume-console [
    type [\\\\\[a]
    press 8  # backspace
    type [z]
  ]
  run [
#?     d:address:array:event <- get console:address/deref, data:offset #? 1
#?     $print [a: ], d:address:array:event #? 1
#?     x:number <- length d:address:array:event/deref #? 1
#?     $print [b: ], x:number #? 1
    read-instruction console:address, screen:address
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
  assume-console [
    type [\\\\\[a[b]]
    press 8  # backspace
    press 8  # backspace
    press 8  # backspace
    type [b\\\\\]]
  ]
  run [
    read-instruction console:address, screen:address
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

scenario read-instruction-backspace-back-into-string [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [[a]]
    press 8  # backspace
    type [b]
  ]
  run [
    read-instruction console:address, screen:address
  ]
  screen-should-contain [
    .\\\[ab                           .
    .                              .
  ]
#?   $print [aaa] #? 1
  screen-should-contain-in-color 6:literal/cyan, [
    .\\\[ab                           .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .                              .
    .                              .
  ]
  # todo: trace sequence of events
  #   slurp-regular-characters: [
  #   slurp-regular-characters/slurp-string: a
  #   slurp-regular-characters/slurp-string: ]
  #   slurp-regular-characters/slurp-string/slurp-regular-characters: backspace
  #   slurp-regular-characters/slurp-string: b
]

scenario read-instruction-highlight-start-of-assignment [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [a <]
  ]
  run [
    read-instruction console:address, screen:address
  ]
  screen-should-contain [
    .a <                           .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <                           .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .a                             .
    .                              .
  ]
]

scenario read-instruction-highlight-assignment [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [a <- b]
  ]
  run [
    read-instruction console:address, screen:address
  ]
  screen-should-contain [
    .a <- b                        .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <-                          .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .a    b                        .
    .                              .
  ]
]

scenario read-instruction-backspace-over-assignment [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [a <-]
    press 8  # backspace
  ]
  run [
    read-instruction console:address, screen:address
  ]
  screen-should-contain [
    .a <                           .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <                           .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .a                             .
    .                              .
  ]
]

scenario read-instruction-assignment-continues-after-backspace [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [a <-]
    press 8  # backspace
    type [-]
  ]
#?   $print [aaa] #? 1
  run [
    read-instruction console:address, screen:address
  ]
  screen-should-contain [
    .a <-                          .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <-                          .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .a                             .
    .                              .
  ]
]

scenario read-instruction-assignment-continues-after-backspace2 [
  assume-screen 30:literal/width, 5:literal/height
  assume-console [
    type [a <- ]
    press 8  # backspace
    press 8  # backspace
    type [-]
  ]
  run [
    read-instruction console:address, screen:address
#?     $browse-trace #? 1
  ]
  screen-should-contain [
    .a <-                          .
    .                              .
  ]
  screen-should-contain-in-color 1:literal/red, [
    .  <-                          .
    .                              .
  ]
  screen-should-contain-in-color 7:literal/white, [
    .a                             .
    .                              .
  ]
]
