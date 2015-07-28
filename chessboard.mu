# Chessboard program: you type in moves in algebraic notation, and it'll
# display the position after each move.

# recipes are mu's names for functions
recipe main [
  open-console  # take control of screen, keyboard and mouse

  # The chessboard recipe takes keyboard and screen objects as 'ingredients'.
  #
  # In mu it is good form (though not required) to explicitly show the
  # hardware you rely on.
  #
  # The chessboard also returns the same keyboard and screen objects. In mu it
  # is good form to not modify ingredients of a recipe unless they are also
  # results. Here we clearly modify both keyboard and screen, so we return
  # both.
  #
  # Here the console and screen are both 0, which usually indicates real
  # hardware rather than a fake for testing as you'll see below.
  0/screen, 0/console <- chessboard 0/screen, 0/console

  close-console  # cleanup screen, keyboard and mouse
]

## But enough about mu. Here's what it looks like to run the chessboard program.

scenario print-board-and-read-move [
  $close-trace  # administrivia: most scenarios save and check traces, but this one gets too large/slow
  # we'll make the screen really wide because the program currently prints out a long line
  assume-screen 120/width, 20/height
  # initialize keyboard to type in a move
  assume-console [
    type [a2-a4
]
  ]
  run [
    screen:address, console:address <- chessboard screen:address, console:address
#?     $browse-trace #? 1
#?     $close-trace #? 1
    # icon for the cursor
    screen:address <- print-character screen:address, 9251/␣
  ]
  screen-should-contain [
  #            1         2         3         4         5         6         7         8         9         10        11
  #  012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
    .Stupid text-mode chessboard. White pieces in uppercase; black pieces in lowercase. No checking for legal moves.         .
    .                                                                                                                        .
    .8 | r n b q k b n r                                                                                                     .
    .7 | p p p p p p p p                                                                                                     .
    .6 |                                                                                                                     .
    .5 |                                                                                                                     .
    .4 | P                                                                                                                   .
    .3 |                                                                                                                     .
    .2 |   P P P P P P P                                                                                                     .
    .1 | R N B Q K B N R                                                                                                     .
    .  +----------------                                                                                                     .
    .    a b c d e f g h                                                                                                     .
    .                                                                                                                        .
    .Type in your move as <from square>-<to square>. For example: 'a2-a4'. Then press <enter>.                               .
    .                                                                                                                        .
    .Hit 'q' to exit.                                                                                                        .
    .                                                                                                                        .
    .move: ␣                                                                                                                 .
    .                                                                                                                        .
    .                                                                                                                        .
  ]
]

## Here's how 'chessboard' is implemented.

recipe chessboard [
#?   $start-tracing [schedule] #? 2
#?   $start-tracing #? 1
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
#?   $print [screen: ], screen:address, [, console: ], console:address, 10/newline
  board:address:array:address:array:character <- initial-position
  # hook up stdin
  stdin:address:channel <- new-channel 10/capacity
  start-running send-keys-to-channel:recipe, console:address, stdin:address:channel, screen:address
  # buffer lines in stdin
  buffered-stdin:address:channel <- new-channel 10/capacity
  start-running buffer-lines:recipe, stdin:address:channel, buffered-stdin:address:channel
  {
    msg:address:array:character <- new [Stupid text-mode chessboard. White pieces in uppercase; black pieces in lowercase. No checking for legal moves.
]
    print-string screen:address, msg:address:array:character
    cursor-to-next-line screen:address
    print-board screen:address, board:address:array:address:array:character
    cursor-to-next-line screen:address
    msg:address:array:character <- new [Type in your move as <from square>-<to square>. For example: 'a2-a4'. Then press <enter>.
]
    print-string screen:address, msg:address:array:character
    cursor-to-next-line screen:address
    msg:address:array:character <- new [Hit 'q' to exit.
]
    print-string screen:address, msg:address:array:character
    {
      cursor-to-next-line screen:address
      msg:address:array:character <- new [move: ]
      print-string screen:address, msg:address:array:character
      m:address:move, quit:boolean, error:boolean <- read-move buffered-stdin:address:channel, screen:address
      break-if quit:boolean, +quit:offset
      buffered-stdin:address:channel <- clear-channel buffered-stdin:address:channel  # cleanup after error. todo: test this?
      loop-if error:boolean
    }
    board:address:array:address:array:character <- make-move board:address:array:address:array:character, m:address:move
    clear-screen screen:address
    loop
  }
  +quit
]

