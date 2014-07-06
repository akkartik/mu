(load "mu.arc")

(clear)
(add-fns '((test1
  (1 <- loadi 1)
  (2 <- loadi 3)
  (3 <- add 1 2))))
(run function*!test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - load and add instructions work"))

(clear)
(add-fns
  '((add-fn
      (3 <- add 1 2))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (add-fn))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - compound functions work"))

(clear)
(add-fns
  '((add-fn
      (3 <- add 1 2)
      (return)
      (4 <- loadi 34))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (add-fn))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - early return works"))
