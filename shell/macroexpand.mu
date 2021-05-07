fn macroexpand expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  # loop until convergence
  var expanded?/eax: boolean <- macroexpand-iter expr-ah, globals, trace
  compare expanded?, 0/false
  loop-if-!=
}

# return true if we found any macros
fn macroexpand-iter _expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) -> _/eax: boolean {
  return 0/false
}
