; reads lines, prints when you hit 'enter'
; dies if you wait a while, because so far we never free memory
(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  (clear-screen)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit nil:literal/keyboard stdin:channel-address)
  ; buffer stdin
  (buffered-stdin:channel-address <- init-channel 1:literal)
  (fork-helper buffer-stdin:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
  ; now read characters from the buffer until a 'enter' is typed
  (s:string-address <- new "? ")
  (print-string nil:literal/terminal s:string-address)
  { begin
    (x:tagged-value stdin:channel-address/deref <- read buffered-stdin:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
;?     (print-primitive-to-host (("AAA " literal))) ;? 0
;?     (print-primitive-to-host c:character) ;? 0
;?     (print-primitive-to-host (("\n" literal))) ;? 0
    (done?:boolean <- equal c:character ((#\newline literal)))
    (break-if done?:boolean)
    (print-character nil:literal/terminal c:character)
    (loop)
  }
])
