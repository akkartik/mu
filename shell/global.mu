type global {
  name: (handle array byte)
  value: (handle cell)
}

type global-table {
  data: (handle array global)
  final-index: int
}

fn initialize-globals _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  var data-ah/eax: (addr handle array global) <- get self, data
  populate data-ah, 0x10
  # generic
  append-primitive self, "="
  # for numbers
  append-primitive self, "+"
  append-primitive self, "-"
  append-primitive self, "*"
  append-primitive self, "/"
  append-primitive self, "sqrt"
  # for pairs
  append-primitive self, "car"
  append-primitive self, "cdr"
  append-primitive self, "cons"
  # for screens
  append-primitive self, "print"
  # for keyboards
  append-primitive self, "key"
  # for streams
  append-primitive self, "stream"
  append-primitive self, "write"
}

fn render-globals screen: (addr screen), _self: (addr global-table), xmin: int, ymin: int, xmax: int, ymax: int {
  clear-rect screen, xmin, ymin, xmax, ymax, 0x12/bg=almost-black
  var self/esi: (addr global-table) <- copy _self
  # render primitives
  var bottom-line/ecx: int <- copy ymax
  bottom-line <- decrement
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-index/edx: int <- copy 1
  var x/edi: int <- copy xmin
  {
    var curr-offset/ebx: (offset global) <- compute-offset data, curr-index
    var curr/ebx: (addr global) <- index data, curr-offset
    var continue?/eax: boolean <- primitive-global? curr
    compare continue?, 0/false
    break-if-=
    var curr-name-ah/eax: (addr handle array byte) <- get curr, name
    var _curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var curr-name/ebx: (addr array byte) <- copy _curr-name
    var tmpx/eax: int <- copy x
    tmpx <- draw-text-rightward screen, curr-name, tmpx, xmax, bottom-line, 0x2a/fg=orange, 0x12/bg=almost-black
    tmpx <- draw-text-rightward screen, " ", tmpx, xmax, bottom-line, 7/fg=grey, 0x12/bg=almost-black
    x <- copy tmpx
    curr-index <- increment
    loop
  }
  var lowest-index/edi: int <- copy curr-index
  var y/ecx: int <- copy ymin
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var final-index/edx: (addr int) <- get self, final-index
  var curr-index/edx: int <- copy *final-index
  {
    compare curr-index, lowest-index
    break-if-<
    compare y, ymax
    break-if->=
    {
      var curr-offset/ebx: (offset global) <- compute-offset data, curr-index
      var curr/ebx: (addr global) <- index data, curr-offset
      var curr-name-ah/eax: (addr handle array byte) <- get curr, name
      var _curr-name/eax: (addr array byte) <- lookup *curr-name-ah
      var curr-name/edx: (addr array byte) <- copy _curr-name
      var x/eax: int <- copy xmin
      x, y <- draw-text-wrapping-right-then-down screen, curr-name, xmin, ymin, xmax, ymax, x, y, 0x2a/fg=orange, 0x12/bg=almost-black
      x, y <- draw-text-wrapping-right-then-down screen, " <- ", xmin, ymin, xmax, ymax, x, y, 7/fg=grey, 0x12/bg=almost-black
      var curr-value/edx: (addr handle cell) <- get curr, value
      var s-storage: (stream byte 0x100)
      var s/ebx: (addr stream byte) <- address s-storage
      print-cell curr-value, s, 0/no-trace
      x, y <- draw-stream-wrapping-right-then-down screen, s, xmin, ymin, xmax, ymax, x, y, 0x3/fg=cyan, 0x12/bg=almost-black
    }
    curr-index <- decrement
    y <- increment
    loop
  }
}

