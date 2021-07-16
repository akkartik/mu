# Integer arithmetic using postfix notation
#
# Limitations:
#   No division yet.
#
# To build:
#   $ ./translate apps/rpn.mu
#
# Example session:
#   $ ./a.elf
#   press ctrl-c or ctrl-d to exit
#   > 1
#   1
#   > 1 1 +
#   2
#   > 1 2 3 + +
#   6
#   > 1 2 3 * +
#   7
#   > 1 2 + 3 *
#   9
#   > 1 3 4 * +
#   13
#   > ^D
#   $
#
# Error handling is non-existent. This is just a prototype.

fn main -> _/ebx: int {
  var in-storage: (stream byte 0x100)
  var in/esi: (addr stream byte) <- address in-storage
  print-string 0/screen, "press ctrl-c or ctrl-d to exit\n"
  # read-eval-print loop
  {
    # print prompt
    print-string 0/screen, "> "
    # read line
    clear-stream in
    read-line-from-real-keyboard in
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0
    break-if-!=
    # parse and eval
    var out/eax: int <- simplify in
    # print
    print-int32-decimal 0/screen, out
    print-string 0/screen, "\n"
    #
    loop
  }
  return 0
}

type int-stack {
  data: (handle array int)
  top: int
}

fn simplify in: (addr stream byte) -> _/eax: int {
  var word-storage: slice
  var word/ecx: (addr slice) <- address word-storage
  var stack-storage: int-stack
  var stack/esi: (addr int-stack) <- address stack-storage
  initialize-int-stack stack, 0x10
  $simplify:word-loop: {
    next-word in, word
    var done?/eax: boolean <- slice-empty? word
    compare done?, 0
    break-if-!=
    # if word is an operator, perform it
    {
      var add?/eax: boolean <- slice-equal? word, "+"
      compare add?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack stack
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack stack
      a <- add b
      push-int-stack stack, a
      loop $simplify:word-loop
    }
    {
      var sub?/eax: boolean <- slice-equal? word, "-"
      compare sub?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack stack
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack stack
      a <- subtract b
      push-int-stack stack, a
      loop $simplify:word-loop
    }
    {
      var mul?/eax: boolean <- slice-equal? word, "*"
      compare mul?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack stack
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack stack
      a <- multiply b
      push-int-stack stack, a
      loop $simplify:word-loop
    }
    # otherwise it's an int
    var n/eax: int <- parse-decimal-int-from-slice word
    push-int-stack stack, n
    loop
  }
  var result/eax: int <- pop-int-stack stack
  return result
}

fn initialize-int-stack _self: (addr int-stack), n: int {
  var self/esi: (addr int-stack) <- copy _self
  var d/edi: (addr handle array int) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn push-int-stack _self: (addr int-stack), _val: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-addr/edx: (addr int) <- index data, top
  var val/eax: int <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-int-stack _self: (addr int-stack) -> _/eax: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    return 0
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr int) <- index data, top
  var val/eax: int <- copy *result-addr
  return val
}