## a board is an array of files, a file is an array of characters (squares)

recipe new-board [
  local-scope
  initial-position:address:array:number <- next-ingredient
  # assert(length(initial-position) == 64)
  len:number <- length initial-position:address:array:number/deref
  correct-length?:boolean <- equal len:number, 64
  assert correct-length?:boolean, [chessboard had incorrect size]
  # board is an array of pointers to files; file is an array of characters
  board:address:array:address:array:character <- new location:type, 8
  col:number <- copy 0
  {
    done?:boolean <- equal col:number, 8
    break-if done?:boolean
    file:address:address:array:character <- index-address board:address:array:address:array:character/deref, col:number
    file:address:address:array:character/deref <- new-file initial-position:address:array:number, col:number
    col:number <- add col:number, 1
    loop
  }
  reply board:address:array:address:array:character
]

recipe new-file [
  local-scope
  position:address:array:number <- next-ingredient
  index:number <- next-ingredient
  index:number <- multiply index:number, 8
  result:address:array:character <- new character:type, 8
  row:number <- copy 0
  {
    done?:boolean <- equal row:number, 8
    break-if done?:boolean
    dest:address:character <- index-address result:address:array:character/deref, row:number
    dest:address:character/deref <- index position:address:array:number/deref, index:number
    row:number <- add row:number, 1
    index:number <- add index:number, 1
    loop
  }
  reply result:address:array:character
]

recipe print-board [
  local-scope
  screen:address <- next-ingredient
  board:address:array:address:array:character <- next-ingredient
  row:number <- copy 7  # start printing from the top of the board
  # print each row
#?   $print [printing board to screen ], screen:address, 10/newline
  {
    done?:boolean <- lesser-than row:number, 0
    break-if done?:boolean
#?     $print [printing rank ], row:number, 10/newline
    # print rank number as a legend
    rank:number <- add row:number, 1
    print-integer screen:address, rank:number
    s:address:array:character <- new [ | ]
    print-string screen:address, s:address:array:character
    # print each square in the row
    col:number <- copy 0
    {
      done?:boolean <- equal col:number, 8
      break-if done?:boolean
      f:address:array:character <- index board:address:array:address:array:character/deref, col:number
      c:character <- index f:address:array:character/deref, row:number
      print-character screen:address, c:character
      print-character screen:address, 32/space
      col:number <- add col:number, 1
      loop
    }
    row:number <- subtract row:number, 1
    cursor-to-next-line screen:address
    loop
  }
  # print file letters as legend
#?   $print [printing legend
#? ] #? 1
  s:address:array:character <- new [  +----------------]
  print-string screen:address, s:address:array:character
  screen:address <- cursor-to-next-line screen:address
#?   screen:address <- print-character screen:address, 97 #? 1
  s:address:array:character <- new [    a b c d e f g h]
  screen:address <- print-string screen:address, s:address:array:character
  screen:address <- cursor-to-next-line screen:address
#?   $print [done printing board
#? ] #? 1
]

# board:address:array:address:array:character <- initial-position
recipe initial-position [
  local-scope
  # layout in memory (in raster order):
  #   R P _ _ _ _ p r
  #   N P _ _ _ _ p n
  #   B P _ _ _ _ p b
  #   Q P _ _ _ _ p q
  #   K P _ _ _ _ p k
  #   B P _ _ _ _ p B
  #   N P _ _ _ _ p n
  #   R P _ _ _ _ p r
  initial-position:address:array:number <- new-array 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 81/Q, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 113/q, 75/K, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 107/k, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r
#?       82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r,
#?       78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n,
#?       66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 
#?       81/Q, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 113/q,
#?       75/K, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 107/k,
#?       66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b,
#?       78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n,
#?       82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r
  board:address:array:address:array:character <- new-board initial-position:address:array:number
  reply board:address:array:address:array:character
]

