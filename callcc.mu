# example program: saving and reusing call-stacks or continuations

recipe main [
  c:continuation <- f
  continue-from c:continuation            # <-- ..when you hit this
]

recipe f [
  c:continuation <- g
  reply c:continuation
]

recipe g [
  c:continuation <- current-continuation  # <-- loop back to here
  $print 1:literal
  reply c:continuation  # threaded through unmodified after first iteration
]
