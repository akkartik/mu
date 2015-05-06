recipe main [
  start-running thread2:recipe
  default-space:address:array:location <- new location:type, 2:literal
  x:integer <- copy 34:literal
  {
    $print x:integer
    loop
  }
]

recipe thread2 [
  default-space:address:array:location <- new location:type, 2:literal
  y:integer <- copy 35:literal
  {
    $print y:integer
    loop
  }
]
