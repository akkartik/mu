fn macroexpand _in-ah: (addr handle cell), _out-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  var in-ah/esi: (addr handle cell) <- copy _in-ah
  var out-ah/edi: (addr handle cell) <- copy _out-ah
  # loop until convergence
  {
    macroexpand-iter in-ah, out-ah, globals, trace
    var _in/eax: (addr cell) <- lookup *in-ah
    var in/ecx: (addr cell) <- copy _in
    var out/eax: (addr cell) <- lookup *out-ah
    var done?/eax: boolean <- cell-isomorphic? in, out, trace
    compare done?, 0/false
    break-if-!=
    copy-object out-ah, in-ah
    loop
  }
}

fn macroexpand-iter _in-ah: (addr handle cell), _out-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  copy-object _in-ah, _out-ah
}
