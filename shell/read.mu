fn read-cell in: (addr gap-buffer), out: (addr handle cell), trace: (addr trace) {
  # eagerly tokenize everything so that the phases are easier to see in the trace
  var tokens-storage: (stream token 0x400)
  var tokens/edx: (addr stream token) <- address tokens-storage
  tokenize in, tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    return
  }
  # insert more parens based on indentation
  var parenthesized-tokens-storage: (stream token 0x400)
  var parenthesized-tokens/ecx: (addr stream token) <- address parenthesized-tokens-storage
  parenthesize tokens, parenthesized-tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    return
  }
  parse-input parenthesized-tokens, out, trace
  transform-infix out, trace
}
