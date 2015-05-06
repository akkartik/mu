;; data structure: board
(primitive square)
(address square-address (square))  ; pointer. verbose but sadly necessary for now
(array file (square))  ; ranks and files are arrays of squares
(address file-address (file))
(address file-address-address (file-address))  ; pointer to a pointer
(array board (file-address))
(address board-address (board))

(function init-board [
  (default-space:space-address <- new space:literal 30:literal)
  (initial-position:integer-array-address <- next-input)
  ; assert(length(initial-position) == 64)
;?   ($print initial-position:integer-array-address/deref) ;? 1
  (len:integer <- length initial-position:integer-array-address/deref)
;?   ($print len:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (correct-length?:boolean <- equal len:integer 64:literal)
  (assert correct-length?:boolean (("chessboard had incorrect size" literal)))
  (b:board-address <- new board:literal 8:literal)
  (col:integer <- copy 0:literal)
  { begin
    (done?:boolean <- equal col:integer 8:literal)
    (break-if done?:boolean)
    (file:file-address-address <- index-address b:board-address/deref col:integer)
    (file:file-address-address/deref <- init-file initial-position:integer-array-address col:integer)
    (col:integer <- add col:integer 1:literal)
    (loop)
  }
  (reply b:board-address)
])

(function init-file [
  (default-space:space-address <- new space:literal 30:literal)
  (position:integer-array-address <- next-input)
  (index:integer <- next-input)
  (index:integer <- multiply index:integer 8:literal)
  (result:file-address <- new file:literal 8:literal)
  (row:integer <- copy 0:literal)
  { begin
    (done?:boolean <- equal row:integer 8:literal)
    (break-if done?:boolean)
    (dest:square-address <- index-address result:file-address/deref row:integer)
    (dest:square-address/deref <- index position:integer-array-address/deref index:integer)
    (row:integer <- add row:integer 1:literal)
    (index:integer <- add index:integer 1:literal)
    (loop)
  }
  (reply result:file-address)
])

(function print-board [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (b:board-address <- next-input)
  (row:integer <- copy 7:literal)
  ; print each row
  { begin
    (done?:boolean <- less-than row:integer 0:literal)
    (break-if done?:boolean)
    ; print rank number as a legend
    (rank:integer <- add row:integer 1:literal)
    (print-integer screen:terminal-address rank:integer)
    (s:string-address <- new " | ")
    (print-string screen:terminal-address s:string-address)
    ; print each square in the row
    (col:integer <- copy 0:literal)
    { begin
      (done?:boolean <- equal col:integer 8:literal)
      (break-if done?:boolean)
      (f:file-address <- index b:board-address/deref col:integer)
      (s:square <- index f:file-address/deref row:integer)
      (print-character screen:terminal-address s:square)
      (print-character screen:terminal-address ((#\space literal)))
      (col:integer <- add col:integer 1:literal)
      (loop)
    }
    (row:integer <- subtract row:integer 1:literal)
    (cursor-to-next-line screen:terminal-address)
    (loop)
  }
  ; print file letters as legend
  (s:string-address <- new "  +----------------")
  (print-string screen:terminal-address s:string-address)
  (cursor-to-next-line screen:terminal-address)
  (s:string-address <- new "    a b c d e f g h")
  (print-string screen:terminal-address s:string-address)
  (cursor-to-next-line screen:terminal-address)
])

;; data structure: move
(and-record move [
  from:integer-integer-pair
  to:integer-integer-pair
])

(address move-address (move))

(function read-move [
  (default-space:space-address <- new space:literal 30:literal)
  (stdin:channel-address <- next-input)
  (from-file:integer <- read-file stdin:channel-address)
  { begin
    (break-if from-file:integer)
    (reply nil:literal)
  }
  (from-rank:integer <- read-rank stdin:channel-address)
  (expect-stdin stdin:channel-address ((#\- literal)))
  (to-file:integer <- read-file stdin:channel-address)
  (to-rank:integer <- read-rank stdin:channel-address)
  (expect-stdin stdin:channel-address ((#\newline literal)))
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

; todo: assumes stdin is always at raw address 1
(function read-file [
  (default-space:space-address <- new space:literal 30:literal)
  (stdin:channel-address <- next-input)
  (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
;?   ($print x:tagged-value) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (a:character <- copy ((#\a literal)))
  (file-base:integer <- character-to-integer a:character)
  (c:character <- maybe-coerce x:tagged-value character:literal)
;?   ($print (("AAA " literal))) ;? 1
;?   ($print c:character) ;? 1
;?   ($print (("\n" literal))) ;? 1
  { begin
    (quit:boolean <- equal c:character ((#\q literal)))
    (break-unless quit:boolean)
    (reply nil:literal)
  }
  (file:integer <- character-to-integer c:character)
  (file:integer <- subtract file:integer file-base:integer)
  ; assert('a' <= from-file <= 'h')
  (above-min:boolean <- greater-or-equal file:integer 0:literal)
  (assert above-min:boolean (("file too low" literal)))
  (below-max:boolean <- lesser-or-equal file:integer 7:literal)
  (assert below-max:boolean (("file too high" literal)))
  (reply file:integer)
])

(function read-rank [
  (default-space:space-address <- new space:literal 30:literal)
  (stdin:channel-address <- next-input)
  (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
  (c:character <- maybe-coerce x:tagged-value character:literal)
;?   ($print (("BBB " literal))) ;? 1
;?   ($print c:character) ;? 1
;?   ($print (("\n" literal))) ;? 1
  { begin
    (quit:boolean <- equal c:character ((#\q literal)))
    (break-unless quit:boolean)
    (reply nil:literal)
  }
  (rank:integer <- character-to-integer c:character)
  (one:character <- copy ((#\1 literal)))
  (rank-base:integer <- character-to-integer one:character)
  (rank:integer <- subtract rank:integer rank-base:integer)
  ; assert('1' <= rank <= '8')
  (above-min:boolean <- greater-or-equal rank:integer 0:literal)
  (assert above-min:boolean (("rank too low" literal)))
  (below-max:boolean <- lesser-or-equal rank:integer 7:literal)
  (assert below-max:boolean (("rank too high" literal)))
  (reply rank:integer)
])

; slurp a character and check that it matches
(function expect-stdin [
  (default-space:space-address <- new space:literal 30:literal)
  (stdin:channel-address <- next-input)
  (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
  (c:character <- maybe-coerce x:tagged-value character:literal)
  (expected:character <- next-input)
  (match?:boolean <- equal c:character expected:character)
  (assert match?:boolean (("expected character not found" literal)))
])

(function make-move [
  (default-space:space-address <- new space:literal 30:literal)
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
  (src:square-address/deref <- copy ((#\_ literal)))
  (reply b:board-address)
])

(function chessboard [
  (default-space:space-address <- new space:literal 30:literal)
  (initial-position:integer-array-address <- init-array ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal))
                                                        ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                        ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                        ((#\Q literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\q literal))
                                                        ((#\K literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\k literal))
                                                        ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                        ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                        ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal)))
  (b:board-address <- init-board initial-position:integer-array-address)
  (cursor-mode)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit nil:literal/keyboard stdin:channel-address)
  ; buffer stdin
  (buffered-stdin:channel-address <- init-channel 1:literal)
  (fork-helper buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
  ($print (("Stupid text-mode chessboard. White pieces in uppercase; black pieces in lowercase. No checking for legal moves." literal)))
  (cursor-to-next-line nil:literal/terminal)
  { begin
    (cursor-to-next-line nil:literal/terminal)
    (print-board nil:literal/terminal b:board-address)
    (cursor-to-next-line nil:literal/terminal)
    ($print (("Type in your move as <from square>-<to square>. For example: 'a2-a4'. Then press <enter>." literal)))
    (cursor-to-next-line nil:literal/terminal)
    ($print (("Hit 'q' to exit." literal)))
    (cursor-to-next-line nil:literal/terminal)
    ($print (("move: " literal)))
    (m:move-address <- read-move buffered-stdin:channel-address)
;?     (retro-mode) ;? 1
;?     ($print stdin:channel-address) ;? 1
;?     ($print (("\n" literal))) ;? 1
;?     ($print buffered-stdin:channel-address) ;? 1
;?     ($print (("\n" literal))) ;? 1
;?     ($dump-memory) ;? 1
;?     (cursor-mode) ;? 1
    (break-unless m:move-address)
    (b:board-address <- make-move b:board-address m:move-address)
    (loop)
  }
  (retro-mode)
])

(function main [
  (chessboard)
])

; todo:
;   backspace, ctrl-u
