fn parse-sexpression tokens: (addr stream cell), _out: (addr handle cell), trace: (addr trace) {
  # For now we just convert first token into a symbol and return it. TODO
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-!=
    var out/eax: (addr handle cell) <- copy _out
    allocate out
    var out-addr/eax: (addr cell) <- lookup *out
    read-from-stream tokens, out-addr
    var type/ecx: (addr int) <- get out-addr, type
    copy-to *type, 2/symbol
  }
}
