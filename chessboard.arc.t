(selective-load "mu.arc" section-level)
(set allow-raw-addresses*)
(add-code:readfile "chessboard.mu")
(freeze function*)
(load-system-functions)

(reset2)
(new-trace "read-move-legal")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (stdin:channel-address <- init-channel 1:literal)
  (r:integer/routine <- fork read-move:fn nil:literal/globals 2000:literal/limit stdin:channel-address)
  (c:character <- copy ((#\a literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (c:character <- copy ((#\2 literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (c:character <- copy ((#\- literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (c:character <- copy ((#\a literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (c:character <- copy ((#\4 literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (c:character <- copy ((#\newline literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (sleep until-routine-done:literal r:integer/routine)
)
(each routine completed-routines*
;?   (prn "  " routine)
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~ran-to-completion 'read-move)
  (prn "F - chessboard accepts legal moves (<rank><file>-<rank><file>)"))
; todo: we can't test that keys pressed are printed to screen
; but that's at a lower level
;? (quit)

(reset2)
(new-trace "read-move-incomplete")
; initialize some variables at specific raw locations
;? (prn "== init")
(run-code test-init
  (1:channel-address/raw <- init-channel 1:literal)
  (2:terminal-address/raw <- init-fake-terminal 20:literal 10:literal)
  (3:string-address/raw <- get 2:terminal-address/raw/deref data:offset))
(wipe completed-routines*)
; the component under test; we'll be running this repeatedly
(let read-move-routine (make-routine 'read-move memory*.1 memory*.2)
;?   (prn "== first key")
  (run-code send-first-key
    (default-space:space-address <- new space:literal 30:literal/capacity)
    (c:character <- copy ((#\a literal)))
    (x:tagged-value <- save-type c:character)
    (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value))
  (wipe completed-routines*)
  ; check that read-move consumes it and then goes to sleep
  (enq read-move-routine running-routines*)
  (run-more)
  (when (ran-to-completion 'read-move)
    (prn "F - chessboard waits after first letter of move"))
  (wipe completed-routines*)
  ; send in a few more letters
;?   (prn "== more keys")
  (restart read-move-routine)
  (run-code send-more-keys
    (default-space:space-address <- new space:literal 30:literal/capacity)
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
    (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value))
  ; check that read-move consumes them and then goes to sleep
  (when (ran-to-completion 'read-move)
    (prn "F - chessboard waits after each subsequent letter of move until the last"))
  (wipe completed-routines*)
  ; send final key
;?   (prn "== final key")
  (restart read-move-routine)
;?   (set dump-trace*)
  (run-code send-final-key
    (default-space:space-address <- new space:literal 30:literal/capacity)
    (c:character <- copy ((#\newline literal)))
    (x:tagged-value <- save-type c:character)
    (1:channel-address/raw/deref <- write 1:channel-address/raw x:tagged-value))
  ; check that read-move consumes it and -- this time -- returns
  (when (~ran-to-completion 'read-move)
    (prn "F - 'read-move' completes after final letter of move"))
)

(reset2)
(new-trace "read-move-quit")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (stdin:channel-address <- init-channel 1:literal)
  (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
  (r:integer/routine <- fork-helper read-move:fn nil:literal/globals 2000:literal/limit stdin:channel-address dummy:terminal-address)
  (c:character <- copy ((#\q literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (sleep until-routine-done:literal r:integer/routine)
)
(when (~ran-to-completion 'read-move)
  (prn "F - chessboard quits on move starting with 'q'"))

(reset2)
(new-trace "read-illegal-file")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (stdin:channel-address <- init-channel 1:literal)
  (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
  (r:integer/routine <- fork-helper read-file:fn nil:literal/globals 2000:literal/limit stdin:channel-address dummy:terminal-address)
  (c:character <- copy ((#\i literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (sleep until-routine-done:literal r:integer/routine)
)
;? (each routine completed-routines*
;?   (prn "  " routine))
(when (or (ran-to-completion 'read-file)
          (let routine routine-running!read-file
            (~posmatch "file too high" rep.routine!error)))
  (prn "F - 'read-file' checks that file lies between 'a' and 'h'"))

(reset2)
(new-trace "read-illegal-rank")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (stdin:channel-address <- init-channel 1:literal)
  (dummy:terminal-address <- init-fake-terminal 20:literal 10:literal)
  (r:integer/routine <- fork-helper read-rank:fn nil:literal/globals 2000:literal/limit stdin:channel-address dummy:terminal-address)
  (c:character <- copy ((#\9 literal)))
  (x:tagged-value <- save-type c:character)
  (stdin:channel-address/deref <- write stdin:channel-address x:tagged-value)
  (sleep until-routine-done:literal r:integer/routine)
)
(when (or (ran-to-completion 'read-rank)
          (let routine routine-running!read-rank
            (~posmatch "rank too high" rep.routine!error)))
  (prn "F - 'read-rank' checks that rank lies between '1' and '8'"))

(reset2)
(new-trace "print-board")
(run-code main
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
  (1:string-address/raw <- get screen:terminal-address/deref data:offset)
)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.1)
(when (~screen-contains memory*.1 20
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
  (prn "F - print-board works; chessboard begins at @memory*.1"))

; todo: how to fold this more elegantly with the previous test?
(reset2)
(new-trace "make-move")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
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
  (1:string-address/raw <- get screen:terminal-address/deref data:offset)
)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.1)
(when (~screen-contains memory*.1 20
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
  (prn "F - make-move works; chessboard begins at @memory*.1"))

(reset2)
