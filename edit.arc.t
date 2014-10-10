(load "mu.arc")

(on-init
  (= types* (obj
              ; Each type must be scalar or array, sum or product or primitive
              location (obj size 1)
              integer (obj size 1)
              boolean (obj size 1)
              boolean-address (obj size 1  address t)
              byte (obj size 1)
;?               string (obj array t  elem 'byte)  ; inspired by Go
              character (obj size 1)  ; int32 like a Go rune
              character-address (obj size 1  address t  elem 'character)
              string (obj size 1)  ; temporary hack
              ; arrays consist of an integer length followed by the right number of elems
              integer-array (obj array t  elem 'integer)
              integer-address (obj size 1  address t  elem 'integer)  ; pointer to int
              ; records consist of a series of elems, corresponding to a list of types
              integer-boolean-pair (obj size 2  record t  elems '(integer boolean))
              ; editor
              line (obj array t  elem 'character)
              line-address (obj size 1  address t  elem 'line)
              line-address-address (obj size 1  address t  elem 'line-address)
              screen (obj array t  elem 'line-address)
              screen-address (obj size 1  address t  elem 'screen)
              )))

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
