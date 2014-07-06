(load "mu.arc")

(clear)
(add-fns '((test1
  (1 <- loadi 1)
  (2 <- loadi 3)
  (3 <- add 1 2))))
(run function*!test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - load and add instructions work"))
