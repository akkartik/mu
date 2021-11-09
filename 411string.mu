# read up to 'len' code-point-utf8s after skipping the first 'start' ones
fn substring in: (addr array byte), start: int, len: int, out-ah: (addr handle array byte) {
  var in-stream: (stream byte 0x100)
  var in-stream-addr/esi: (addr stream byte) <- address in-stream
  write in-stream-addr, in
  var out-stream: (stream byte 0x100)
  var out-stream-addr/edi: (addr stream byte) <- address out-stream
  $substring:core: {
    # skip 'start' code-point-utf8s
    var i/eax: int <- copy 0
    {
      compare i, start
      break-if->=
      {
        var dummy/eax: code-point-utf8 <- read-code-point-utf8 in-stream-addr
        compare dummy, 0xffffffff/end-of-file
        break-if-= $substring:core
      }
      i <- increment
      loop
    }
    # copy 'len' code-point-utf8s
    i <- copy 0
    {
      compare i, len
      break-if->=
      {
        var g/eax: code-point-utf8 <- read-code-point-utf8 in-stream-addr
        compare g, 0xffffffff/end-of-file
        break-if-= $substring:core
        write-code-point-utf8 out-stream-addr, g
      }
      i <- increment
      loop
    }
  }
  stream-to-array out-stream-addr, out-ah
}

fn test-substring {
  var out-h: (handle array byte)
  var out-ah/edi: (addr handle array byte) <- address out-h
  # prefix substrings
  substring 0, 0, 3, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "", "F - test-substring/null"
  substring "", 0, 3, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
#?   print-string-to-real-screen out
#?   print-string-to-real-screen "\n"
  check-strings-equal out, "", "F - test-substring/empty"
  #
  substring "abcde", 0, 3, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
#?   print-string-to-real-screen out
#?   print-string-to-real-screen "\n"
  check-strings-equal out, "abc", "F - test-substring/truncate"
  #
  substring "abcde", 0, 5, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "abcde", "F - test-substring/all"
  #
  substring "abcde", 0, 7, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "abcde", "F - test-substring/too-small"
  # substrings outside string
  substring "abcde", 6, 1, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "", "F - test-substring/start-too-large"
  # trim prefix
  substring "", 2, 3, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "", "F - test-substring/middle-empty"
  #
  substring "abcde", 1, 2, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "bc", "F - test-substring/middle-truncate"
  #
  substring "abcde", 1, 4, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "bcde", "F - test-substring/middle-all"
  #
  substring "abcde", 1, 5, out-ah
  var out/eax: (addr array byte) <- lookup *out-ah
  check-strings-equal out, "bcde", "F - test-substring/middle-too-small"
}

fn split-string in: (addr array byte), delim: code-point-utf8, out: (addr handle array (handle array byte)) {
  var in-stream: (stream byte 0x100)
  var in-stream-addr/esi: (addr stream byte) <- address in-stream
  write in-stream-addr, in
  var tokens-stream: (stream (handle array byte) 0x100)
  var tokens-stream-addr/edi: (addr stream (handle array byte)) <- address tokens-stream
  var curr-stream: (stream byte 0x100)
  var curr-stream-addr/ecx: (addr stream byte) <- address curr-stream
  $split-string:core: {
    var g/eax: code-point-utf8 <- read-code-point-utf8 in-stream-addr
    compare g, 0xffffffff
    break-if-=
#?     print-code-point-utf8-to-real-screen g
#?     print-string-to-real-screen "\n"
    compare g, delim
    {
      break-if-!=
      # token complete; flush
      var token: (handle array byte)
      var token-ah/eax: (addr handle array byte) <- address token
      stream-to-array curr-stream-addr, token-ah
      write-to-stream tokens-stream-addr, token-ah
      clear-stream curr-stream-addr
      loop $split-string:core
    }
    write-code-point-utf8 curr-stream-addr, g
    loop
  }
  stream-to-array tokens-stream-addr, out
}

fn test-split-string {
  var out-h: (handle array (handle array byte))
  var out-ah/edi: (addr handle array (handle array byte)) <- address out-h
  # prefix substrings
  split-string "bab", 0x61, out-ah
  # no crash
}
