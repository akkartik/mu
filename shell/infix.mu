fn transform-infix _x-ah: (addr handle cell), trace: (addr trace) {
  trace-text trace, "infix", "transform infix"
  trace-lower trace
  trace-text trace, "infix", "todo"
  trace-higher trace
}
