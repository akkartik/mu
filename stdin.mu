(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  (clear-screen)
  ; hook up stdin
  (stdin:channel-address <- init-channel 1:literal)
;?   (print-primitive-to-host (("main: stdin is " literal)))
;?   (print-primitive-to-host stdin:channel-address)
;?   (print-primitive-to-host (("\n" literal)))
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit stdin:channel-address)
  ; now read characters from stdin until a 'q' is typed
  (print-primitive-to-host (("? " literal)))
  { begin
    (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
;?     (print-primitive-to-host (("main: stdin is " literal)))
;?     (print-primitive-to-host stdin:channel-address)
;?     (print-primitive-to-host (("\n" literal)))
;?     (print-primitive-to-host (("check: " literal)))
;?     (print-primitive-to-host c:character)
    (done?:boolean <- equal c:character ((#\q literal)))
    (break-if done?:boolean)
    (print-character nil:literal/terminal c:character)
    (loop)
  }
])
