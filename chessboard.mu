(function read-board [
  (default-scope:scope-address <- new scope:literal 30:literal)
  (initial-position:list-address <- init-list R:literal N:literal B:literal Q:literal K:literal B:literal N:literal R:literal
                                              P:literal P:literal P:literal P:literal P:literal P:literal P:literal P:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              _:literal _:literal _:literal _:literal _:literal _:literal _:literal _:literal
                                              p:literal p:literal p:literal p:literal p:literal p:literal p:literal p:literal
                                              r:literal n:literal b:literal q:literal k:literal b:literal n:literal r:literal)
  ; assert(length(initial-position) == 64)
  (len:integer <- list-length initial-position:list-address)
  (print-primitive len:integer)
  (reply)
;?   (b:board <- read-board initial-position:list)
;?   (print-board b:board)
])

(function print-board [

])

(function main [
  (read-board)
])
