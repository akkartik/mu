fn macroexpand _in-ah: (addr handle cell), _out-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  copy-object _in-ah, _out-ah
}
