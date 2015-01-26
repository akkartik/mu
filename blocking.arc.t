(selective-load "mu.arc" section-level)

(reset)
(new-trace "blocking-example")
(add-code
  '((function reader [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:tagged-value 1:channel-address/space:global/nochange <- read 1:channel-address/space:global)
     ])
    (function main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (1:channel-address <- init-channel 3:literal)
      (2:integer/routine <- fork-helper reader:fn default-space:space-address/globals 50:literal/limit)
      ; write nothing to the channel
;?       (sleep until-routine-done:literal 2:integer/routine)
     ])))
;? (= dump-trace* (obj whitelist '("schedule" "run")))
(run 'main)
;? (prn "completed:")
;? (each r completed-routines*
;?   (prn " " r))
(when (ran-to-completion 'reader)
  (prn "F - reader waits for input"))

(reset)
