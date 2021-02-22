# out is not allocated
fn read-cell in: (addr gap-buffer), out: (addr handle cell) {
  # TODO:
  #   tokenize
  #   insert parens
  #   transform infix
  #   token tree
  #   syntax tree
  rewind-gap-buffer in
  var token-storage: (stream byte 0x1000)  # strings can be large
  var token/ecx: (addr stream byte) <- address token-storage
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    next-token in, token
    read-symbol token, out
    loop
  }
}

fn next-token in: (addr gap-buffer), out: (addr stream byte) {
  clear-stream out
  skip-whitespace-from-gap-buffer in
  var g/eax: grapheme <- peek-from-gap-buffer in
  {
    var digit?/eax: boolean <- is-decimal-digit? g
    compare digit?, 0/false
    break-if-=
    next-number-token in, out
    return
  }
  next-symbol-token in, out
}

fn next-symbol-token in: (addr gap-buffer), out: (addr stream byte) {
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    # if non-symbol, return
    var symbol-grapheme?/eax: boolean <- is-symbol-grapheme? g
    {
      compare symbol-grapheme?, 0/false
      break-if-!=
      return
    }
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out, g
    loop
  }
}

fn is-symbol-grapheme? g: grapheme -> _/eax: boolean {
  compare g, 0x20/space
  {
    break-if-!=
    return 0/false
  }
  compare g, 0xa/newline
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x22/double-quote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x28/open-paren
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x29/close-paren
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x5b/open-square-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x5d/close-square-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x7b/open-curly-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x7d/close-curly-bracket
  {
    break-if-!=
    return 0/false
  }
  return 1/true
}

fn next-number-token in: (addr gap-buffer), out: (addr stream byte) {
  var done?/eax: boolean <- gap-buffer-scan-done? in
  compare done?, 0/false
  break-if-!=
  var g/eax: grapheme <- peek-from-gap-buffer in
  # if not symbol grapheme, return
  {
    var symbol-grapheme?/eax: boolean <- is-symbol-grapheme? g
    compare symbol-grapheme?, 0/false
    break-if-!=
    return
  }
  # if not digit grapheme, abort
  {
    var digit?/eax: boolean <- is-decimal-digit? g
    compare digit?, 0/false
    break-if-!=
    abort "invalid number"
  }
  var g/eax: grapheme <- read-from-gap-buffer in
  write-grapheme out, g
  loop
}

fn read-symbol in: (addr stream byte), _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  new-symbol out
  var out-a/eax: (addr cell) <- lookup *out
  var out-data-ah/eax: (addr handle stream byte) <- get out-a, text-data
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme in
    write-grapheme out-data, g
    loop
  }
}
