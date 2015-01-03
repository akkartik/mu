(function producer [
  ; produce numbers 1 to 5 on a channel
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel-address <- next-input)
  ; n = 0
  (n:integer <- copy 0:literal)
  { begin
    (done?:boolean <- less-than n:integer 5:literal)
    (break-unless done?:boolean)
    ; other threads might get between these prints
    (print-primitive (("produce: " literal)))
    (print-primitive n:integer)
    (print-primitive (("\n" literal)))
    ; 'box' n into a dynamically typed 'tagged value' because that's what
    ; channels take
    (n2:integer-address <- new integer:literal)
    (n2:integer-address/deref <- copy n:integer)
    (n3:tagged-value-address <- init-tagged-value integer-address:literal n2:integer-address)
    (chan:channel-address/deref <- write chan:channel-address n3:tagged-value-address/deref)
    (n:integer <- add n:integer 1:literal)
    (loop)
  }
])

(function consumer [
  ; consume and print integers from a channel
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel-address <- next-input)
  { begin
    ; read a tagged value from the channel
    (x:tagged-value chan:channel-address/deref <- read chan:channel-address)
    ; unbox the tagged value into an integer
    (n2:integer-address <- maybe-coerce x:tagged-value integer-address:literal)
    ; other threads might get between these prints
    (print-primitive (("consume: " literal)))
    (print-primitive n2:integer-address/deref)
    (print-primitive (("\n" literal)))
    (loop)
  }
])

(function main [
  (chan:channel-address <- init-channel 3:literal)
  ; create two background 'routines' that communicate by a channel
  (fork consumer:fn nil:literal chan:channel-address)
  (fork producer:fn nil:literal chan:channel-address)
  (sleep 2000:literal)  ; wait for forked routines to effect the transfer
])
