fn initialize-primitives _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  # for numbers
  append-primitive self, "+"
  append-primitive self, "-"
  append-primitive self, "*"
  append-primitive self, "/"
  append-primitive self, "sqrt"
  append-primitive self, "abs"
  append-primitive self, "sgn"
  append-primitive self, "<"
  append-primitive self, ">"
  append-primitive self, "<="
  append-primitive self, ">="
  # generic
  append-primitive self, "="
  append-primitive self, "no"
  append-primitive self, "not"
  append-primitive self, "dbg"
  # for pairs
  append-primitive self, "car"
  append-primitive self, "cdr"
  append-primitive self, "cons"
  # for screens
  append-primitive self, "print"
  append-primitive self, "clear"
  append-primitive self, "lines"
  append-primitive self, "columns"
  append-primitive self, "up"
  append-primitive self, "down"
  append-primitive self, "left"
  append-primitive self, "right"
  append-primitive self, "cr"
  append-primitive self, "pixel"
  append-primitive self, "width"
  append-primitive self, "height"
  # for keyboards
  append-primitive self, "key"
  # for streams
  append-primitive self, "stream"
  append-primitive self, "write"
  # misc
  append-primitive self, "abort"
  # keep sync'd with render-primitives
}

fn render-primitives screen: (addr screen), xmin: int, xmax: int, ymax: int {
  var y/ecx: int <- copy ymax
  y <- subtract 0x10
  clear-rect screen, xmin, y, xmax, ymax, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "cursor graphics", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  print", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen a -> a", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  lines columns", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen -> number", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  up down left right", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  cr", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen   ", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, "# move cursor down and to left margin", tmpx, xmax, y, 0x38/fg=trace, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "pixel graphics", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  width height", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen -> number", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  pixel", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen x y color", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "screen/keyboard", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  clear", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  key", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": () -> grapheme?", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "streams", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  stream", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": () -> stream ", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  write", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": stream grapheme -> stream", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "fn def set if while = no(t) car cdr cons  ", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, "num: ", tmpx, xmax, y, 7/fg=grey, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, "+ - * / sqrt abs sgn < > <= >=   ", tmpx, xmax, y, 0x2a/fg=orange, 0xdc/bg=green-bg
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
  compare self, 0
  {
    break-if-!=
    abort "append primitive"
    return
  }
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

# a little strange; goes from value to name and selects primitive based on name
fn apply-primitive _f: (addr cell), args-ah: (addr handle cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace) {
  var f/esi: (addr cell) <- copy _f
  var f-index-a/ecx: (addr int) <- get f, index-data
  var f-index/ecx: int <- copy *f-index-a
  var globals/eax: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    abort "apply primitive"
    return
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var f-offset/ecx: (offset global) <- compute-offset global-data, f-index
  var f-value/ecx: (addr global) <- index global-data, f-offset
  var f-name-ah/ecx: (addr handle array byte) <- get f-value, name
  var f-name/eax: (addr array byte) <- lookup *f-name-ah
  {
    var add?/eax: boolean <- string-equal? f-name, "+"
    compare add?, 0/false
    break-if-=
    apply-add args-ah, out, trace
    return
  }
  {
    var subtract?/eax: boolean <- string-equal? f-name, "-"
    compare subtract?, 0/false
    break-if-=
    apply-subtract args-ah, out, trace
    return
  }
  {
    var multiply?/eax: boolean <- string-equal? f-name, "*"
    compare multiply?, 0/false
    break-if-=
    apply-multiply args-ah, out, trace
    return
  }
  {
    var divide?/eax: boolean <- string-equal? f-name, "/"
    compare divide?, 0/false
    break-if-=
    apply-divide args-ah, out, trace
    return
  }
  {
    var square-root?/eax: boolean <- string-equal? f-name, "sqrt"
    compare square-root?, 0/false
    break-if-=
    apply-square-root args-ah, out, trace
    return
  }
  {
    var abs?/eax: boolean <- string-equal? f-name, "abs"
    compare abs?, 0/false
    break-if-=
    apply-abs args-ah, out, trace
    return
  }
  {
    var sgn?/eax: boolean <- string-equal? f-name, "sgn"
    compare sgn?, 0/false
    break-if-=
    apply-sgn args-ah, out, trace
    return
  }
  {
    var car?/eax: boolean <- string-equal? f-name, "car"
    compare car?, 0/false
    break-if-=
    apply-car args-ah, out, trace
    return
  }
  {
    var cdr?/eax: boolean <- string-equal? f-name, "cdr"
    compare cdr?, 0/false
    break-if-=
    apply-cdr args-ah, out, trace
    return
  }
  {
    var cons?/eax: boolean <- string-equal? f-name, "cons"
    compare cons?, 0/false
    break-if-=
    apply-cons args-ah, out, trace
    return
  }
  {
    var structurally-equal?/eax: boolean <- string-equal? f-name, "="
    compare structurally-equal?, 0/false
    break-if-=
    apply-structurally-equal args-ah, out, trace
    return
  }
  {
    var not?/eax: boolean <- string-equal? f-name, "no"
    compare not?, 0/false
    break-if-=
    apply-not args-ah, out, trace
    return
  }
  {
    var not?/eax: boolean <- string-equal? f-name, "not"
    compare not?, 0/false
    break-if-=
    apply-not args-ah, out, trace
    return
  }
  {
    var debug?/eax: boolean <- string-equal? f-name, "dbg"
    compare debug?, 0/false
    break-if-=
    apply-debug args-ah, out, trace
    return
  }
  {
    var lesser?/eax: boolean <- string-equal? f-name, "<"
    compare lesser?, 0/false
    break-if-=
    apply-< args-ah, out, trace
    return
  }
  {
    var greater?/eax: boolean <- string-equal? f-name, ">"
    compare greater?, 0/false
    break-if-=
    apply-> args-ah, out, trace
    return
  }
  {
    var lesser-or-equal?/eax: boolean <- string-equal? f-name, "<="
    compare lesser-or-equal?, 0/false
    break-if-=
    apply-<= args-ah, out, trace
    return
  }
  {
    var greater-or-equal?/eax: boolean <- string-equal? f-name, ">="
    compare greater-or-equal?, 0/false
    break-if-=
    apply->= args-ah, out, trace
    return
  }
  {
    var print?/eax: boolean <- string-equal? f-name, "print"
    compare print?, 0/false
    break-if-=
    apply-print args-ah, out, trace
    return
  }
  {
    var clear?/eax: boolean <- string-equal? f-name, "clear"
    compare clear?, 0/false
    break-if-=
    apply-clear args-ah, out, trace
    return
  }
  {
    var lines?/eax: boolean <- string-equal? f-name, "lines"
    compare lines?, 0/false
    break-if-=
    apply-lines args-ah, out, trace
    return
  }
  {
    var columns?/eax: boolean <- string-equal? f-name, "columns"
    compare columns?, 0/false
    break-if-=
    apply-columns args-ah, out, trace
    return
  }
  {
    var up?/eax: boolean <- string-equal? f-name, "up"
    compare up?, 0/false
    break-if-=
    apply-up args-ah, out, trace
    return
  }
  {
    var down?/eax: boolean <- string-equal? f-name, "down"
    compare down?, 0/false
    break-if-=
    apply-down args-ah, out, trace
    return
  }
  {
    var left?/eax: boolean <- string-equal? f-name, "left"
    compare left?, 0/false
    break-if-=
    apply-left args-ah, out, trace
    return
  }
  {
    var right?/eax: boolean <- string-equal? f-name, "right"
    compare right?, 0/false
    break-if-=
    apply-right args-ah, out, trace
    return
  }
  {
    var cr?/eax: boolean <- string-equal? f-name, "cr"
    compare cr?, 0/false
    break-if-=
    apply-cr args-ah, out, trace
    return
  }
  {
    var pixel?/eax: boolean <- string-equal? f-name, "pixel"
    compare pixel?, 0/false
    break-if-=
    apply-pixel args-ah, out, trace
    return
  }
  {
    var width?/eax: boolean <- string-equal? f-name, "width"
    compare width?, 0/false
    break-if-=
    apply-width args-ah, out, trace
    return
  }
  {
    var height?/eax: boolean <- string-equal? f-name, "height"
    compare height?, 0/false
    break-if-=
    apply-height args-ah, out, trace
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
    var stream?/eax: boolean <- string-equal? f-name, "stream"
    compare stream?, 0/false
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
  {
    var abort?/eax: boolean <- string-equal? f-name, "abort"
    compare abort?, 0/false
    break-if-=
    apply-abort args-ah, out, trace
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
    error trace, "sqrt needs 1 arg but got 0"
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

fn apply-abs _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply abs"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "abs needs 1 arg but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "arg for abs is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  #
  var result/xmm0: float <- copy *first-value
  var zero: float
  compare result, zero
  {
    break-if-float>=
    var neg1/eax: int <- copy -1
    var neg1-f/xmm1: float <- convert neg1
    result <- multiply neg1-f
  }
  new-float out, result
}

fn apply-sgn _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply sgn"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "sgn needs 1 arg but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "arg for sgn is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  #
  var result/xmm0: float <- copy *first-value
  var zero: float
  $apply-sgn:core: {
    compare result, zero
    break-if-=
    {
      break-if-float>
      var neg1/eax: int <- copy -1
      result <- convert neg1
      break $apply-sgn:core
    }
    {
      break-if-float<
      var one/eax: int <- copy 1
      result <- convert one
      break $apply-sgn:core
    }
  }
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
    error trace, "car needs 1 arg but got 0"
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
    error trace, "cdr needs 1 arg but got 0"
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

fn apply-structurally-equal _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '='"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'=' needs 2 args but got 0"
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

fn apply-not _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply not"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "not needs 1 arg but got 0"
    return
  }
  # args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  # not
  var nil?/eax: boolean <- nil? first
  compare nil?, 0/false
  {
    break-if-!=
    nil out
    return
  }
  new-integer out, 1
}

fn apply-debug _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply debug"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "not needs 1 arg but got 0"
    return
  }
  # dump args->left uglily to screen and wait for a keypress
  var first-ah/eax: (addr handle cell) <- get args, left
  dump-cell-from-cursor-over-full-screen first-ah
  {
    var foo/eax: byte <- read-key 0/keyboard
    compare foo, 0
    loop-if-=
  }
  # return nothing
}

