(selective-load "mu.arc" section-level)

(reset)
(new-trace "read-move-legal")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 1:literal)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (2:string-address/raw <- get screen:terminal-address/deref data:offset)
      (r:integer/routine <- fork read-move:fn nil:literal/globals 2000:literal/limit screen:terminal-address)
      (c:character <- copy ((#\a literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\2 literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\- literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\a literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\4 literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (sleep until-routine-done:literal r:integer/routine)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("schedule")))
(run 'main)
(each routine completed-routines*
;?   (prn "  " routine)
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~ran-to-completion 'read-move)
  (prn "F - chessboard accepts legal moves (<rank><file>-<rank><file>)"))
(when (~memory-contains-array memory*.2 "a2-a4")
  (prn "F - chessboard prints moves read from keyboard"))
;? (quit)

(reset)
(new-trace "read-move-incomplete")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 1:literal)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (2:string-address/raw <- get screen:terminal-address/deref data:offset)
      (r:integer/routine <- fork-helper read-move:fn nil:literal/globals 2000:literal/limit screen:terminal-address)
      (c:character <- copy ((#\a literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\2 literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\- literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (c:character <- copy ((#\a literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (sleep until-routine-done:literal r:integer/routine)
     ])))
(run 'main)
(when (ran-to-completion 'read-move)
  (prn "F - chessboard hangs until 5 characters are entered"))
(when (~memory-contains-array memory*.2 "a2-a")
  (prn "F - chessboard prints keys from keyboard before entire move is read"))

(reset)
(new-trace "read-move-quit")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 1:literal)
      (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (r:integer/routine <- fork-helper read-move:fn nil:literal/globals nil:literal/limit dummy:terminal-address)
      (c:character <- copy ((#\q literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (sleep until-routine-done:literal r:integer/routine)
     ])))
(run 'main)
(when (~ran-to-completion 'read-move)
  (prn "F - chessboard quits on move starting with 'q'"))

(reset)
(new-trace "read-illegal-file")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 1:literal)
      (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (r:integer/routine <- fork-helper read-file:fn nil:literal/globals nil:literal/limit dummy:terminal-address)
      (c:character <- copy ((#\i literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (sleep until-routine-done:literal r:integer/routine)
     ])))
;? (= dump-trace* (obj whitelist '("schedule")))
(run 'main)
;? (each routine completed-routines*
;?   (prn "  " routine))
(when (or (ran-to-completion 'read-file)
          (let routine routine-running!read-file
            (~posmatch "file too high" rep.routine!error)))
  (prn "F - 'read-file' checks that file lies between 'a' and 'h'"))

(reset)
(new-trace "read-illegal-rank")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 1:literal)
      (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (r:integer/routine <- fork-helper read-rank:fn nil:literal/globals nil:literal/limit dummy:terminal-address)
      (c:character <- copy ((#\9 literal)))
      (x:tagged-value <- save-type c:character)
      (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value)
      (sleep until-routine-done:literal r:integer/routine)
     ])))
(run 'main)
(when (or (ran-to-completion 'read-rank)
          (let routine routine-running!read-rank
            (~posmatch "rank too high" rep.routine!error)))
  (prn "F - 'read-rank' checks that rank lies between '1' and '8'"))

(reset)
(new-trace "print-board")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (initial-position:list-address <- init-list ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal))
                                                  ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                  ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                  ((#\Q literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\q literal))
                                                  ((#\K literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\k literal))
                                                  ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                  ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                  ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal)))
      (b:board-address <- init-board initial-position:list-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (print-board screen:terminal-address b:board-address)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.5)
(when (~memory-contains-array memory*.5
          (+ "8 | r n b q k b n r "
             "7 | p p p p p p p p "
             "6 | _ _ _ _ _ _ _ _ "
             "5 | _ _ _ _ _ _ _ _ "
             "4 | _ _ _ _ _ _ _ _ "
             "3 | _ _ _ _ _ _ _ _ "
             "2 | P P P P P P P P "
             "1 | R N B Q K B N R "
             "  +---------------- "
             "    a b c d e f g h "))
  (prn "F - print-board works; chessboard begins at @memory*.5"))

; todo: how to fold this more elegantly with the previous test?
(reset)
(new-trace "make-move")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      ; hook up stdin
      (1:channel-address/raw <- init-channel 1:literal)
      ; fake screen
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      ; initial position
      (initial-position:list-address <- init-list ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal))
                                                  ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                  ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                  ((#\Q literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\q literal))
                                                  ((#\K literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\k literal))
                                                  ((#\B literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\b literal))
                                                  ((#\N literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\n literal))
                                                  ((#\R literal)) ((#\P literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\_ literal)) ((#\p literal)) ((#\r literal)))
      (b:board-address <- init-board initial-position:list-address)
      ; move: a2-a4
      (m:move-address <- new move:literal)
      (f:integer-integer-pair-address <- get-address m:move-address/deref from:offset)
      (dest:integer-address <- get-address f:integer-integer-pair-address/deref 0:offset)
      (dest:integer-address/deref <- copy 0:literal)  ; from-file: a
      (dest:integer-address <- get-address f:integer-integer-pair-address/deref 1:offset)
      (dest:integer-address/deref <- copy 1:literal)  ; from-rank: 2
      (t0:integer-integer-pair-address <- get-address m:move-address/deref to:offset)
      (dest:integer-address <- get-address t0:integer-integer-pair-address/deref 0:offset)
      (dest:integer-address/deref <- copy 0:literal)  ; to-file: a
      (dest:integer-address <- get-address t0:integer-integer-pair-address/deref 1:offset)
      (dest:integer-address/deref <- copy 3:literal)  ; to-rank: 4
      (b:board-address <- make-move b:board-address m:move-address)
      (print-board screen:terminal-address b:board-address)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.5)
(when (~memory-contains-array memory*.5
          (+ "8 | r n b q k b n r "
             "7 | p p p p p p p p "
             "6 | _ _ _ _ _ _ _ _ "
             "5 | _ _ _ _ _ _ _ _ "
             "4 | P _ _ _ _ _ _ _ "
             "3 | _ _ _ _ _ _ _ _ "
             "2 | _ P P P P P P P "
             "1 | R N B Q K B N R "
             "  +---------------- "
             "    a b c d e f g h "))
  (prn "F - make-move works; chessboard begins at @memory*.5"))

(reset)
