(load "mu.arc")

(reset)
(add-fns:readfile "edit.mu")
(add-fns
  '((test-new-screen
      ((curr-screen screen-address) <- new-screen (5 literal) (5 literal))
      )))
(run 'test-new-screen)
(prn memory*)

;? (reset)
;? (add-fns:readfile "edit.mu")
;? (add-fns
;?   '((test-redraw
;?       ((curr-screen screen-address) <- new-screen (5 literal) (5 literal))
;?       ((x line-address) <- get-address (curr-screen screen) (2 offset))
;?       ((y character-address) <- get-address (x line-address deref) (4 offset))
;?       ((y character-address deref) <- copy (literal "a"))
;?       )))
;? (run 'test-redraw)
;? (prn memory*)
