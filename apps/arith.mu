fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  # var input/esi: (addr array byte) = args[1] {{{
  var input/esi: (addr array byte) <- copy 0
  {
    var args-in-reg/eax: (addr array (addr array byte)) <- copy args
    var input-in-eax/eax: (addr addr array byte) <- index args-in-reg, 1
    input <- copy *input-in-eax
  }
  # }}}
  var result/eax: int <- parse-int input
  exit-status <- copy result  # only LSB makes it out
}

fn parse-int _in: (addr array byte) -> result/eax: int {
  var in/esi: (addr array byte) <- copy _in
  var len/edx: int <- length in
  var i/ecx: int <- copy 0
  var out/edi: int <- copy 0
  {
    compare i, len
    break-if->=
    # out *= 10
    {
      var ten/eax: int <- copy 0xa
      out <- multiply ten
    }
    # c = in[i]
    var c/eax: byte <- copy 0
    {
      var tmp/ebx: (addr byte) <- index in, i
      c <- copy-byte *tmp
    }
    #
    var digit/eax: int <- to-decimal-digit c
    out <- add digit
    i <- increment
    loop
  }
  result <- copy out
}