scenario printing-the-board [
  assume-screen 30/width, 12/height
  run [
    1:address:array:address:array:character/board <- initial-position
    screen:address <- print-board screen:address, 1:address:array:address:array:character/board
#?     $dump-screen #? 1
  ]
  screen-should-contain [
  #  012345678901234567890123456789
    .8 | r n b q k b n r           .
    .7 | p p p p p p p p           .
    .6 |                           .
    .5 |                           .
    .4 |                           .
    .3 |                           .
    .2 | P P P P P P P P           .
    .1 | R N B Q K B N R           .
    .  +----------------           .
    .    a b c d e f g h           .
    .                              .
    .                              .
  ]
]

## data structure: move

container move [
  # valid range: 0-7
  from-file:number
  from-rank:number
  to-file:number
  to-rank:number
]

# result:address:move, quit?:boolean, error?:boolean <- read-move stdin:address:channel, screen:address
# prints only error messages to screen
recipe read-move [
  local-scope
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
#?   $print screen:address #? 1
  from-file:number, quit?:boolean, error?:boolean <- read-file stdin:address:channel, screen:address
  reply-if quit?:boolean, 0/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0/dummy, quit?:boolean, error?:boolean
#?   close-console #? 1
  # construct the move object
  result:address:move <- new move:type
  x:address:number <- get-address result:address:move/deref, from-file:offset
  x:address:number/deref <- copy from-file:number
  x:address:number <- get-address result:address:move/deref, from-rank:offset
  x:address:number/deref, quit?:boolean, error?:boolean <- read-rank stdin:address:channel, screen:address
  reply-if quit?:boolean, 0/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0/dummy, quit?:boolean, error?:boolean
  error?:boolean <- expect-from-channel stdin:address:channel, 45/dash, screen:address
  reply-if error?:boolean, 0/dummy, 0/quit, error?:boolean
  x:address:number <- get-address result:address:move/deref, to-file:offset
  x:address:number/deref, quit?:boolean, error?:boolean <- read-file stdin:address:channel, screen:address
  reply-if quit?:boolean, 0/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0/dummy, quit?:boolean, error?:boolean
  x:address:number <- get-address result:address:move/deref, to-rank:offset
  x:address:number/deref, quit?:boolean, error?:boolean <- read-rank stdin:address:channel, screen:address
  reply-if quit?:boolean, 0/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0/dummy, quit?:boolean, error?:boolean
#?   $exit #? 1
  error?:boolean <- expect-from-channel stdin:address:channel, 10/newline, screen:address
  reply-if error?:boolean, 0/dummy, 0/quit, error?:boolean
  reply result:address:move, quit?:boolean, error?:boolean
]

