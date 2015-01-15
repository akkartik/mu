(function main [
  (fork thread2:fn)
  (default-space:space-address <- new space:literal 2:literal)
  (x:integer <- copy 34:literal)
  { begin
    (print-primitive nil:literal/terminal x:integer)
    (loop)
  }
])

(function thread2 [
  (default-space:space-address <- new space:literal 2:literal)
  (y:integer <- copy 35:literal)
  { begin
    (print-primitive nil:literal/terminal y:integer)
    (loop)
  }
])
