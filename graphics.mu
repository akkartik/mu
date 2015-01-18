; open a viewport, print coordinates of mouse clicks
; currently need to ctrl-c to exit after closing the viewport
(function main [
  (window-on (("practice" literal)) 300:literal 300:literal)
  { begin
    (pos:integer-integer-pair click?:boolean <- mouse-position)
    (loop-unless click?:boolean)
    (x:integer <- get pos:integer-integer-pair 0:offset)
    (y:integer <- get pos:integer-integer-pair 1:offset)
;?     (print-primitive-to-host (("AAA " literal)))
;?     (print-primitive-to-host x:integer)
;?     (print-primitive-to-host ((", " literal)))
;?     (print-primitive-to-host y:integer)
;?     (print-primitive-to-host (("\n" literal)))
    (print-integer nil:literal/terminal x:integer)
    (print-primitive-to-host ((", " literal)))
    (print-integer nil:literal/terminal y:integer)
    (print-primitive-to-host (("\n" literal)))
    (loop)
  }
  (window-off)
])
