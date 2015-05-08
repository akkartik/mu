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

scenario printing-the-board [
  assume-screen 30:literal/width, 24:literal/height
  run [
#?     $print [AAA #? 1
#? ] #? 1
    # layout in memory:
    #   R P _ _ _ _ p r
    #   N P _ _ _ _ p n
    #   B P _ _ _ _ p b
    #   Q P _ _ _ _ p q
    #   K P _ _ _ _ p k
    #   B P _ _ _ _ p B
    #   N P _ _ _ _ p n
    #   R P _ _ _ _ p r
    1:address:array:integer/initial-position <- init-array 82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r, 78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n, 66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 81:literal/Q, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 113:literal/q, 75:literal/K, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 107:literal/k, 66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n, 82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r
#?       82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r,
#?       78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n,
#?       66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b, 
#?       81:literal/Q, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 113:literal/q,
#?       75:literal/K, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 107:literal/k,
#?       66:literal/B, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 98:literal/b,
#?       78:literal/N, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 110:literal/n,
#?       82:literal/R, 80:literal/P, 32:literal/blank, 32:literal/blank, 32:literal/blank, 32:literal/blank, 112:literal/p, 114:literal/r
#?     $print [BBB #? 1
#? ] #? 1
#?     $start-tracing #? 1
    2:address:array:address:array:character/board <- init-board 1:address:array:integer/initial-position
#?     $print [CCC #? 1
#? ] #? 1
    screen:address <- print-board screen:address, 2:address:array:address:array:character/board
#?     $print [DDD #? 1
#? ] #? 1
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

recipe read-move [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  from-file:integer <- read-file stdin:address:channel
  {
    q-pressed?:boolean <- lesser-than from-file:integer, 0:literal
    break-unless q-pressed?:boolean
    reply 0:literal
  }
  # construct the move object
  result:address:move <- new move:literal
  x:address:integer <- get-address result:address:move/deref, from-file:offset
  x:address:integer/deref <- copy from-file:integer
  x:address:integer <- get-address result:address:move/deref, from-rank:offset
  x:address:integer/deref <- read-rank stdin:address:channel
  expect-from-channel stdin:address:channel, 45:literal  # '-'
  x:address:integer <- get-address result:address:move/deref, to-file:offset
  x:address:integer/deref <- read-file stdin:address:channel
  x:address:integer <- get-address result:address:move/deref, to-rank:offset
  x:address:integer/deref <- read-rank stdin:address:channel
  expect-from-channel stdin:address:channel, 10:literal  # newline
  reply result:address:move
]

recipe read-file [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 81:literal  # 'q'
    break-unless q-pressed?:boolean
    reply -1:literal
  }
  file:integer <- subtract c:character, 97:literal  # 'a'
  # 'a' <= file <= 'h'
  above-min:boolean <- greater-or-equal file:integer, 0:literal
  assert above-min:boolean [file too low]
  below-max:boolean <- lesser-than file:integer, 8:literal
  assert below-max:boolean [file too high]
  reply file:integer
]

recipe read-rank [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  {
    q-pressed?:boolean <- equal c:character, 81:literal  # 'q'
    break-unless q-pressed?:boolean
    reply -1:literal
  }
  rank:integer <- subtract c:character, 49:literal  # '1'
  # assert'1' <= rank <= '8'
  above-min:boolean <- greater-or-equal rank:integer 0:literal
  assert above-min:boolean [rank too low]
  below-max:boolean <- lesser-or-equal rank:integer 7:literal
  assert below-max:boolean [rank too high]
  reply rank:integer
]

# read a character from the given channel and check that it's what we expect
recipe expect-from-channel [
  default-space:address:array:location <- new location:type, 30:literal
  stdin:address:channel <- next-ingredient
  expected:character <- next-ingredient
  c:character, stdin:address:channel <- read stdin:address:channel
  match?:boolean <- equal c:character, expected:character
  assert match?:boolean [expected character not found]
]

scenario read-move-blocking [
  run [
#?     $start-tracing #? 1
    1:address:channel <- init-channel 2:literal
#?     $print [aaa channel address: ], 1:address:channel, [ #? 1
#? ] #? 1
    2:integer/routine <- start-running read-move:recipe, 1:address:channel
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
    1:address:channel <- write 1:address:channel, 10:literal  # newline
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
