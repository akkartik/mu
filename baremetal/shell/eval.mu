type interpreter {
  # tokenize
  # insert parens
  # transform infix
  # token tree
  # syntax tree
}

fn evaluate _self: (addr interpreter), in: (addr stream byte), out: (addr stream byte) {
  clear-stream out
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme in
    write-grapheme out, g
    loop
  }
}
