# example program: creating and using global variables

def main [
  # allocate 5 locations for globals
  global-space:space <- new location:type, 5
  # read to globals by using /space:global
  1:num/space:global <- copy 3
  foo
]

def foo [
  # ditto for writing to globals
  $print 1:num/space:global, 10/newline
]
