;; data structure: board
(primitive square)
(address square-address (square))  ; pointer. verbose but sadly necessary for now
(array file (square))  ; ranks and files are arrays of squares
(address file-address (file))
(address file-address-address (file-address))  ; pointer to a pointer
(array board (file-address))
(address board-address (board))

(function read-board [
  (default-space:space-address <- new space:literal 30:literal)
  (initial-position:list-address <- init-list R:literal P:literal _:literal _:literal _:literal _:literal p:literal r:literal
                                              N:literal P:literal _:literal _:literal _:literal _:literal p:literal n:literal
                                              B:literal P:literal _:literal _:literal _:literal _:literal p:literal b:literal
                                              Q:literal P:literal _:literal _:literal _:literal _:literal p:literal q:literal
                                              K:literal P:literal _:literal _:literal _:literal _:literal p:literal k:literal
                                              B:literal P:literal _:literal _:literal _:literal _:literal p:literal b:literal
                                              N:literal P:literal _:literal _:literal _:literal _:literal p:literal n:literal
                                              R:literal P:literal _:literal _:literal _:literal _:literal p:literal r:literal)
  ; assert(length(initial-position) == 64)
  (len:integer <- list-length initial-position:list-address)
  (correct-length?:boolean <- equal len:integer 64:literal)
  (assert correct-length?:boolean (("chessboard had incorrect size" literal)))
  (b:board-address <- new board:literal 8:literal)
  (col:integer <- copy 0:literal)
  (curr:list-address <- copy initial-position:list-address)
  { begin
    (done?:boolean <- equal col:integer 8:literal)
    (break-if done?:boolean)
    (file:file-address-address <- index-address b:board-address/deref col:integer)
    (file:file-address-address/deref curr:list-address <- read-file curr:list-address)
    (col:integer <- add col:integer 1:literal)
    (loop)
  }
  (reply b:board-address)
])

(function read-file [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor:list-address <- next-input)
  (result:file-address <- new file:literal 8:literal)
  (row:integer <- copy 0:literal)
  { begin
    (done?:boolean <- equal row:integer 8:literal)
    (break-if done?:boolean)
    (src:tagged-value-address <- list-value-address cursor:list-address)
    (dest:square-address <- index-address result:file-address/deref row:integer)
    (dest:square-address/deref <- get src:tagged-value-address/deref payload:offset)  ; unsafe typecast
    (cursor:list-address <- list-next cursor:list-address)
    (row:integer <- add row:integer 1:literal)
    (loop)
  }
  (reply result:file-address cursor:list-address)
])

(function print-board [
  (default-space:space-address <- new space:literal 30:literal)
  (b:board-address <- next-input)
  (y:integer <- copy 0:literal)
  (row:integer <- copy 7:literal)
  ; print each row
  { begin
    (done?:boolean <- less-than row:integer 0:literal)
    (break-if done?:boolean)
    ; print each square in the row
    (x:integer <- copy 0:literal)
    (col:integer <- copy 0:literal)
    { begin
      (done?:boolean <- equal col:integer 8:literal)
      (break-if done?:boolean)
      (f:file-address <- index b:board-address/deref col:integer)
      (s:square <- index f:file-address/deref row:integer)
      { begin
        ; print black squares, leave others white
        ; todo: print pieces
        (t1:integer <- add row:integer col:integer)
        (_ t2:integer <- divide-with-remainder t1:integer 2:literal)
        (black?:boolean <- equal t2:integer 1:literal)
        (break-if black?:boolean)
        (rectangle x:integer y:integer 40:literal 40:literal (("black" literal)))
      }
      (col:integer <- add col:integer 1:literal)
      (x:integer <- add x:integer 40:literal)
      (loop)
    }
    (row:integer <- subtract row:integer 1:literal)
    (y:integer <- add y:integer 40:literal)
    (loop)
  }
])

;; data structure: move
(and-record move [
  from:integer-integer-pair
  to:integer-integer-pair
])

(address move-address (move))

(function read-move [
  (default-space:space-address <- new space:literal 30:literal)
])

(function make-move [
  (default-space:space-address <- new space:literal 30:literal)
])

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (b:board-address <- read-board)
  (graphics-on)
;?   (rectangle 0:literal 0:literal 100:literal 200:literal (("black" literal)))
;?   (wait-for-key)
;?   (reply)
  { begin
    (clear-screen)
    (print-board b:board-address)
    (wait-for-mouse)
;?     (m:move-address <- read-move)
;?     (b:board-address <- make-move b:board-address m:move-address)
;?     (loop)
  }
  (graphics-off)
])
