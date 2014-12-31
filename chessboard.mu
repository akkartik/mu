(function read-board [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (initial-position:list-address <- init-list R:literal P:literal _:literal _:literal _:literal _:literal p:literal r:literal
                                              N:literal P:literal _:literal _:literal _:literal _:literal p:literal n:literal
                                              B:literal P:literal _:literal _:literal _:literal _:literal p:literal b:literal
                                              Q:literal P:literal _:literal _:literal _:literal _:literal p:literal q:literal
                                              K:literal P:literal _:literal _:literal _:literal _:literal p:literal k:literal
                                              B:literal P:literal _:literal _:literal _:literal _:literal p:literal b:literal
                                              N:literal P:literal _:literal _:literal _:literal _:literal p:literal n:literal
                                              R:literal P:literal _:literal _:literal _:literal _:literal p:literal r:literal)
  ; assert(length(initial-position) == 64)
;?   (print-primitive (("list-length\n" literal)))
  (len:integer <- list-length initial-position:list-address)
  (correct-length?:boolean <- equal len:integer 64:literal)
  (assert correct-length?:boolean "chessboard had incorrect size")
  (b:board-address <- new board:literal 8:literal)
  (col:integer <- copy 0:literal)
  (curr:list-address <- copy initial-position:list-address)
  { begin
    (done?:boolean <- equal col:integer 8:literal)
    (break-if done?:boolean)
;?     (print-primitive col:integer)
;?     (print-primitive (("\n" literal)))
    (file:file-address-address <- index-address b:board-address/deref col:integer)
    (file:file-address-address/deref curr:list-address <- read-file curr:list-address)
    (col:integer <- add col:integer 1:literal)
    (loop)
  }
  (reply b:board-address)
])

(function read-file [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (cursor:list-address <- next-input)
  (result:file-address <- new file:literal 8:literal)
  (row:integer <- copy 0:literal)
  { begin
    (done?:boolean <- equal row:integer 8:literal)
    (break-if done?:boolean)
;?     (print-primitive (("  " literal)))
;?     (print-primitive row:integer)
;?     (print-primitive (("\n" literal)))
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
  (default-scope:scope-address <- new scope:literal 30:literal)
  (b:board-address <- next-input)
  (row:integer <- copy 7:literal)
  ; print each row
  { begin
    (done?:boolean <- less-than row:integer 0:literal)
    (break-if done?:boolean)
    ; print each square in the row
    (col:integer <- copy 0:literal)
    { begin
      (done?:boolean <- equal col:integer 8:literal)
      (break-if done?:boolean)
      (f:file-address <- index b:board-address/deref col:integer)
      (s:square <- index f:file-address/deref row:integer)
      (print-primitive s:square)
      (print-primitive ((" " literal)))
      (col:integer <- add col:integer 1:literal)
      (loop)
    }
    (print-primitive (("\n" literal)))
    (row:integer <- subtract row:integer 1:literal)
    (loop)
  }
])

(function main [
;?   (print-primitive (("\u2654 \u265a" literal)))
  (b:board-address <- read-board)
  (print-board b:board-address)
])
