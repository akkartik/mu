# TODO: not really implemented yet
fn parenthesize in: (addr stream token), out: (addr stream token), trace: (addr trace) {
  trace-text trace, "parenthesize", "insert parens"
  trace-lower trace
  rewind-stream in
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    #
    var token-storage: token
    var token/edx: (addr token) <- address token-storage
    read-from-stream in, token
    var is-indent?/eax: boolean <- indent-token? token
    compare is-indent?, 0/false
    loop-if-!=
    write-to-stream out, token  # shallow copy
    loop
  }
  trace-higher trace
}
