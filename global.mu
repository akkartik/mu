# example program: creating and using global variables

recipe main [
  # allocate 5 locations for globals
  global-space:address:shared:array:location <- new location:type, 5
  # read to globals by using /space:global
  1:number/space:global <- copy 3
  foo
]

recipe foo [
  # ditto for writing to globals
  $print 1:number/space:global, 10/newline
]
