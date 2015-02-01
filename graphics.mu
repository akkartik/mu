; open a viewport, print coordinates of mouse clicks
; currently need to ctrl-c to exit after closing the viewport
(function main [
  (window-on (("practice" literal)) 300:literal 300:literal)
  { begin
    (pos:integer-integer-pair click?:boolean <- mouse-position)
    (loop-unless click?:boolean)
    (x:integer <- get pos:integer-integer-pair 0:offset)
    (y:integer <- get pos:integer-integer-pair 1:offset)
;?     ($print (("AAA " literal)))
;?     ($print x:integer)
;?     ($print ((", " literal)))
;?     ($print y:integer)
;?     ($print (("\n" literal)))
    (print-integer nil:literal/terminal x:integer)
    (print-character nil:literal/terminal ((#\, literal)))
    (print-character nil:literal/terminal ((#\space literal)))
    (print-integer nil:literal/terminal y:integer)
    (print-character nil:literal/terminal ((#\newline literal)))
    (loop)
  }
  (window-off)
])
