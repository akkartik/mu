fn evaluate _in: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "evaluate"
  trace-lower trace
  var in/eax: (addr handle cell) <- copy _in
  var in-addr/eax: (addr cell) <- lookup *in
  {
    var is-nil?/eax: boolean <- is-nil? in-addr
    compare is-nil?, 0/false
    break-if-=
    # nil is a literal
    copy-object _in, out
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in-addr, type
  compare *in-type, 1/number
  {
    break-if-!=
    # numbers are literals
    copy-object _in, out
    trace-higher trace
    return
  }
  copy-object _in, out
  trace-higher trace
}