fn apply-< _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '<'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'<' needs 2 args but got 0"
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
  var first-type/eax: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for '<' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "first arg for '<' is not a number"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  compare first-float, *second-value
  {
    break-if-float<
    nil out
    return
  }
  new-integer out, 1/true
}

fn apply-> _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '>'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'>' needs 2 args but got 0"
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
  var first-type/eax: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for '>' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "first arg for '>' is not a number"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  compare first-float, *second-value
  {
    break-if-float>
    nil out
    return
  }
  new-integer out, 1/true
}

fn apply-<= _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '<='"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'<=' needs 2 args but got 0"
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
  var first-type/eax: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for '<=' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "first arg for '<=' is not a number"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  compare first-float, *second-value
  {
    break-if-float<=
    nil out
    return
  }
  new-integer out, 1/true
}

fn apply->= _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '>='"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'>=' needs 2 args but got 0"
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
  var first-type/eax: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for '>=' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "first arg for '>=' is not a number"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  compare first-float, *second-value
  {
    break-if-float>=
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

fn apply-clear _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply clear"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'clear' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'clear' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  clear-screen screen
}

fn apply-up _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply up"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'up' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'up' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  move-cursor-up screen
}

fn apply-down _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'down'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'down' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'down' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  move-cursor-down screen
}

