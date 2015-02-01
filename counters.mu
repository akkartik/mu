(function init-counter [
  (default-space:space-address <- new space:literal 30:literal)
  (n:integer <- next-input)
  (reply default-space:space-address)
 ])

(function increment-counter [
  (default-space:space-address <- new space:literal 30:literal)
  (0:space-address/names:init-counter <- next-input)  ; setup outer space; it *must* come from 'init-counter'
  (x:integer <- next-input)
  (n:integer/space:1 <- add n:integer/space:1 x:integer)
  (reply n:integer/space:1)
 ])

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  ; counter A
  (a:space-address <- init-counter 34:literal)
  ; counter B
  (b:space-address <- init-counter 23:literal)
  ; increment both by 2 but in different ways
  (increment-counter a:space-address 1:literal)
  (bres:integer <- increment-counter b:space-address 2:literal)
  (ares:integer <- increment-counter a:space-address 1:literal)
  ; check results
  ($print (("Contents of counters a: " literal)))
  (print-integer nil:literal/terminal ares:integer)
  ($print ((" b: " literal)))
  (print-integer nil:literal/terminal bres:integer)
  ($print (("\n" literal)))
 ])

; compare http://www.paulgraham.com/accgen.html
