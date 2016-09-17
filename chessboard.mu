# Chessboard program: you type in moves in algebraic notation, and it'll
# display the position after each move.

def main [
  open-console  # take control of screen, keyboard and mouse

  # The chessboard function takes keyboard and screen objects as 'ingredients'.
  #
  # In mu it is good form (though not required) to explicitly show the
  # hardware you rely on.
  #
  # Here the console and screen are both 0, which usually indicates real
  # hardware rather than a fake for testing as you'll see below.
  chessboard 0/screen, 0/console

  close-console  # clean up screen, keyboard and mouse
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
    local-scope
    screen:address:screen, console:address:console <- chessboard screen:address:screen, console:address:console
    # icon for the cursor
    cursor-icon:char <- copy 9251/␣
    screen <- print screen, cursor-icon
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

type board = address:array:address:array:char

def chessboard screen:address:screen, console:address:console -> screen:address:screen, console:address:console [
  local-scope
  load-ingredients
  board:board <- initial-position
  # hook up stdin
  stdin-in:address:source:char, stdin-out:address:sink:char <- new-channel 10/capacity
  start-running send-keys-to-channel, console, stdin-out, screen
  # buffer lines in stdin
  buffered-stdin-in:address:source:char, buffered-stdin-out:address:sink:char <- new-channel 10/capacity
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

def new-board initial-position:address:array:char -> board:board [
  local-scope
  load-ingredients
  # assert(length(initial-position) == 64)
  len:num <- length *initial-position
  correct-length?:boolean <- equal len, 64
  assert correct-length?, [chessboard had incorrect size]
  # board is an array of pointers to files; file is an array of characters
  board <- new {(address array character): type}, 8
  col:num <- copy 0
  {
    done?:boolean <- equal col, 8
    break-if done?
    file:address:array:char <- new-file initial-position, col
    *board <- put-index *board, col, file
    col <- add col, 1
    loop
  }
]

def new-file position:address:array:char, index:num -> result:address:array:char [
  local-scope
  load-ingredients
  index <- multiply index, 8
  result <- new character:type, 8
  row:num <- copy 0
  {
    done?:boolean <- equal row, 8
    break-if done?
    square:char <- index *position, index
    *result <- put-index *result, row, square
    row <- add row, 1
    index <- add index, 1
    loop
  }
]

def print-board screen:address:screen, board:board -> screen:address:screen [
  local-scope
  load-ingredients
  row:num <- copy 7  # start printing from the top of the board
  space:char <- copy 32/space
  # print each row
  {
    done?:boolean <- lesser-than row, 0
    break-if done?
    # print rank number as a legend
    rank:num <- add row, 1
    print-integer screen, rank
    print screen, [ | ]
    # print each square in the row
    col:num <- copy 0
    {
      done?:boolean <- equal col:num, 8
      break-if done?:boolean
      f:address:array:char <- index *board, col
      c:char <- index *f, row
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

def initial-position -> board:board [
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
  initial-position:address:array:char <- new-array 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 81/Q, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 113/q, 75/K, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 107/k, 66/B, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 98/b, 78/N, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 110/n, 82/R, 80/P, 32/blank, 32/blank, 32/blank, 32/blank, 112/p, 114/r
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
    local-scope
    board:board <- initial-position
    screen:address:screen <- print-board screen:address:screen, board
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
  from-file:num
  from-rank:num
  to-file:num
  to-rank:num
]

# prints only error messages to screen
def read-move stdin:address:source:char, screen:address:screen -> result:address:move, quit?:boolean, error?:boolean, stdin:address:source:char, screen:address:screen [
  local-scope
  load-ingredients
  from-file:num, quit?:boolean, error?:boolean <- read-file stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  # construct the move object
  result:address:move <- new move:type
  *result <- put *result, from-file:offset, from-file
  from-rank:num, quit?, error? <- read-rank stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  *result <- put *result, from-rank:offset, from-rank
  error? <- expect-from-channel stdin, 45/dash, screen
  return-if error?, 0/dummy, 0/quit
  to-file:num, quit?, error? <- read-file stdin, screen
  return-if quit?:boolean, 0/dummy
  return-if error?:boolean, 0/dummy
  *result <- put *result, to-file:offset, to-file
  to-rank:num, quit?, error? <- read-rank stdin, screen
  return-if quit?, 0/dummy
  return-if error?, 0/dummy
  *result <- put *result, to-rank:offset, to-rank
  error? <- expect-from-channel stdin, 10/newline, screen
  return-if error?, 0/dummy, 0/quit
]

# valid values for file: 0-7
def read-file stdin:address:source:char, screen:address:screen -> file:num, quit:boolean, error:boolean, stdin:address:source:char, screen:address:screen [
  local-scope
  load-ingredients
  c:char, eof?:boolean, stdin <- read stdin
  return-if eof?, 0/dummy, 1/quit, 0/error
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
  file:num <- subtract c, 97/a
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

# valid values for rank: 0-7
def read-rank stdin:address:source:char, screen:address:screen -> rank:num, quit?:boolean, error?:boolean, stdin:address:source:char, screen:address:screen [
  local-scope
  load-ingredients
  c:char, eof?:boolean, stdin <- read stdin
  return-if eof?, 0/dummy, 1/quit, 0/error
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
  rank:num <- subtract c, 49/'1'
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
def expect-from-channel stdin:address:source:char, expected:char, screen:address:screen -> result:boolean, stdin:address:source:char, screen:address:screen [
  local-scope
  load-ingredients
  c:char, eof?:boolean, stdin <- read stdin
  return-if eof? 1/true
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
    local-scope
    source:address:source:char, sink:address:sink:char <- new-channel 2/capacity
    read-move-routine:num/routine <- start-running read-move, source, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state:num <- routine-state read-move-routine
    waiting?:boolean <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after coming up (before any keys were pressed)]
    # press 'a'
    sink <- write sink, 97/a
    restart read-move-routine
    # 'read-move' still waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    waiting? <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after rank 'a']
    # press '2'
    sink <- write sink, 50/'2'
    restart read-move-routine
    # 'read-move' still waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    waiting? <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after file 'a2']
    # press '-'
    sink <- write sink, 45/'-'
    restart read-move-routine
    # 'read-move' still waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    waiting? <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after hyphen 'a2-']
    # press 'a'
    sink <- write sink, 97/a
    restart read-move-routine
    # 'read-move' still waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    waiting? <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after rank 'a2-a']
    # press '4'
    sink <- write sink, 52/'4'
    restart read-move-routine
    # 'read-move' still waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    waiting? <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-blocking: routine failed to pause after file 'a2-a4']
    # press 'newline'
    sink <- write sink, 10  # newline
    restart read-move-routine
    # 'read-move' now completes
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    completed?:boolean <- equal read-move-state, 1/completed
    assert completed?, [ 
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
    local-scope
    source:address:source:char, sink:address:sink:char <- new-channel 2/capacity
    read-move-routine:num <- start-running read-move, source, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state:num <- routine-state read-move-routine
    waiting?:boolean <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-quit: routine failed to pause after coming up (before any keys were pressed)]
    # press 'q'
    sink <- write sink, 113/q
    restart read-move-routine
    # 'read-move' completes
    wait-for-routine-to-block read-move-routine
    read-move-state <- routine-state read-move-routine
    completed?:boolean <- equal read-move-state, 1/completed
    assert completed?, [ 
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
    local-scope
    source:address:source:char, sink:address:sink:char <- new-channel 2/capacity
    read-move-routine:num <- start-running read-move, source, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state:num <- routine-state read-move-routine
    waiting?:boolean <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-illegal-file: routine failed to pause after coming up (before any keys were pressed)]
    sink <- write sink, 50/'2'
    restart read-move-routine
    wait-for-routine-to-block read-move-routine
  ]
  screen-should-contain [
    .file too low: 2     .
    .                    .
  ]
]

scenario read-move-illegal-rank [
  assume-screen 20/width, 2/height
  run [
    local-scope
    source:address:source:char, sink:address:sink:char <- new-channel 2/capacity
    read-move-routine:num <- start-running read-move, source, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state:num <- routine-state read-move-routine
    waiting?:boolean <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-illegal-rank: routine failed to pause after coming up (before any keys were pressed)]
    sink <- write sink, 97/a
    sink <- write sink, 97/a
    restart read-move-routine
    wait-for-routine-to-block read-move-routine
  ]
  screen-should-contain [
    .rank too high: a    .
    .                    .
  ]
]

scenario read-move-empty [
  assume-screen 20/width, 2/height
  run [
    local-scope
    source:address:source:char, sink:address:sink:char <- new-channel 2/capacity
    read-move-routine:num <- start-running read-move, source, screen:address:screen
    # 'read-move' is waiting for input
    wait-for-routine-to-block read-move-routine
    read-move-state:num <- routine-state read-move-routine
    waiting?:boolean <- not-equal read-move-state, 2/discontinued
    assert waiting?, [ 
F read-move-empty: routine failed to pause after coming up (before any keys were pressed)]
    sink <- write sink, 10/newline
    sink <- write sink, 97/a
    restart read-move-routine
    wait-for-routine-to-block read-move-routine
  ]
  screen-should-contain [
    .that's not enough   .
    .                    .
  ]
]

def make-move board:board, m:address:move -> board:board [
  local-scope
  load-ingredients
  from-file:num <- get *m, from-file:offset
  from-rank:num <- get *m, from-rank:offset
  to-file:num <- get *m, to-file:offset
  to-rank:num <- get *m, to-rank:offset
  from-f:address:array:char <- index *board, from-file
  to-f:address:array:char <- index *board, to-file
  src:char/square <- index *from-f, from-rank
  *to-f <- put-index *to-f, to-rank, src
  *from-f <- put-index *from-f, from-rank, 32/space
]

scenario making-a-move [
  assume-screen 30/width, 12/height
  run [
    local-scope
    board:board <- initial-position
    move:address:move <- new move:type
    *move <- merge 6/g, 1/'2', 6/g, 3/'4'
    board <- make-move board, move
    screen:address:screen <- print-board screen:address:screen, board
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
