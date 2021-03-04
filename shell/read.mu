# out is not allocated
fn read-cell in: (addr gap-buffer), out: (addr handle cell), trace: (addr trace) {
  var tokens-storage: (stream cell 0x100)
  var tokens/ecx: (addr stream cell) <- address tokens-storage
  tokenize in, tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    return
  }
  # TODO: insert parens
  # TODO: transform infix
  parse-input tokens, out, trace
}
