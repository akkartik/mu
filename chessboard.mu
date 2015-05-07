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