fn primitive-global? _x: (addr global) -> _/eax: boolean {
  var x/eax: (addr global) <- copy _x
  var value-ah/eax: (addr handle cell) <- get x, value
  var value/eax: (addr cell) <- lookup *value-ah
  compare value, 0/null
  {
    break-if-!=
    return 0/false
  }
  var value-type/eax: (addr int) <- get value, type
  compare *value-type, 4/primitive
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn append-primitive _self: (addr global-table), name: (addr array byte) {
  var self/esi: (addr global-table) <- copy _self
  var final-index-addr/ecx: (addr int) <- get self, final-index
  increment *final-index-addr
  var curr-index/ecx: int <- copy *final-index-addr
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-offset/esi: (offset global) <- compute-offset data, curr-index
  var curr/esi: (addr global) <- index data, curr-offset
  var curr-name-ah/eax: (addr handle array byte) <- get curr, name
  copy-array-object name, curr-name-ah
  var curr-value-ah/eax: (addr handle cell) <- get curr, value
  new-primitive-function curr-value-ah, curr-index
}

fn append-global _self: (addr global-table), name: (addr array byte), value: (handle cell) {
  var self/esi: (addr global-table) <- copy _self
  var final-index-addr/ecx: (addr int) <- get self, final-index
  increment *final-index-addr
  var curr-index/ecx: int <- copy *final-index-addr
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-offset/esi: (offset global) <- compute-offset data, curr-index
  var curr/esi: (addr global) <- index data, curr-offset
  var curr-name-ah/eax: (addr handle array byte) <- get curr, name
  copy-array-object name, curr-name-ah
  var curr-value-ah/eax: (addr handle cell) <- get curr, value
  copy-handle value, curr-value-ah
}

fn lookup-symbol-in-globals _sym: (addr cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell) {
  var sym/eax: (addr cell) <- copy _sym
  var sym-name-ah/eax: (addr handle stream byte) <- get sym, text-data
  var _sym-name/eax: (addr stream byte) <- lookup *sym-name-ah
  var sym-name/edx: (addr stream byte) <- copy _sym-name
  var globals/esi: (addr global-table) <- copy _globals
  {
    compare globals, 0
    break-if-=
    var curr-index/ecx: int <- find-symbol-in-globals globals, sym-name
    compare curr-index, -1/not-found
    break-if-=
    var global-data-ah/eax: (addr handle array global) <- get globals, data
    var global-data/eax: (addr array global) <- lookup *global-data-ah
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-value/eax: (addr handle cell) <- get curr, value
    copy-object curr-value, out
    return
  }
  # if sym is "screen" and screen-cell exists, return it
  {
    var sym-is-screen?/eax: boolean <- stream-data-equal? sym-name, "screen"
    compare sym-is-screen?, 0/false
    break-if-=
    compare screen-cell, 0
    break-if-=
    copy-object screen-cell, out
    return
  }
  # if sym is "keyboard" and keyboard-cell exists, return it
  {
    var sym-is-keyboard?/eax: boolean <- stream-data-equal? sym-name, "keyboard"
    compare sym-is-keyboard?, 0/false
    break-if-=
    compare keyboard-cell, 0
    break-if-=
    copy-object keyboard-cell, out
    return
  }
  # otherwise error "unbound symbol: ", sym
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "unbound symbol: "
  rewind-stream sym-name
  write-stream stream, sym-name
  trace trace, "error", stream
}

# return the index in globals containing 'sym'
# or -1 if not found
fn find-symbol-in-globals _globals: (addr global-table), sym-name: (addr stream byte) -> _/ecx: int {
  var globals/esi: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    return -1/not-found
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var final-index/ecx: (addr int) <- get globals, final-index
  var curr-index/ecx: int <- copy *final-index
  {
    compare curr-index, 0
    break-if-<
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-name-ah/eax: (addr handle array byte) <- get curr, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var found?/eax: boolean <- stream-data-equal? sym-name, curr-name
    compare found?, 0/false
    {
      break-if-=
      return curr-index
    }
    curr-index <- decrement
    loop
  }
  return -1/not-found
}

# a little strange; goes from value to name and selects primitive based on name
fn apply-primitive _f: (addr cell), args-ah: (addr handle cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace) {
  var f/esi: (addr cell) <- copy _f
  var f-index-a/ecx: (addr int) <- get f, index-data
  var f-index/ecx: int <- copy *f-index-a
  var globals/eax: (addr global-table) <- copy _globals
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var f-offset/ecx: (offset global) <- compute-offset global-data, f-index
  var f-value/ecx: (addr global) <- index global-data, f-offset
  var f-name-ah/ecx: (addr handle array byte) <- get f-value, name
  var f-name/eax: (addr array byte) <- lookup *f-name-ah
  {
    var is-add?/eax: boolean <- string-equal? f-name, "+"
    compare is-add?, 0/false
    break-if-=
    apply-add args-ah, out, trace
    return
  }
  {
    var is-subtract?/eax: boolean <- string-equal? f-name, "-"
    compare is-subtract?, 0/false
    break-if-=
    apply-subtract args-ah, out, trace
    return
  }
  {
    var is-multiply?/eax: boolean <- string-equal? f-name, "*"
    compare is-multiply?, 0/false
    break-if-=
    apply-multiply args-ah, out, trace
    return
  }
  {
    var is-divide?/eax: boolean <- string-equal? f-name, "/"
    compare is-divide?, 0/false
    break-if-=
    apply-divide args-ah, out, trace
    return
  }
  {
    var is-square-root?/eax: boolean <- string-equal? f-name, "sqrt"
    compare is-square-root?, 0/false
    break-if-=
    apply-square-root args-ah, out, trace
    return
  }
  {
    var is-car?/eax: boolean <- string-equal? f-name, "car"
    compare is-car?, 0/false
    break-if-=
    apply-car args-ah, out, trace
    return
  }
  {
    var is-cdr?/eax: boolean <- string-equal? f-name, "cdr"
    compare is-cdr?, 0/false
    break-if-=
    apply-cdr args-ah, out, trace
    return
  }
  {
    var is-cons?/eax: boolean <- string-equal? f-name, "cons"
    compare is-cons?, 0/false
    break-if-=
    apply-cons args-ah, out, trace
    return
  }
  {
    var is-compare?/eax: boolean <- string-equal? f-name, "="
    compare is-compare?, 0/false
    break-if-=
    apply-compare args-ah, out, trace
    return
  }
  {
    var is-print?/eax: boolean <- string-equal? f-name, "print"
    compare is-print?, 0/false
    break-if-=
    apply-print args-ah, out, trace
    return
  }
  {
    var wait-for-key?/eax: boolean <- string-equal? f-name, "key"
    compare wait-for-key?, 0/false
    break-if-=
    apply-wait-for-key args-ah, out, trace
    return
  }
  {
    var is-stream?/eax: boolean <- string-equal? f-name, "stream"
    compare is-stream?, 0/false
    break-if-=
    apply-stream args-ah, out, trace
    return
  }
  {
    var write?/eax: boolean <- string-equal? f-name, "write"
    compare write?, 0/false
    break-if-=
    apply-write args-ah, out, trace
    return
  }
  abort "unknown primitive function"
}

fn apply-add _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply +"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "+ needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for + is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
#?   dump-cell right-ah
#?   abort "aaa"
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for + is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # add
  var result/xmm0: float <- copy *first-value
  result <- add *second-value
  new-float out, result
}

