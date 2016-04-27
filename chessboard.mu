# Chessboard program: you type in moves in algebraic notation, and it'll
# display the position after each move.

def main [
  open-console  # take control of screen, keyboard and mouse

  # The chessboard function takes keyboard and screen objects as 'ingredients'.
  #
  # In mu it is good form (though not required) to explicitly show the
  # hardware you rely on.
  #
  # The chessboard also returns the same keyboard and screen objects. In mu it
  # is good form to not modify ingredients of a function unless they are also
  # results. Here we clearly modify both keyboard and screen, so we return
  # both.
  #
  # Here the console and screen are both 0, which usually indicates real
  # hardware rather than a fake for testing as you'll see below.
  chessboard 0/screen, 0/console

  close-console  # cleanup screen, keyboard and mouse
]

## But enough about mu. Here's what it looks like to run the chessboard program.

scenario print-board-and-read-move [
  trace-until 100/app
  # we'll make the screen really wide because the program currently prints out a long line
  assume-screen 120/width, 20/height
  # initialize keyboard to type in a move
  assume-console [
    type [a2-a4
]
  ]
  run [
    screen:address:screen, console:address:console <- chessboard screen:address:screen, console:address:console
    # icon for the cursor
    1:character/cursor-icon <- copy 9251/␣
    screen <- print screen, 1:character/cursor-icon
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

def chessboard screen:address:screen, console:address:console -> screen:address:screen, console:address:console [
  local-scope
  load-ingredients
  board:address:array:address:array:character <- initial-position
  # hook up stdin
  stdin-in:address:source:character, stdin-out:address:sink:character <- new-channel 10/capacity
  start-running send-keys-to-channel, console, stdin-out, screen
  # buffer lines in stdin
  buffered-stdin-in:address:source:character, buffered-stdin-out:address:sink:character <- new-channel 10/capacity
  start-running buffer-lines, stdin-in, buffered-stdin-out
  {
    print screen, [Stupid text-mode chessboard. White pieces in uppercase; black pieces in lowercase. No checking for legal moves.
]
    cursor-to-next-line screen
    print-board screen, board
    cursor-to-next-line screen
    print screen, [Type in your move as <from square>-<to square>. For example: 'a2-a4'. Then press <enter>.
]
    cursor-to-next-line screen
    print screen [Hit 'q' to exit.
]
    {
      cursor-to-next-line screen
      screen <- print screen, [move: ]
      m:address:move, quit:boolean, error:boolean <- read-move buffered-stdin-in, screen
      break-if quit, +quit:label
      buffered-stdin-in <- clear buffered-stdin-in  # cleanup after error. todo: test this?
      loop-if error
    }
    board <- make-move board, m
    screen <- clear-screen screen
    loop
  }
  +quit
]

## a board is an array of files, a file is an array of characters (squares)

def new-board initial-position:address:array:character -> board:address:array:address:array:character [
  local-scope
  load-ingredients
  # assert(length(initial-position) == 64)
  len:number <- length *initial-position
  correct-length?:boolean <- equal len, 64
  assert correct-length?, [chessboard had incorrect size]
  # board is an array of pointers to files; file is an array of characters
  board <- new {(address array character): type}, 8
  col:number <- copy 0
  {
    done?:boolean <- equal col, 8
    break-if done?
    file:address:array:character <- new-file initial-position, col
    *board <- put-index *board, col, file
    col <- add col, 1
    loop
  }
]

def new-file position:address:array:character, index:number -> result:address:array:character [
  local-scope
  load-ingredients
  index <- multiply index, 8
  result <- new character:type, 8
  row:number <- copy 0
  {
    done?:boolean <- equal row, 8
    break-if done?
    square:character <- index *position, index
    *result <- put-index *result, row, square
    row <- add row, 1
    index <- add index, 1
    loop
  }
]

def print-board screen:address:screen, board:address:array:address:array:character -> screen:address:screen [
  local-scope
  load-ingredients
  row:number <- copy 7  # start printing from the top of the board
  space:character <- copy 32/space
  # print each row
  {
    done?:boolean <- lesser-than row, 0
    break-if done?
    # print rank number as a legend
    rank:number <- add row, 1
    print-integer screen, rank
    print screen, [ | ]
    # print each square in the row
    col:number <- copy 0
    {
      done?:boolean <- equal col:number, 8
      break-if done?:boolean
      f:address:array:character <- index *board, col
      c:character <- index *f, row
      print screen, c
      print screen, space
      col <- add col, 1
      loop
    }
    row <- subtract row, 1
    cursor-to-next-line screen
    loop
  }
  # print file letters as legend
  print screen, [  +----------------]
  cursor-to-next-line screen
  print screen, [    a b c d e f g h]
  cursor-to-next-line screen
]

def initial-position -> board:address:array:address:array:character [
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
  initial-position:address:array:character <- new-array 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 81/Q, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 113/q, 75/K, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 107/k, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r
#?       82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r,
#?       78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n,
#?       66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 
#?       81/Q, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 113/q,
#?       75/K, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 107/k,
#?       66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b,
#?       78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n,
#?       82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r
  board <- new-board initial-position
]

scenario printing-the-board [
  assume-screen 30/width, 12/height
  run [
    1:address:array:address:array:character/board <- initial-position
    screen:address:screen <- print-board screen:address:screen, 1:address:array:address:array:character/board
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

# prints only error messages to screen
def read-move stdin:address:source:character, screen:address:screen -> result:address:move, quit?:boolean, error?:boolean, stdin:address:source:character, screen:address:screen [
  local-scope
  load-ingredients
  from-file:number, quit?:boolean, error?:boolean <- read-file stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  # construct the move object
  result:address:move <- new move:type
  *result <- put *result, from-file:offset, from-file
  from-rank:number, quit?, error? <- read-rank stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  *result <- put *result, from-rank:offset, from-rank
  error? <- expect-from-channel stdin, 45/dash, screen
  return-if error?, 0/dummy, 0/quit
  to-file:number, quit?, error? <- read-file stdin, screen
  return-if quit?:boolean, 0/dummy
  return-if error?:boolean, 0/dummy
  *result <- put *result, to-file:offset, to-file
  to-rank:number, quit?, error? <- read-rank stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  *result <- put *result, to-rank:offset, to-rank
  error? <- expect-from-channel stdin, 10/newline, screen
  return-if error?, 0/dummy, 0/quit
  return result  # BUG: why is this statement required?
]

# valid values for file: 0-7
def read-file stdin:address:source:character, screen:address:screen -> file:number, quit:boolean, error:boolean, stdin:address:source:character, screen:address:screen [
  local-scope
  load-ingredients
  c:character, stdin <- read stdin
  {
    q-pressed?:boolean <- equal c, 81/Q
    break-unless q-pressed?
    return 0/dummy, 1/quit, 0/error
  }
  {
    q-pressed? <- equal c, 113/q
    break-unless q-pressed?
    return 0/dummy, 1/quit, 0/error
  }
  {
    empty-fake-keyboard?:boolean <- equal c, 0/eof
    break-unless empty-fake-keyboard?
    return 0/dummy, 1/quit, 0/error
  }
  {
    newline?:boolean <- equal c, 10/newline
    break-unless newline?
    print screen, [that's not enough]
    return 0/dummy, 0/quit, 1/error
  }
  file:number <- subtract c, 97/a
  # 'a' <= file <= 'h'
  {
    above-min:boolean <- greater-or-equal file, 0
    break-if above-min
    print screen, [file too low: ]
    print screen, c
    cursor-to-next-line screen
    return 0/dummy, 0/quit, 1/error
  }
  {
    below-max:boolean <- lesser-than file, 8
    break-if below-max
    print screen, [file too high: ]
    print screen, c
    return 0/dummy, 0/quit, 1/error
  }
  return file, 0/quit, 0/error
]

# valid values: 0-7, -1 (quit), -2 (error)
def read-rank stdin:address:source:character, screen:address:screen -> rank:number, quit?:boolean, error?:boolean, stdin:address:source:character, screen:address:screen [
  local-scope
  load-ingredients
  c:character, stdin <- read stdin
  {
    q-pressed?:boolean <- equal c, 8/Q
    break-unless q-pressed?
    return 0/dummy, 1/quit, 0/error
  }
  {
    q-pressed? <- equal c, 113/q
    break-unless q-pressed?
    return 0/dummy, 1/quit, 0/error
  }
  {
    newline?:boolean <- equal c, 10  # newline
    break-unless newline?
    print screen, [that's not enough]
    return 0/dummy, 0/quit, 1/error
  }
  rank:number <- subtract c, 49/'1'
  # assert'1' <= rank <= '8'
  {
    above-min:boolean <- greater-or-equal rank, 0
    break-if above-min
    print screen, [rank too low: ]
    print screen, c
    return 0/dummy, 0/quit, 1/error
  }
  {
    below-max:boolean <- lesser-or-equal rank, 7
    break-if below-max
    print screen, [rank too high: ]
    print screen, c
    return 0/dummy, 0/quit, 1/error
  }
  return rank, 0/quit, 0/error
]

# read a character from the given channel and check that it's what we expect
# return true on error
def expect-from-channel stdin:address:source:character, expected:character, screen:address:screen -> result:boolean, stdin:address:source:character, screen:address:screen [
  local-scope
  load-ingredients
  c:character, stdin <- read stdin
  {
    match?:boolean <- equal c, expected
    break-if match?
    print screen, [expected character not found]
  }
  result <- not match?
]

scenario read-move-blocking [
  assume-screen 20/width, 2/height
  run [
    1:address:source:character, 2:address:sink:character <- new-channel 2/capacity
    3:number/routine <- start-running read-move, 1:address:source:character, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-blocking: routine failed to pause after coming up (before any keys were pressed)]
    # press 'a'
    2:address:sink:character <- write 2:address:sink:character, 97/a
    restart 3:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-blocking: routine failed to pause after rank 'a']
    # press '2'
    2:address:sink:character <- write 2:address:sink:character, 50/'2'
    restart 3:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-blocking: routine failed to pause after file 'a2']
    # press '-'
    2:address:sink:character <- write 2:address:sink:character, 45/'-'
    restart 3:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?/routine-state, [ 
F read-move-blocking: routine failed to pause after hyphen 'a2-']
    # press 'a'
    2:address:sink:character <- write 2:address:sink:character, 97/a
    restart 3:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?/routine-state, [ 
F read-move-blocking: routine failed to pause after rank 'a2-a']
    # press '4'
    2:address:sink:character <- write 2:address:sink:character, 52/'4'
    restart 3:number/routine
    # 'read-move' still waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-blocking: routine failed to pause after file 'a2-a4']
    # press 'newline'
    2:address:sink:character <- write 2:address:sink:character, 10  # newline
    restart 3:number/routine
    # 'read-move' now completes
    wait-for-routine 3:number
    4:number <- routine-state 3:number
    5:boolean/completed? <- equal 4:number/routine-state, 1/completed
    assert 5:boolean/completed?, [ 
F read-move-blocking: routine failed to terminate on newline]
    trace 1, [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-quit [
  assume-screen 20/width, 2/height
  run [
    1:address:source:character, 2:address:sink:character <- new-channel 2/capacity
    3:number/routine <- start-running read-move, 1:address:channel:character, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-quit: routine failed to pause after coming up (before any keys were pressed)]
    # press 'q'
    2:address:sink:character <- write 2:address:sink:character, 113/q
    restart 3:number/routine
    # 'read-move' completes
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/completed? <- equal 4:number/routine-state, 1/completed
    assert 5:boolean/completed?, [ 
F read-move-quit: routine failed to terminate on 'q']
    trace 1, [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

scenario read-move-illegal-file [
  assume-screen 20/width, 2/height
  run [
    1:address:source:character, 2:address:sink:character <- new-channel 2/capacity
    3:number/routine <- start-running read-move, 1:address:source:character, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:sink:character <- write 1:address:sink:character, 50/'2'
    restart 3:number/routine
    wait-for-routine 3:number
  ]
  screen-should-contain [
    .file too low: 2     .
    .                    .
  ]
]

scenario read-move-illegal-rank [
  assume-screen 20/width, 2/height
  run [
    1:address:source:character, 2:address:sink:character <- new-channel 2/capacity
    3:number/routine <- start-running read-move, 1:address:source:character, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:sink:character <- write 1:address:sink:character, 97/a
    1:address:sink:character <- write 1:address:sink:character, 97/a
    restart 3:number/routine
    wait-for-routine 3:number
  ]
  screen-should-contain [
    .rank too high: a    .
    .                    .
  ]
]

scenario read-move-empty [
  assume-screen 20/width, 2/height
  run [
    1:address:source:character, 2:address:sink:character <- new-channel 2/capacity
    3:number/routine <- start-running read-move, 1:address:source:character, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine 3:number
    4:number <- routine-state 3:number/id
    5:boolean/waiting? <- equal 4:number/routine-state, 3/waiting
    assert 5:boolean/waiting?, [ 
F read-move-file: routine failed to pause after coming up (before any keys were pressed)]
    1:address:sink:character <- write 1:address:sink:character, 10/newline
    1:address:sink:character <- write 1:address:sink:character, 97/a
    restart 3:number/routine
    wait-for-routine 3:number
  ]
  screen-should-contain [
    .that's not enough   .
    .                    .
  ]
]

def make-move board:address:array:address:array:character, m:address:move -> board:address:array:address:array:character [
  local-scope
  load-ingredients
  from-file:number <- get *m, from-file:offset
  from-rank:number <- get *m, from-rank:offset
  to-file:number <- get *m, to-file:offset
  to-rank:number <- get *m, to-rank:offset
  from-f:address:array:character <- index *board, from-file
  to-f:address:array:character <- index *board, to-file
  src:character/square <- index *from-f, from-rank
  *to-f <- put-index *to-f, to-rank, src
  *from-f <- put-index *from-f, from-rank, 32/space
]

scenario making-a-move [
  assume-screen 30/width, 12/height
  run [
    2:address:array:address:array:character/board <- initial-position
    3:address:move <- new move:type
    *3:address:move <- merge 6/g, 1/'2', 6/g, 3/'4'
    2:address:array:address:array:character/board <- make-move 2:address:array:address:array:character/board, 3:address:move
    screen:address:screen <- print-board screen:address:screen, 2:address:array:address:array:character/board
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
