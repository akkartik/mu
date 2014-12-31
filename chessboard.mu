(function read-board [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (initial-position:list-address <- init-list R:literal N:literal B:literal Q:literal K:literal B:literal N:literal R:literal
                                              P:literal P:literal P:literal P:literal P:literal P:literal P:literal P:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              p:literal p:literal p:literal p:literal p:literal p:literal p:literal p:literal
                                              r:literal n:literal b:literal q:literal k:literal b:literal n:literal r:literal)
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
  (reply)
])

(function main [
  (b:board-address <- read-board)
  (print-board b:board-address)
])