fn apply-subtract _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply -"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "- needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for - is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for - is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # subtract
  var result/xmm0: float <- copy *first-value
  result <- subtract *second-value
  new-float out, result
}

fn apply-multiply _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply *"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "* needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for * is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for * is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # multiply
  var result/xmm0: float <- copy *first-value
  result <- multiply *second-value
  new-float out, result
}

fn apply-divide _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply /"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "/ needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for / is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for / is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # divide
  var result/xmm0: float <- copy *first-value
  result <- divide *second-value
  new-float out, result
}

fn apply-square-root _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply sqrt"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "sqrt needs 1 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "arg for sqrt is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # square-root
  var result/xmm0: float <- square-root *first-value
  new-float out, result
}

fn apply-car _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply car"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "car needs 1 args but got 0"
    return
  }
  # args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 0/pair
  {
    break-if-=
    error trace, "arg for car is not a pair"
    return
  }
  # car
  var result/eax: (addr handle cell) <- get first, left
  copy-object result, out
}

fn apply-cdr _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply cdr"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "cdr needs 1 args but got 0"
    return
  }
  # args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 0/pair
  {
    break-if-=
    error trace, "arg for cdr is not a pair"
    return
  }
  # cdr
  var result/eax: (addr handle cell) <- get first, right
  copy-object result, out
}

