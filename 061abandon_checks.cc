:(scenarios transform)  // many of the tests below are *extremely* unsafe
:(scenario abandon_in_same_recipe_as_new)
recipe test [
  x:address:number <- new number:type
  abandon x
]
# no warnings

:(scenario abandon_in_separate_recipe_from_new)
recipe test [
  x:address:number <- test-new
  test-abandon x
]
recipe test-new -> result:address:number [
  result <- new number:type
]
recipe test-abandon x:address:number [
  load-ingredients
  abandon x
]
# no warnings

:(scenario define_after_abandon_in_same_recipe_as_new)
recipe test [
  x:address:number <- new number:type
  abandon x
  x <- new number:type
  reply x
]
# no warnings

:(scenario define_after_abandon_in_separate_recipe_from_new)
recipe test [
  x:address:number <- test-new
  test-abandon x
  x <- test-new
  reply x
]
recipe test-new -> result:address:number [
  result <- new number:type
]
recipe test-abandon x:address:number [
  load-ingredients
  abandon x
]
# no warnings

:(scenario abandon_inside_loop_initializing_variable)
recipe test [
  {
    x:address:number <- new number:type
    abandon x
    loop
  }
]
# no warnings

:(scenario abandon_inside_loop_initializing_variable_2)
recipe test [
  {
    x:address:number <- test-new
    test-abandon x
    loop
  }
]
recipe test-new -> result:address:number [
  result <- new number:type
]
recipe test-abandon x:address:number [
  load-ingredients
  abandon x
]
# no warnings

:(scenario abandon_inside_loop_initializing_variable_3)
recipe test [
  {
    x:address:number <- test-new
    test-abandon x
    x:address:number <- test-new  # modify x to a new value
    y:address:number <- copy x  # use x after reinitialization
    loop
  }
]
recipe test-new -> result:address:number [
  result <- new number:type
]
recipe test-abandon x:address:number [
  load-ingredients
  abandon x
]
# no warnings

:(scenario abandon_inside_loop_initializing_variable_4)
container test-list [
  value:number
  next:address:test-list
]
recipe test-cleanup x:address:test-list [
  load-ingredients
  {
    next:address:test-list <- test-next x
    test-abandon x
    x <- copy next
    loop
  }
]
recipe test-next x:address:test-list -> result:address:test-list/contained-in:x [
  load-ingredients
  result <- get *x, next:offset
]
recipe test-abandon x:address:test-list [
  load-ingredients
  abandon x
]
# no warnings

:(scenario abandon_non_unique_address_after_define)
recipe test [
  x:address:number <- new number:type
  y:address:number <- copy x
  abandon x
  y:address:number <- new number:type  # overwrite alias
  z:address:number <- copy y
]
# no warnings
