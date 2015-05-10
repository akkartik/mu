# chessboard program: takes moves in algebraic notation and displays the
# position after each

## a board is an array of files, a file is an array of characters (squares)
recipe init-board [
  default-space:address:array:location <- new location:type, 30:literal
  initial-position:address:array:integer <- next-ingredient
  # assert(length(initial-position) == 64)
  len:integer <- length initial-position:address:array:integer/deref
  correct-length?:boolean <- equal len:integer, 64:literal
  assert correct-length?:boolean, [chessboard had incorrect size]
  # board is an array of pointers to files; file is an array of characters
  board:address:array:address:array:character <- new location:type, 8:literal
  col:integer <- copy 0:literal
  {
    done?:boolean <- equal col:integer, 8:literal
    break-if done?:boolean
    file:address:address:array:character <- index-address board:address:array:address:array:character/deref, col:integer
    file:address:address:array:character/deref <- init-file initial-position:address:array:integer, col:integer
    col:integer <- add col:integer, 1:literal
    loop
  }
  reply board:address:array:address:array:character
]

recipe init-file [
  default-space:address:array:location <- new location:type, 30:literal
  position:address:array:integer <- next-ingredient
  index:integer <- next-ingredient
  index:integer <- multiply index:integer, 8:literal
  result:address:array:character <- new character:type, 8:literal
  row:integer <- copy 0:literal
  {
    done?:boolean <- equal row:integer, 8:literal
    break-if done?:boolean
    dest:address:character <- index-address result:address:array:character/deref, row:integer
    dest:address:character/deref <- index position:address:array:integer/deref, index:integer
    row:integer <- add row:integer, 1:literal
    index:integer <- add index:integer, 1:literal
    loop
  }
  reply result:address:array:character
]

recipe print-board [
  default-space:address:array:location <- new location:type, 30:literal
  screen:address <- next-ingredient
  board:address:array:address:array:character <- next-ingredient
  row:integer <- copy 7:literal  # start printing from the top of the board
  # print each row
  {
    done?:boolean <- lesser-than row:integer, 0:literal
    break-if done?:boolean
    # print rank number as a legend
    rank:integer <- add row:integer, 1:literal
    print-integer screen:address, rank:integer
    s:address:array:character <- new [ | ]
    print-string screen:address, s:address:array:character
    # print each square in the row
    col:integer <- copy 0:literal
    {
      done?:boolean <- equal col:integer, 8:literal
      break-if done?:boolean
      f:address:array:character <- index board:address:array:address:array:character/deref, col:integer
      s:character <- index f:address:array:character/deref, row:integer
      print-character screen:address, s:character
      print-character screen:address, 32:literal  # ' '
      col:integer <- add col:integer, 1:literal
      loop
    }
    row:integer <- subtract row:integer, 1:literal
    cursor-to-next-line screen:address
    loop
  }
  # print file letters as legend
  s:address:array:character <- new [  +----------------]
  print-string screen:address, s:address:array:character
  screen:address <- cursor-to-next-line screen:address
#?   screen:address <- print-character screen:address, 97:literal #? 1
  s:address:array:character <- new [    a b c d e f g h]
  screen:address <- print-string screen:address, s:address:array:character
  screen:address <- cursor-to-next-line screen:address
]

# board:address:array:address:array:character <- initial-position
recipe initial-position [
  default-space:address:array:location <- new location:type, 30:literal
  # layout in memory (in raster order):
  #   R P _ _ _ _ p r
  #   N P _ _ _ _ p n
  #   B P _ _ _ _ p b
  #   Q P _ _ _ _ p q
  #   K P _ _ _ _ p k
  #   B P _ _ _ _ p B
  #   N P _ _ _ _ p n
  #   R P _ _ _ _ p r
  initial-position:address:array:integer <- init-array 82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r, 78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n, 66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 81:literal/Q, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 113:literal/q, 75:literal/K, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 107:literal/k, 66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n, 82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r
#?       82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r,
#?       78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n,
#?       66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 
#?       81:literal/Q, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 113:literal/q,
#?       75:literal/K, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 107:literal/k,
#?       66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b,
#?       78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n,
#?       82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r
  board:address:array:address:array:character <- init-board initial-position:address:array:integer
  reply board:address:array:address:array:character
]

