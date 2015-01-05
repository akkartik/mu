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

;; data structure: sprite
(and-record sprite [
  width:integer
  height:integer
  data:integer-array-address
])

(address sprite-address (sprite))

(function read-sprite [
  (default-space:space-address <- new space:literal 30:literal)
  (print-primitive (("  init-list\n" literal)))
(q-pbm:list-address <- init-list
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 0:literal 0:literal
  0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal
  0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal
  0:literal 2:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 2:literal 0:literal
  0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 1:literal 2:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 2:literal 1:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 2:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 2:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 0:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 2:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 1:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 2:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal
  0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal 0:literal)
  (print-primitive (("  init-list done\n" literal)))
;?   (pbm:list-address <- next-input)
  (result:sprite-address <- new sprite:literal)
  (w:integer-address <- get-address result:sprite-address/deref width:offset)
  (w:integer-address/deref <- copy 40:literal)
  (print-primitive w:integer-address/deref)
  (h:integer-address <- get-address result:sprite-address/deref height:offset)
  (h:integer-address/deref <- copy 40:literal)
  (print-primitive h:integer-address/deref)
  (capacity:integer <- multiply w:integer-address/deref h:integer-address/deref)
  (buf:integer-array-address-address <- get-address result:sprite-address/deref data:offset)
  (print-primitive (("  list-to-array\n" literal)))
  (buf:integer-array-address-address/deref <- list-to-array capacity:integer q-pbm:list-address)
  (print-primitive (("  read-sprite done\n" literal)))
  (reply result:sprite-address)
])

(function next-int-from-list [
  (default-space:space-address <- new space:literal 30:literal)
  (curr:list-address <- next-input)
  (x:tagged-value-address <- list-value-address curr:list-address)
  (result:integer <- get x:tagged-value-address/deref payload:offset)  ; unsafe
  (next:list-address <- list-next curr:list-address)
  (reply result:integer next:list-address)
])

(function list-to-array [
  (default-space:space-address <- new space:literal 30:literal)
  (size:integer <- next-input)
  (in:list-address <- next-input)
  (result:integer-array-address <- new integer-array:literal size:integer)
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer size:integer)
    (break-if done?:boolean)
    (assert in:list-address (("insufficient elements in list" literal)))
    (src:tagged-value-address <- list-value-address in:list-address)
    (dest:integer-address <- index-address result:integer-array-address/deref i:integer)
    (dest:integer-address/deref <- get src:tagged-value-address/deref payload:offset)
    (i:integer <- add i:integer 1:literal)
    (in:list-address <- list-next in:list-address)
    (loop)
  }
  (reply result:integer-array-address)
])

(function draw-sprite [
  (default-space:space-address <- new space:literal 30:literal)
  (origx:integer <- next-input)  ; screen
  (origy:integer <- next-input)
  (img:sprite-address <- next-input)
  (buf:integer-array-address <- get img:sprite-address/deref data:offset)
  (w:integer <- get img:sprite-address/deref width:offset)  ; sprite
  (h:integer <- get img:sprite-address/deref height:offset)
  (xmax:integer <- add w:integer origx:integer)  ; screen
  (ymax:integer <- add h:integer origy:integer)
  (y:integer <- copy origy:integer)  ; screen
  (idx:integer <- copy 0:literal)  ; sprite
;?   (print-primitive y:integer)
;?   (print-primitive ((" -> " literal)))
;?   (print-primitive ymax:integer)
;?   (print-primitive (("\n" literal)))
  { begin  ; for y from origy to ymax
    (done?:boolean <- greater-or-equal y:integer ymax:integer)
    (break-if done?:boolean)
;?     (print-primitive (("  y: " literal)))
;?     (print-primitive y:integer)
;?     (print-primitive (("\n" literal)))
    (x:integer <- copy origx:integer)
    { begin  ; for x from origx to xmax
      (done?:boolean <- greater-or-equal x:integer xmax:integer)
      (break-if done?:boolean)
;?       (print-primitive (("    x: " literal)))
;?       (print-primitive x:integer)
;?       (print-primitive (("\n" literal)))
      { begin  ; switch sprite[x][y]
        (color:integer <- index buf:integer-array-address/deref idx:integer)
        { begin
          (transparent?:boolean <- equal color:integer 0:literal)
          (break-unless transparent?:boolean)
          ; do nothing
          (break 2:blocks)
        }
        { begin
          (white?:boolean <- equal color:integer 1:literal)
          (break-unless white?:boolean)
          (point x:integer y:integer (("white" literal)))
          (break 2:blocks)
        }
        { begin
          (black?:boolean <- equal color:integer 2:literal)
          (break-unless black?:boolean)
          (point x:integer y:integer (("black" literal)))
          (break 2:blocks)
        }
      }
      (x:integer <- add x:integer 1:literal)
      (idx:integer <- add idx:integer 1:literal)
      (loop)
    }
    (y:integer <- add y:integer 1:literal)
    (loop)
  }
])

(function draw-board [
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
        { begin
          ; print black squares, leave others white
          ; todo: print pieces
          (t1:integer <- add row:integer col:integer)
          (_ t2:integer <- divide-with-remainder t1:integer 2:literal)
          (black?:boolean <- equal t2:integer 1:literal)
          (break-if black?:boolean)
          (rectangle x:integer y:integer 40:literal 40:literal (("dark gray" literal)))
          (break 2:blocks)
        }
        (rectangle x:integer y:integer 40:literal 40:literal (("light gray" literal)))
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
  (graphics-on (("chessboard" literal)) 320:literal 320:literal)
;?   (rectangle 0:literal 0:literal 100:literal 200:literal (("black" literal)))
;?   (wait-for-key)
;?   (reply)
  { begin
    (clear-screen)
;?     (draw-board b:board-address)
    (print-primitive (("read-sprite\n" literal)))
    (x:sprite-address <- read-sprite)
    (print-primitive (("draw-sprite\n" literal)))
    (foo)
    (draw-sprite 0:literal 0:literal x:sprite-address)
;?     (print-primitive (("done\n" literal)))
;?     (wait-for-key)
    (break)
    (image (("Q3.png" literal)) 0:literal 0:literal)
    (x:integer <- color-at 1:literal 1:literal)
    (print-primitive x:integer)
;?     (wait-for-mouse)
;?     (m:move-address <- read-move)
;?     (b:board-address <- make-move b:board-address m:move-address)
;?     (loop)
  }
  (graphics-off)
])
