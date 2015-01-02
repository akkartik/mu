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
  (default-scope:scope-address <- new scope:literal 30:literal)
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
  (default-scope:scope-address <- new scope:literal 30:literal)
  (b:board-address <- next-input)
  (row:integer <- copy 7:literal)
  (screen-y:integer <- copy 1:literal)
  ; print each row
  { begin
    (cursor 1:literal screen-y:integer)
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
    (row:integer <- subtract row:integer 1:literal)
    (screen-y:integer <- add screen-y:integer 1:literal)
    (loop)
  }
])

(and-record move [
  from:integer-integer-pair
  to:integer-integer-pair
])

(address move-address (move))

(function read-move [
  (a:character <- copy ((#\a literal)))
  (file-base:integer <- character-to-integer a:character)
  (one:character <- copy ((#\1 literal)))
  (rank-base:integer <- character-to-integer one:character)
  ; get from-file
  (c:character <- wait-for-key)
  (print-primitive c:character)
  (from-file:integer <- character-to-integer c:character)
  (from-file:integer <- subtract from-file:integer file-base:integer)
  ; assert('a' <= from-file <= 'h')
  (above-min:boolean <- greater-or-equal from-file:integer 0:literal)
  (assert above-min:boolean (("from-file too low" literal)))
  (below-max:boolean <- lesser-or-equal from-file:integer 7:literal)
  (assert below-max:boolean (("from-file too high" literal)))
  ; get from-rank
  (c:character <- wait-for-key)
  (print-primitive c:character)
  (from-rank:integer <- character-to-integer c:character)
  (from-rank:integer <- subtract from-rank:integer rank-base:integer)
  ; assert('1' <= from-rank <= '8')
  (above-min:boolean <- greater-or-equal from-rank:integer 0:literal)
  (assert above-min:boolean (("from-rank too low" literal)))
  (below-max:boolean <- lesser-or-equal from-rank:integer 7:literal)
  (assert below-max:boolean (("from-rank too high" literal)))
  ; slurp hyphen
  (c:character <- wait-for-key)
  (print-primitive c:character)
  (hyphen?:boolean <- equal c:character ((#\- literal)))
  (assert hyphen?:boolean (("expected hyphen" literal)))
  ; get to-file
  (c:character <- wait-for-key)
  (print-primitive c:character)
  (to-file:integer <- character-to-integer c:character)
  (to-file:integer <- subtract to-file:integer file-base:integer)
  ; assert('a' <= to-file <= 'h')
  (above-min:boolean <- greater-or-equal to-file:integer 0:literal)
  (assert above-min:boolean (("to-file too low" literal)))
  (below-max:boolean <- lesser-or-equal to-file:integer 7:literal)
  (assert below-max:boolean (("to-file too high" literal)))
  ; get to-rank
  (c:character <- wait-for-key)
  (print-primitive c:character)
  (to-rank:integer <- character-to-integer c:character)
  (to-rank:integer <- subtract to-rank:integer rank-base:integer)
  ; assert('1' <= to-rank <= '8')
  (above-min:boolean <- greater-or-equal to-rank:integer 0:literal)
  (assert above-min:boolean (("to-rank too low" literal)))
  (below-max:boolean <- lesser-or-equal to-rank:integer 7:literal)
  (assert below-max:boolean (("to-rank too high" literal)))
  ; construct the move object
  (result:move-address <- new move:literal)
  (f:integer-integer-pair-address <- get-address result:move-address/deref from:offset)
  (dest:integer-address <- get-address f:integer-integer-pair-address/deref 0:offset)
  (dest:integer-address/deref <- copy from-file:integer)
  (dest:integer-address <- get-address f:integer-integer-pair-address/deref 1:offset)
  (dest:integer-address/deref <- copy from-rank:integer)
  (t0:integer-integer-pair-address <- get-address result:move-address/deref to:offset)
  (dest:integer-address <- get-address t0:integer-integer-pair-address/deref 0:offset)
  (dest:integer-address/deref <- copy to-file:integer)
  (dest:integer-address <- get-address t0:integer-integer-pair-address/deref 1:offset)
  (dest:integer-address/deref <- copy to-rank:integer)
  (reply result:move-address)
])

(function make-move [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (b:board-address <- next-input)
  (m:move-address <- next-input)
  (x:integer-integer-pair <- get m:move-address/deref from:offset)
  (from-file:integer <- get x:integer-integer-pair 0:offset)
  (from-rank:integer <- get x:integer-integer-pair 1:offset)
  (f:file-address <- index b:board-address/deref from-file:integer)
  (src:square-address <- index-address f:file-address/deref from-rank:integer)
  (x:integer-integer-pair <- get m:move-address/deref to:offset)
  (to-file:integer <- get x:integer-integer-pair 0:offset)
  (to-rank:integer <- get x:integer-integer-pair 1:offset)
  (f:file-address <- index b:board-address/deref to-file:integer)
  (dest:square-address <- index-address f:file-address/deref to-rank:integer)
  (dest:square-address/deref <- copy src:square-address/deref)
  (src:square-address/deref <- copy _:literal)
  (reply b:board-address)
])

(function main [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (b:board-address <- read-board)
  (console-on)
  { begin
    (clear-screen)
    (print-board b:board-address)
    (print-primitive (("? " literal)))
    (m:move-address <- read-move)
    (b:board-address <- make-move b:board-address m:move-address)
    (loop)
  }
  (console-off)
])
