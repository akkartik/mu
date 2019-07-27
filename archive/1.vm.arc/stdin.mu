; reads and prints keys until you hit 'q'
; no need to hit 'enter', and 'enter' has no special meaning
; dies if you wait a while, because so far we never free memory
(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
;?   ($print (("main: stdin is " literal)))
;?   ($print stdin:channel-address)
;?   ($print (("\n" literal)))
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit nil:literal/keyboard stdin:channel-address)
  ; now read characters from stdin until a 'q' is typed
  ($print (("? " literal)))
  { begin
    (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
;?     ($print (("main: stdin is " literal)))
;?     ($print stdin:channel-address)
;?     ($print (("\n" literal)))
;?     ($print (("check: " literal)))
;?     ($print c:character)
    (done?:boolean <- equal c:character ((#\q literal)))
    (break-if done?:boolean)
    (loop)
  }
])
