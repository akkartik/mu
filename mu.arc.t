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
      (reply)
      (4 <- loadi 34))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (add-fn))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - early return works"))
;? (quit)

(clear)
(add-fns
  '((add-fn
      (4 <- read)
      (5 <- read)
      (3 <- add 4 5)
      (reply)
      (4 <- loadi 34))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (add-fn 1 2)
    )))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - parameterized compound fn"))

(clear)
(add-fns
  '((add-fn
      (4 <- read)
      (5 <- read)
      (6 <- add 4 5)
      (reply 6)
      (4 <- loadi 34))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (3 <- add-fn 1 2))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3  6 4))
  (prn "F - parameterized compound fn with return value"))

(clear)
(add-fns
  '((add-fn
      (4 <- read)
      (5 <- read)
      (6 <- add 4 5)
      (reply 6 5)
      (4 <- loadi 34))
    (main
      (1 <- loadi 1)
      (2 <- loadi 3)
      (3 7 <- add-fn 1 2))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; add-fn's temporaries
                         4 1  5 3  6 4))
  (prn "F - parameterized compound fn with multiple return values"))
