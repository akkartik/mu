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
    (print-primitive-to-host (("produce: " literal)))
    (print-integer nil:literal/terminal n:integer)
    (print-primitive-to-host (("\n" literal)))
    ; 'box' n into a dynamically typed 'tagged value' because that's what
    ; channels take
    (n2:integer <- copy n:integer)
    (n3:tagged-value-address <- init-tagged-value integer:literal n2:integer)
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
    (n2:integer <- maybe-coerce x:tagged-value integer:literal)
    ; other threads might get between these prints
    (print-primitive-to-host (("consume: " literal)))
    (print-integer nil:literal/terminal n2:integer)
    (print-primitive-to-host (("\n" literal)))
    (loop)
  }
])

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel-address <- init-channel 3:literal)
  ; create two background 'routines' that communicate by a channel
  (routine1:integer <- fork consumer:fn nil:literal/globals nil:literal/limit chan:channel-address)
  (routine2:integer <- fork producer:fn nil:literal/globals nil:literal/limit chan:channel-address)
  (sleep until-routine-done:literal routine1:integer)
  (sleep until-routine-done:literal routine2:integer)
])