fn apply-cons _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply cons"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "cons needs 2 args but got 0"
    return
  }
  # args->left
  var first-ah/ecx: (addr handle cell) <- get args, left
  # args->right->left
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  # cons
  new-pair out, *first-ah, *second-ah
}

fn apply-compare _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply ="
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "cons needs 2 args but got 0"
    return
  }
  # args->left
  var first-ah/ecx: (addr handle cell) <- get args, left
  # args->right->left
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/edx: (addr handle cell) <- get right, left
  # compare
  var _first/eax: (addr cell) <- lookup *first-ah
  var first/ecx: (addr cell) <- copy _first
  var second/eax: (addr cell) <- lookup *second-ah
  var match?/eax: boolean <- cell-isomorphic? first, second, trace
  compare match?, 0/false
  {
    break-if-!=
    nil out
    return
  }
  new-integer out, 1/true
}

fn apply-print _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply print"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "print needs 2 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'print' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  # args->right->left
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var stream-storage: (stream byte 0x100)
  var stream/edi: (addr stream byte) <- address stream-storage
  print-cell second-ah, stream, trace
  draw-stream-wrapping-right-then-down-from-cursor-over-full-screen screen, stream, 7/fg, 0/bg
  # return what was printed
  copy-object second-ah, out
}

fn apply-wait-for-key _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply key"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "key needs 1 arg but got 0"
    return
  }
  # keyboard = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 6/keyboard
  {
    break-if-=
    error trace, "first arg for 'key' is not a keyboard"
    return
  }
  var keyboard-ah/eax: (addr handle gap-buffer) <- get first, keyboard-data
  var _keyboard/eax: (addr gap-buffer) <- lookup *keyboard-ah
  var keyboard/ecx: (addr gap-buffer) <- copy _keyboard
  var result/eax: int <- wait-for-key keyboard
  # return key typed
  new-integer out, result
}

fn wait-for-key keyboard: (addr gap-buffer) -> _/eax: int {
  # if keyboard is 0, use real keyboard
  {
    compare keyboard, 0/real-keyboard
    break-if-!=
    var key/eax: byte <- read-key 0/real-keyboard
    var result/eax: int <- copy key
    return result
  }
  # otherwise read from fake keyboard
  var g/eax: grapheme <- read-from-gap-buffer keyboard
  var result/eax: int <- copy g
  return result
}

fn apply-stream _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply stream"
  allocate-stream out
}

fn apply-write _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply write"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "write needs 2 args but got 0"
    return
  }
  # stream = args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 3/stream
  {
    break-if-=
    error trace, "first arg for 'write' is not a stream"
    return
  }
  var stream-data-ah/eax: (addr handle stream byte) <- get first, text-data
  var _stream-data/eax: (addr stream byte) <- lookup *stream-data-ah
  var stream-data/ebx: (addr stream byte) <- copy _stream-data
  # args->right->left
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/ecx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for stream is not a number/grapheme"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var x-float/xmm0: float <- copy *second-value
  var x/eax: int <- convert x-float
  var x-grapheme/eax: grapheme <- copy x
  write-grapheme stream-data, x-grapheme
  # return the stream
  copy-object first-ah, out
}
