(selective-load "mu.arc" section-level)

(reset)
(new-trace "read-move-legal")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 3:literal)
      (r:integer/routine <- fork read-move:fn nil:literal/globals 200:literal/limit)
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
;? (quit)

(reset)
(new-trace "read-move-incomplete")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 3:literal)
      (r:integer/routine <- fork-helper read-move:fn nil:literal/globals 200:literal/limit)
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

(reset)
(new-trace "read-move-quit")
(add-code:readfile "chessboard-cursor.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address/raw <- init-channel 3:literal)
      (r:integer/routine <- fork-helper read-move:fn nil:literal/globals nil:literal/limit)
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
      (1:channel-address/raw <- init-channel 3:literal)
      (r:integer/routine <- fork-helper read-file:fn nil:literal/globals nil:literal/limit)
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
      (1:channel-address/raw <- init-channel 3:literal)
      (r:integer/routine <- fork-helper read-rank:fn nil:literal/globals nil:literal/limit)
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
  (prn "F - print-board doesn't work; chessboard begins at @memory*.5"))

(reset)