scenario printing-the-board [
  assume-screen 30:literal/width, 24:literal/height
  run [
    1:address:array:address:array:character/board <- initial-position
    screen:address <- print-board screen:address, 1:address:array:address:array:character/board
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
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
  ]
]

## data structure: move
container move [
  # valid range: 0-7
  from-file:integer
  from-rank:integer
  to-file:integer
  to-rank:integer
]

# result:address:move, quit?:boolean, error?:boolean <- read-move stdin:address:channel, screen:address
# prints only error messages to screen
recipe read-move [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
#?   $print screen:address #? 1
  from-file:integer, quit?:boolean, error?:boolean <- read-file stdin:address:channel, screen:address
  reply-if quit?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
#?   return-to-console #? 1
  # construct the move object
  result:address:move <- new move:literal
  x:address:integer <- get-address result:address:move/deref, from-file:offset
  x:address:integer/deref <- copy from-file:integer
  x:address:integer <- get-address result:address:move/deref, from-rank:offset
  x:address:integer/deref, quit?:boolean, error?:boolean <- read-rank stdin:address:channel, screen:address
  reply-if quit?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  error?:boolean <- expect-from-channel stdin:address:channel, 45:literal/dash, screen:address
  reply-if error?:boolean, 0:literal/dummy, 0:literal/quit, error?:boolean
  x:address:integer <- get-address result:address:move/deref, to-file:offset
  x:address:integer/deref, quit?:boolean, error?:boolean <- read-file stdin:address:channel, screen:address
  reply-if quit?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  x:address:integer <- get-address result:address:move/deref, to-rank:offset
  x:address:integer/deref, quit?:boolean, error?:boolean <- read-rank stdin:address:channel, screen:address
  reply-if quit?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
  reply-if error?:boolean, 0:literal/dummy, quit?:boolean, error?:boolean
#?   $exit #? 1
  error?:boolean <- expect-from-channel stdin:address:channel, 13:literal/newline, screen:address
  reply-if error?:boolean, 0:literal/dummy, 0:literal/quit, error?:boolean
  reply result:address:move, quit?:boolean, error?:boolean
]

