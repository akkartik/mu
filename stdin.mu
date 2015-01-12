(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (console-on)
  (clear-screen)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
;?   (print-primitive (("main: stdin is " literal)))
;?   (print-primitive stdin:channel-address)
;?   (print-primitive (("\n" literal)))
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit stdin:channel-address)
  ; now read characters from stdin until a 'q' is typed
  (print-primitive (("? " literal)))
  { begin
    (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
;?     (print-primitive (("main: stdin is " literal)))
;?     (print-primitive stdin:channel-address)
;?     (print-primitive (("\n" literal)))
;?     (print-primitive (("check: " literal)))
;?     (print-primitive c:character)
    (done?:boolean <- equal c:character ((#\q literal)))
    (break-if done?:boolean)
    (print-primitive c:character)
    (loop)
  }
])
