; open a viewport, print coordinates of mouse clicks
; currently need to ctrl-c to exit after closing the viewport
(function main [
  (graphics-on)
  { begin
    (pos:integer-integer-pair click?:boolean <- mouse-position)
    { begin
      (break-if click?:boolean)
      (loop 2:blocks)
    }
    (x:integer <- get pos:integer-integer-pair 0:offset)
    (y:integer <- get pos:integer-integer-pair 1:offset)
    (print-primitive x:integer)
    (print-primitive ((", " literal)))
    (print-primitive y:integer)
    (print-primitive (("\n" literal)))
    (loop)
  }
  (graphics-off)
])
