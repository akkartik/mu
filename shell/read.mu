fn read-cell in: (addr gap-buffer), out: (addr handle cell), trace: (addr trace) {
  # TODO: we may be able to generate tokens lazily and drop this stream.
  # Depends on how we implement indent-sensitivity and infix.
  var tokens-storage: (stream cell 0x400)
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