# file:number, quit:boolean, error:boolean <- read-file stdin:address:channel, screen:address
# valid values for file: 0-7
recipe read-file [
  local-scope
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 81/Q
    break-unless q-pressed?:boolean
    reply 0/dummy, 1/quit, 0/error
  }
  {
    q-pressed?:boolean <- equal c:character, 113/q
    break-unless q-pressed?:boolean
    reply 0/dummy, 1/quit, 0/error
  }
  {
    empty-fake-keyboard?:boolean <- equal c:character, 0/eof
    break-unless empty-fake-keyboard?:boolean
    reply 0/dummy, 1/quit, 0/error
  }
  {
    newline?:boolean <- equal c:character, 10/newline
    break-unless newline?:boolean
    error-message:address:array:character <- new [that's not enough]
    print-string screen:address, error-message:address:array:character
    reply 0/dummy, 0/quit, 1/error
  }
  file:number <- subtract c:character, 97/a
#?   $print file:number, 10/newline
  # 'a' <= file <= 'h'
  {
    above-min:boolean <- greater-or-equal file:number, 0
    break-if above-min:boolean
    error-message:address:array:character <- new [file too low: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    cursor-to-next-line screen:address
    reply 0/dummy, 0/quit, 1/error
  }
  {
    below-max:boolean <- lesser-than file:number, 8
    break-if below-max:boolean
    error-message:address:array:character <- new [file too high: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0/dummy, 0/quit, 1/error
  }
  reply file:number, 0/quit, 0/error
]

# rank:number <- read-rank stdin:address:channel, screen:address
# valid values: 0-7, -1 (quit), -2 (error)
recipe read-rank [
  local-scope
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 8/Q
    break-unless q-pressed?:boolean
    reply 0/dummy, 1/quit, 0/error
  }
  {
    q-pressed?:boolean <- equal c:character, 113/q
    break-unless q-pressed?:boolean
    reply 0/dummy, 1/quit, 0/error
  }
  {
    newline?:boolean <- equal c:character, 10  # newline
    break-unless newline?:boolean
    error-message:address:array:character <- new [that's not enough]
    print-string screen:address, error-message:address:array:character
    reply 0/dummy, 0/quit, 1/error
  }
  rank:number <- subtract c:character, 49/'1'
#?   $print rank:number, 10/newline
  # assert'1' <= rank <= '8'
  {
    above-min:boolean <- greater-or-equal rank:number, 0
    break-if above-min:boolean
    error-message:address:array:character <- new [rank too low: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0/dummy, 0/quit, 1/error
  }
  {
    below-max:boolean <- lesser-or-equal rank:number, 7
    break-if below-max:boolean
    error-message:address:array:character <- new [rank too high: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0/dummy, 0/quit, 1/error
  }
  reply rank:number, 0/quit, 0/error
]

# read a character from the given channel and check that it's what we expect
# return true on error
recipe expect-from-channel [
  local-scope
  stdin:address:channel <- next-ingredient
  expected:character <- next-ingredient
  screen:address <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  match?:boolean <- equal c:character, expected:character
  {
    break-if match?:boolean
    s:address:array:character <- new [expected character not found]
    print-string screen:address, s:address:array:character
  }
  result:boolean <- not match?:boolean
  reply result:boolean
]

scenario read-move-blocking [
  assume-screen 20/width, 2/height
  run [
#?     $start-tracing #? 1
    1:address:channel <- new-channel 2
#?     $print [aaa channel address: ], 1:address:channel, 10/newline
    2:number/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:number
#?     $print [bbb channel address: ], 1:address:channel, 10/newline
    3:number <- routine-state 2:number/id
#?     $print [I: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after coming up (before any keys were pressed)]
    # press 'a'
#?     $print [ccc channel address: ], 1:address:channel, 10/newline
#?     $exit #? 1
    1:address:channel <- write 1:address:channel, 97/a
    restart 2:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
#?     $print [II: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after rank 'a']
    # press '2'
    1:address:channel <- write 1:address:channel, 50/'2'
    restart 2:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
#?     $print [III: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after file 'a2']
    # press '-'
    1:address:channel <- write 1:address:channel, 45/'-'
    restart 2:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number
#?     $print [IV: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?/routine-state, [
F read-move-blocking: routine failed to pause after hyphen 'a2-']
    # press 'a'
    1:address:channel <- write 1:address:channel, 97/a
    restart 2:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number
#?     $print [V: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?/routine-state, [
F read-move-blocking: routine failed to pause after rank 'a2-a']
    # press '4'
    1:address:channel <- write 1:address:channel, 52/'4'
    restart 2:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number
#?     $print [VI: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after file 'a2-a4']
    # press 'newline'
    1:address:channel <- write 1:address:channel, 10  # newline
    restart 2:number/routine
    # 'read-move' now completes
    wait-for-routine 2:number
    3:number <- routine-state 2:number
#?     $print [VII: routine ], 2:number, [ state ], 3:number 10/newline
    4:boolean/completed? <- equal 3:number/routine-state, 1/completed
    assert 4:boolean/completed?, [
F read-move-blocking: routine failed to terminate on newline]
    trace [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-quit [
  assume-screen 20/width, 2/height
  run [
    1:address:channel <- new-channel 2
    2:number/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-quit: routine failed to pause after coming up (before any keys were pressed)]
    # press 'q'
    1:address:channel <- write 1:address:channel, 113/q
    restart 2:number/routine
    # 'read-move' completes
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
    4:boolean/completed? <- equal 3:number/routine-state, 1/completed
    assert 4:boolean/completed?, [
F read-move-quit: routine failed to terminate on 'q']
    trace [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-illegal-file [
  assume-screen 20/width, 2/height
  run [
    1:address:channel <- new-channel 2
    2:number/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 50/'2'
    restart 2:number/routine
    wait-for-routine 2:number
  ]
  screen-should-contain [
    .file too low: 2     .
    .                    .
  ]
]

scenario read-move-illegal-rank [
  assume-screen 20/width, 2/height
  run [
    1:address:channel <- new-channel 2
    2:number/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 97/a
    1:address:channel <- write 1:address:channel, 97/a
    restart 2:number/routine
    wait-for-routine 2:number
  ]
  screen-should-contain [
    .rank too high: a    .
    .                    .
  ]
]

scenario read-move-empty [
  assume-screen 20/width, 2/height
  run [
    1:address:channel <- new-channel 2
    2:number/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:number
    3:number <- routine-state 2:number/id
    4:boolean/waiting? <- equal 3:number/routine-state, 2/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 10/newline
    1:address:channel <- write 1:address:channel, 97/a
    restart 2:number/routine
    wait-for-routine 2:number
  ]
  screen-should-contain [
    .that's not enough   .
    .                    .
  ]
]

recipe make-move [
  local-scope
  b:address:array:address:array:character <- next-ingredient
  m:address:move <- next-ingredient
  from-file:number <- get m:address:move/deref, from-file:offset
#?   $print from-file:number, 10/newline
  from-rank:number <- get m:address:move/deref, from-rank:offset
#?   $print from-rank:number, 10/newline
  to-file:number <- get m:address:move/deref, to-file:offset
#?   $print to-file:number, 10/newline
  to-rank:number <- get m:address:move/deref, to-rank:offset
#?   $print to-rank:number, 10/newline
  f:address:array:character <- index b:address:array:address:array:character/deref, from-file:number
  src:address:character/square <- index-address f:address:array:character/deref, from-rank:number
  f:address:array:character <- index b:address:array:address:array:character/deref, to-file:number
  dest:address:character/square <- index-address f:address:array:character/deref, to-rank:number
#?   $print src:address:character/deref, 10/newline
  dest:address:character/deref/square <- copy src:address:character/deref/square
  src:address:character/deref/square <- copy 32/space
  reply b:address:array:address:array:character/same-as-ingredient:0
]

scenario making-a-move [
  assume-screen 30/width, 12/height
  run [
    2:address:array:address:array:character/board <- initial-position
    3:address:move <- new move:type
    4:address:number <- get-address 3:address:move/deref, from-file:offset
    4:address:number/deref <- copy 6/g
    5:address:number <- get-address 3:address:move/deref, from-rank:offset
    5:address:number/deref <- copy 1/'2'
    6:address:number <- get-address 3:address:move/deref, to-file:offset
    6:address:number/deref <- copy 6/g
    7:address:number <- get-address 3:address:move/deref, to-rank:offset
    7:address:number/deref <- copy 3/'4'
    2:address:array:address:array:character/board <- make-move 2:address:array:address:array:character/board, 3:address:move
    screen:address <- print-board screen:address, 2:address:array:address:array:character/board
  ]
  screen-should-contain [
  #  012345678901234567890123456789
    .8 | r n b q k b n r           .
    .7 | p p p p p p p p           .
    .6 |                           .
    .5 |                           .
    .4 |             P             .
    .3 |                           .
    .2 | P P P P P P   P           .
    .1 | R N B Q K B N R           .
    .  +----------------           .
    .    a b c d e f g h           .
    .                              .
  ]
]
