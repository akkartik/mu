(load "mu.arc")
(set allow-raw-addresses*)

(reset)
(new-trace "p1")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))")
      (n:integer <- length x:string-address/deref)
      ($print (("p1 " literal)))
      ($print n:integer)
      ($print (("\n" literal)))
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
    ])))
(run 'main)

(reset)
(new-trace "p2")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1")
      (n:integer <- length x:string-address/deref)
      ($print (("p2 " literal)))
      ($print n:integer)
      ($print (("\n" literal)))
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
    ])))
(run 'main)

(reset)
(new-trace "p3")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3")
      (n:integer <- length x:string-address/deref)
      ($print (("p3 " literal)))
      ($print n:integer)
      ($print (("\n" literal)))
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
    ])))
(run 'main)

(reset)
(new-trace "p4")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (n:integer <- length x:string-address/deref)
      ($print (("p4 " literal)))
      ($print n:integer)
      ($print (("\n" literal)))
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
    ])))
(run 'main)

(reset)
