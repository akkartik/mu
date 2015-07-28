# example program: running multiple routines

recipe main [
  start-running thread2:recipe
  {
    $print 34
    loop
  }
]

recipe thread2 [
  {
    $print 35
    loop
  }
]