# file:integer, quit:boolean, error:boolean <- read-file stdin:address:channel, screen:address
# valid values for file: 0-7
recipe read-file [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 81:literal  # 'Q'
    break-unless q-pressed?:boolean
    reply 0:literal/dummy, 1:literal/quit, 0:literal/error
  }
  {
    q-pressed?:boolean <- equal c:character, 113:literal  # 'q'
    break-unless q-pressed?:boolean
    reply 0:literal/dummy, 1:literal/quit, 0:literal/error
  }
  {
    newline?:boolean <- equal c:character, 13:literal/newline
    break-unless newline?:boolean
    error-message:address:array:character <- new [that's not enough]
    print-string screen:address, error-message:address:array:character
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  file:integer <- subtract c:character, 97:literal  # 'a'
#?   $print file:integer, [ #? 1
#? ] #? 1
  # 'a' <= file <= 'h'
  {
    above-min:boolean <- greater-or-equal file:integer, 0:literal
    break-if above-min:boolean
    error-message:address:array:character <- new [file too low: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    cursor-to-next-line screen:address
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  {
    below-max:boolean <- lesser-than file:integer, 8:literal
    break-if below-max:boolean
    error-message:address:array:character <- new [file too high: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  reply file:integer, 0:literal/quit, 0:literal/error
]

# rank:integer <- read-rank stdin:address:channel, screen:address
# valid values: 0-7, -1 (quit), -2 (error)
recipe read-rank [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  screen:address <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 81:literal  # 'Q'
    break-unless q-pressed?:boolean
    reply 0:literal/dummy, 1:literal/quit, 0:literal/error
  }
  {
    q-pressed?:boolean <- equal c:character, 113:literal  # 'q'
    break-unless q-pressed?:boolean
    reply 0:literal/dummy, 1:literal/quit, 0:literal/error
  }
  {
    newline?:boolean <- equal c:character, 13:literal/newline
    break-unless newline?:boolean
    error-message:address:array:character <- new [that's not enough]
    print-string screen:address, error-message:address:array:character
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  rank:integer <- subtract c:character, 49:literal  # '1'
#?   $print rank:integer, [ #? 1
#? ] #? 1
  # assert'1' <= rank <= '8'
  {
    above-min:boolean <- greater-or-equal rank:integer 0:literal
    break-if above-min:boolean
    error-message:address:array:character <- new [rank too low: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  {
    below-max:boolean <- lesser-or-equal rank:integer 7:literal
    break-if below-max:boolean
    error-message:address:array:character <- new [rank too high: ]
    print-string screen:address, error-message:address:array:character
    print-character screen:address, c:character
    reply 0:literal/dummy, 0:literal/quit, 1:literal/error
  }
  reply rank:integer, 0:literal/quit, 0:literal/error
]

# read a character from the given channel and check that it's what we expect
# return true on error
recipe expect-from-channel [
  default-space:address:array:location <- new location:type, 30:literal
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
  assume-screen 20:literal/width, 2:literal/height
  run [
#?     $start-tracing #? 1
    1:address:channel <- init-channel 2:literal
#?     $print [aaa channel address: ], 1:address:channel, [ #? 1
#? ] #? 1
    2:integer/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:integer
#?     $print [bbb channel address: ], 1:address:channel, [ #? 1
#? ] #? 1
    3:integer <- routine-state 2:integer/id
#?     $print [I: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after coming up (before any keys were pressed)]
    # press 'a'
#?     $print [ccc channel address: ], 1:address:channel, [ #? 1
#? ] #? 1
#?     $exit #? 1
    1:address:channel <- write 1:address:channel, 97:literal  # 'a'
    restart 2:integer/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
#?     $print [II: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after rank 'a']
    # press '2'
    1:address:channel <- write 1:address:channel, 50:literal  # '2'
    restart 2:integer/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
#?     $print [III: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after file 'a2']
    # press '-'
    1:address:channel <- write 1:address:channel, 45:literal  # '-'
    restart 2:integer/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer
#?     $print [IV: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?/routine-state, [
F read-move-blocking: routine failed to pause after hyphen 'a2-']
    # press 'a'
    1:address:channel <- write 1:address:channel, 97:literal  # 'a'
    restart 2:integer/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer
#?     $print [V: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?/routine-state, [
F read-move-blocking: routine failed to pause after rank 'a2-a']
    # press '4'
    1:address:channel <- write 1:address:channel, 52:literal  # '4'
    restart 2:integer/routine
    # 'read-move' still waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer
#?     $print [VI: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-blocking: routine failed to pause after file 'a2-a4']
    # press 'newline'
    1:address:channel <- write 1:address:channel, 13:literal  # newline
    restart 2:integer/routine
    # 'read-move' now completes
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer
#?     $print [VII: routine ], 2:integer, [ state ], 3:integer [ #? 1
#? ] #? 1
    4:boolean/completed? <- equal 3:integer/routine-state, 1:literal/completed
    assert 4:boolean/completed?, [
F read-move-blocking: routine failed to terminate on newline]
    trace [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-quit [
  assume-screen 20:literal/width, 2:literal/height
  run [
    1:address:channel <- init-channel 2:literal
    2:integer/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-quit: routine failed to pause after coming up (before any keys were pressed)]
    # press 'q'
    1:address:channel <- write 1:address:channel, 113:literal  # 'q'
    restart 2:integer/routine
    # 'read-move' completes
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
    4:boolean/completed? <- equal 3:integer/routine-state, 1:literal/completed
    assert 4:boolean/completed?, [
F read-move-quit: routine failed to terminate on 'q']
    trace [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-illegal-file [
  assume-screen 20:literal/width, 2:literal/height
  run [
    1:address:channel <- init-channel 2:literal
    2:integer/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 50:literal  # '2'
    restart 2:integer/routine
    wait-for-routine 2:integer
  ]
  screen-should-contain [
    .file too low: 2     .
    .                    .
  ]
]

scenario read-move-illegal-rank [
  assume-screen 20:literal/width, 2:literal/height
  run [
    1:address:channel <- init-channel 2:literal
    2:integer/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 97:literal  # 'a'
    1:address:channel <- write 1:address:channel, 97:literal  # 'a'
    restart 2:integer/routine
    wait-for-routine 2:integer
  ]
  screen-should-contain [
    .rank too high: a    .
    .                    .
  ]
]

scenario read-move-empty [
  assume-screen 20:literal/width, 2:literal/height
  run [
    1:address:channel <- init-channel 2:literal
    2:integer/routine <- start-running read-move:recipe, 1:address:channel, screen:address
    # 'read-move' is waiting for input
    wait-for-routine 2:integer
    3:integer <- routine-state 2:integer/id
    4:boolean/waiting? <- equal 3:integer/routine-state, 2:literal/waiting
    assert 4:boolean/waiting?, [
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:channel <- write 1:address:channel, 13:literal/newline
    1:address:channel <- write 1:address:channel, 97:literal  # 'a'
    restart 2:integer/routine
    wait-for-routine 2:integer
  ]
  screen-should-contain [
    .that's not enough   .
    .                    .
  ]
]

recipe make-move [
  default-space:address:array:location <- new location:type, 30:literal
  b:address:array:address:array:character <- next-ingredient
  m:address:move <- next-ingredient
  from-file:integer <- get m:address:move/deref, from-file:offset
#?   $print from-file:integer, [ #? 1
#? ] #? 1
  from-rank:integer <- get m:address:move/deref, from-rank:offset
#?   $print from-rank:integer, [ #? 1
#? ] #? 1
  to-file:integer <- get m:address:move/deref, to-file:offset
#?   $print to-file:integer, [ #? 1
#? ] #? 1
  to-rank:integer <- get m:address:move/deref, to-rank:offset
#?   $print to-rank:integer, [ #? 1
#? ] #? 1
  f:address:array:character <- index b:address:array:address:array:character/deref, from-file:integer
  src:address:character/square <- index-address f:address:array:character/deref, from-rank:integer
  f:address:array:character <- index b:address:array:address:array:character/deref, to-file:integer
  dest:address:character/square <- index-address f:address:array:character/deref, to-rank:integer
#?   $print src:address:character/deref, [ #? 1
#? ] #? 1
  dest:address:character/deref/square <- copy src:address:character/deref/square
  src:address:character/deref/square <- copy 32:literal  # ' '
  reply b:address:array:address:array:character/same-as-ingredient:0
]

scenario making-a-move [
  assume-screen 30:literal/width, 24:literal/height
  run [
    2:address:array:address:array:character/board <- initial-position
    3:address:move <- new move:type
    4:address:integer <- get-address 3:address:move/deref, from-file:offset
    4:address:integer/deref <- copy 6:literal/g
    5:address:integer <- get-address 3:address:move/deref, from-rank:offset
    5:address:integer/deref <- copy 1:literal/2
    6:address:integer <- get-address 3:address:move/deref, to-file:offset
    6:address:integer/deref <- copy 6:literal/g
    7:address:integer <- get-address 3:address:move/deref, to-rank:offset
    7:address:integer/deref <- copy 3:literal/4
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
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
    .                              .
  ]
]

recipe chessboard [
  default-space:address:array:location <- new location:type, 30:literal
  board:address:array:address:array:character <- initial-position
  switch-to-display
  # hook up stdin
  stdin:address:channel <- init-channel 10:literal/capacity
  start-running send-keys-to-channel:recipe, 0:literal/keyboard, stdin:address:channel, 0:literal/screen
  # buffer stdin
  buffered-stdin:address:channel <- init-channel 10:literal/capacity
  start-running buffer-lines:recipe, stdin:address:channel, buffered-stdin:address:channel
  {
    msg:address:array:character <- new [Stupid text-mode chessboard. White pieces in uppercase; black pieces in lowercase. No checking for legal moves.
  ]
    print-string 0:literal/screen, msg:address:array:character
    cursor-to-next-line 0:literal/screen
    print-board 0:literal/screen, board:address:array:address:array:character
    cursor-to-next-line 0:literal/screen
    msg:address:array:character <- new [Type in your move as <from square>-<to square>. For example: 'a2-a4'. Then press <enter>.
]
    print-string 0:literal/screen, msg:address:array:character
    cursor-to-next-line 0:literal/screen
    msg:address:array:character <- new [Hit 'q' to exit.
]
    print-string 0:literal/screen, msg:address:array:character
    {
      cursor-to-next-line 0:literal/screen
      msg:address:array:character <- new [move: ]
      print-string 0:literal/screen, msg:address:array:character
      m:address:move, quit:boolean, error:boolean <- read-move buffered-stdin:address:channel, 0:literal/screen
      break-if quit:boolean, +quit:offset
      loop-if error:boolean
    }
    board:address:array:address:array:character <- make-move board:address:array:address:array:character, m:address:move
    clear-screen 0:literal/screen
    loop
  }
  +quit
#?   $print [aaa] #? 1
  return-to-console
]

recipe main [
  chessboard
]
