fn macroexpand expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  # loop until convergence
  var expanded?/eax: boolean <- macroexpand-iter expr-ah, globals, trace
  compare expanded?, 0/false
  loop-if-!=
}

# return true if we found any macros
fn macroexpand-iter _expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) -> _/eax: boolean {
  # if car(expr) is a symbol defined as a macro, expand it
  var expr-ah/esi: (addr handle cell) <- copy _expr-ah
  var expr/eax: (addr cell) <- lookup *expr-ah
  {
    var expr-type/eax: (addr int) <- get expr, type
    compare *expr-type, 0/pair
    break-if-=
    # not a pair
    return 0/false
  }
  var first-ah/ebx: (addr handle cell) <- get expr, left
  var rest-ah/ecx: (addr handle cell) <- get expr, right
  var first/eax: (addr cell) <- lookup *first-ah
  var definition-h: (handle cell)
  var definition-ah/ebx: (addr handle cell) <- address definition-h
  maybe-lookup-symbol-in-globals first, definition-ah, globals, trace
  var definition/eax: (addr cell) <- lookup *definition-ah
  compare definition, 0
  {
    break-if-!=
    # no definition
    return 0/false
  }
  {
    var definition-type/eax: (addr int) <- get definition, type
    compare *definition-type, 0/pair
    break-if-=
    # definition not a pair
    return 0/false
  }
  {
    var definition-car-ah/eax: (addr handle cell) <- get definition, left
    var definition-car/eax: (addr cell) <- lookup *definition-car-ah
    var macro?/eax: boolean <- litmac? definition-car
    compare macro?, 0/false
    break-if-!=
    # definition not a macro
    return 0/false
  }
  var macro-definition-ah/eax: (addr handle cell) <- get definition, right
  # TODO: check car(macro-definition) is litfn
  apply macro-definition-ah, rest-ah, expr-ah, globals, trace, 0/no-screen, 0/no-keyboard, 0/call-number
  return 1/true
}