fn apply-left _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'left'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'left' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'left' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  move-cursor-left screen
}

fn apply-right _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'right'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'right' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'right' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  move-cursor-right screen
}

fn apply-cr _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'cr'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'cr' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'cr' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/ecx: (addr screen) <- copy _screen
  #
  move-cursor-to-left-margin-of-next-line screen
}

fn apply-pixel _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply pixel"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "pixel needs 4 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'pixel' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # x = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  # TODO: check that rest is a pair
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/ecx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for 'pixel' is not an int (x coordinate)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var x/edx: int <- convert *second-value
  # y = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  # TODO: check that rest is a pair
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  var third-type/ecx: (addr int) <- get third, type
  compare *third-type, 1/number
  {
    break-if-=
    error trace, "third arg for 'pixel' is not an int (y coordinate)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var y/ebx: int <- convert *third-value
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  # TODO: check that rest is a pair
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  var fourth-type/ecx: (addr int) <- get fourth, type
  compare *fourth-type, 1/number
  {
    break-if-=
    error trace, "fourth arg for 'pixel' is not an int (color; 0..0xff)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var color/eax: int <- convert *fourth-value
  pixel screen, x, y, color
  # return nothing
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

fn apply-lines _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply lines"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "lines needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'lines' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edx: (addr screen) <- copy _screen
  # compute dimensions
  var dummy/eax: int <- copy 0
  var height/ecx: int <- copy 0
  dummy, height <- screen-size screen
  var result/xmm0: float <- convert height
  new-float out, result
}

fn apply-abort _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  abort "aa"
}

fn apply-columns _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply columns"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "columns needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'columns' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edx: (addr screen) <- copy _screen
  # compute dimensions
  var width/eax: int <- copy 0
  var dummy/ecx: int <- copy 0
  width, dummy <- screen-size screen
  var result/xmm0: float <- convert width
  new-float out, result
}

fn apply-width _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply width"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "width needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'width' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edx: (addr screen) <- copy _screen
  # compute dimensions
  var width/eax: int <- copy 0
  var dummy/ecx: int <- copy 0
  width, dummy <- screen-size screen
  width <- shift-left 3/log2-font-width
  var result/xmm0: float <- convert width
  new-float out, result
}

fn apply-height _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply height"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "height needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 5/screen
  {
    break-if-=
    error trace, "first arg for 'height' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edx: (addr screen) <- copy _screen
  # compute dimensions
  var dummy/eax: int <- copy 0
  var height/ecx: int <- copy 0
  dummy, height <- screen-size screen
  height <- shift-left 4/log2-font-height
  var result/xmm0: float <- convert height
  new-float out, result
}