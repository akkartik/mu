# example program: saving and reusing call-stacks or continuations

recipe main [
  c:continuation <- f
  continue-from c                         # <-- ..when you hit this
]

recipe f [
  c:continuation <- g
  reply c
]

recipe g [
  c:continuation <- current-continuation  # <-- loop back to here
  $print 1
  reply c  # threaded through unmodified after first iteration
]
