# out is not allocated
fn read-cell in: (addr gap-buffer), out: (addr handle cell), trace: (addr trace) {
  var tokens-storage: (stream cell 0x100)
  var tokens/ecx: (addr stream cell) <- address tokens-storage
  tokenize in, tokens, trace
  # TODO: insert parens
  # TODO: transform infix
  parse-sexpression tokens, out, trace
}
