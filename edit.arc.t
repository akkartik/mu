(load "mu.arc")

(reset)
(new-trace "new-screen")
;? (set dump-trace*)
(add-fns:readfile "edit.mu")
(add-fns
  '((test-new-screen
      ((curr-screen screen-address) <- new-screen (5 literal) (5 literal))
      )))
;? (each stmt function*!new-screen
;?   (prn stmt))
(let before Memory-in-use-until
  (run 'test-new-screen)
;?   (prn memory*)
  (when (~is (- Memory-in-use-until before) 36)  ; 5+1 * 5+1
    (prn "F - new-screen didn't allocate enough memory: @(- Memory-in-use-until before)"))
;?   (prn memory*!curr-screen)
  (when (~is (memory* memory*!curr-screen) 5)  ; number of rows
    (prn "F - newly-allocated screen doesn't have the right number of rows: @(memory* memory*!curr-screen)"))
  (let row-pointers (let base (+ 1 memory*!curr-screen)
                      (range base (+ base 4)))
;?     (prn row-pointers)
    (when (some nil (map memory* row-pointers))
      (prn "F - newly-allocated screen didn't initialize all of its row pointers"))
;?     (when (~iso (prn:map memory* row-pointers)
    (when (~iso (map memory* row-pointers)
                (list (+ before 6)
                      (+ before 12)
                      (+ before 18)
                      (+ before 24)
                      (+ before 30)))
      (prn "F - newly-allocated screen incorrectly initialized its row pointers"))
    (when (~all 5 (map memory* (map memory* row-pointers)))
      (prn "F - newly-allocated screen didn't initialize all of its row lengths"))))

(reset)
