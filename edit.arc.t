(load "mu.arc")

(reset)
(new-trace "new-screen")
(add-code:readfile "edit.mu")
(add-code
  '((def test-new-screen [
      ((2001 screen-address) <- new-screen (5 literal) (5 literal))
     ])))
;? (each stmt function*!new-screen
;?   (prn stmt))
(let before Memory-in-use-until
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
  (run 'test-new-screen)
;?   (prn memory*)
;?   (prn memory*!2001)
  (when (~is (memory* memory*!2001) 5)  ; number of rows
    (prn "F - newly-allocated screen doesn't have the right number of rows: @(memory* memory*!2001)"))
  (let row-pointers (let base (+ 1 memory*!2001)
                      (range base (+ base 4)))
;?     (prn row-pointers)
    (when (some nil (map memory* row-pointers))
      (prn "F - newly-allocated screen didn't initialize all of its row pointers"))
    (when (~all 5 (map memory* (map memory* row-pointers)))
      (prn "F - newly-allocated screen didn't initialize all of its row lengths"))))

(reset)
