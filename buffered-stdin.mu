; reads lines, prints them back when you hit 'enter'
; dies if you wait a while, because so far we never free memory
(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode) ;? 1
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit nil:literal/keyboard stdin:channel-address)
  ; buffer stdin
  (buffered-stdin:channel-address <- init-channel 1:literal)
  (fork-helper buffer-stdin:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
  { begin
    ; now read characters from the buffer until 'enter' is typed
    (s:string-address <- new "? ")
    (print-string nil:literal/terminal s:string-address)
    { begin
      (x:tagged-value buffered-stdin:channel-address/deref <- read buffered-stdin:channel-address)
      (c:character <- maybe-coerce x:tagged-value character:literal)
;?       ($print (("AAA " literal))) ;? 1
;?       ($print c:character) ;? 1
;?       ($print (("\n" literal))) ;? 1
      (print-character nil:literal/terminal c:character)
      (line-done?:boolean <- equal c:character ((#\newline literal)))
      (loop-unless line-done?:boolean)
    }
    (loop)
  }
])
