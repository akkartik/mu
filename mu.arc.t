(load "mu.arc")

(run '(
  (1 <- loadi 1)
  (2 <- loadi 3)
  (3 <- add 1 2)))
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - load and add instructions work"))
