# Primitives are functions that are implemented directly in Mu.
# They always evaluate all their arguments.

fn initialize-primitives _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  # for numbers
  append-primitive self, "+"
  append-primitive self, "-"
  append-primitive self, "*"
  append-primitive self, "/"
  append-primitive self, "%"
  append-primitive self, "sqrt"
  append-primitive self, "abs"
  append-primitive self, "sgn"
  append-primitive self, "<"
  append-primitive self, ">"
  append-primitive self, "<="
  append-primitive self, ">="
  # generic
  append-primitive self, "apply"
  append-primitive self, "="
  append-primitive self, "no"
  append-primitive self, "not"
  append-primitive self, "dbg"
  # for pairs
  append-primitive self, "car"
  append-primitive self, "cdr"
  append-primitive self, "cons"
  append-primitive self, "cons?"
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
  append-primitive self, "line"
  append-primitive self, "hline"
  append-primitive self, "vline"
  append-primitive self, "circle"
  append-primitive self, "bezier"
  append-primitive self, "width"
  append-primitive self, "height"
  # for keyboards
  append-primitive self, "key"
  # for streams
  append-primitive self, "stream"
  append-primitive self, "write"
  append-primitive self, "read"
  append-primitive self, "rewind"
  # misc
  append-primitive self, "abort"
  # keep sync'd with render-primitives
}

# Slightly misnamed; renders primitives as well as special forms that don't
# evaluate all their arguments.
fn render-primitives screen: (addr screen), xmin: int, xmax: int, ymax: int {
  var y/ecx: int <- copy ymax
  y <- subtract 0x10/primitives-border
  clear-rect screen, xmin, y, xmax, ymax, 0xdc/bg=green-bg
  y <- increment
  var right-min/edx: int <- copy xmax
  right-min <- subtract 0x1e/primitives-divider
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "primitives", right-min, y, xmax, ymax, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "fn apply set if while", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "booleans", right-min, y, xmax, ymax, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "= and or not", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "lists", right-min, y, xmax, ymax, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "cons car cdr no cons?", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "numbers", right-min, y, xmax, ymax, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "+ - * / %", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "< > <= >=", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  set-cursor-position screen, right-min, y
  draw-text-wrapping-right-then-down-from-cursor screen, "sqrt abs sgn", right-min, y, xmax, ymax, 0x2a/fg=orange, 0xdc/bg=green-bg
#?   {
#?     compare screen, 0
#?     break-if-!=
#?     var foo/eax: byte <- read-key 0/keyboard
#?     compare foo, 0
#?     loop-if-=
#?   }
  y <- copy ymax
  y <- subtract 0xf/primitives-border
  var left-max/edx: int <- copy xmax
  left-max <- subtract 0x20/primitives-divider
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "cursor graphics", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  print", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen a -> a", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  lines columns", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen -> number", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  up down left right", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  cr", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen   ", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, "# move cursor down and to left margin", tmpx, left-max, y, 0x38/fg=trace, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "pixel graphics", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  circle bezier line hline vline pixel", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  width height", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen -> number", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  clear", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": screen", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  key", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": keyboard -> grapheme?", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "streams", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  stream", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": () -> stream ", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  write", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": stream grapheme -> stream", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  rewind clear", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": stream", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
  y <- increment
  var tmpx/eax: int <- copy xmin
  tmpx <- draw-text-rightward screen, "  read", tmpx, left-max, y, 0x2a/fg=orange, 0xdc/bg=green-bg
  tmpx <- draw-text-rightward screen, ": stream -> grapheme", tmpx, left-max, y, 7/fg=grey, 0xdc/bg=green-bg
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
  {
    var value-type/eax: (addr int) <- get value, type
    compare *value-type, 4/primitive
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
  # '%' is the remainder operator, because modulo isn't really meaningful for
  # non-integers
  #
  # I considered calling this operator 'rem', but I want to follow Arc in
  # using 'rem' for filtering out elements from lists.
  #   https://arclanguage.github.io/ref/list.html#rem
  {
    var remainder?/eax: boolean <- string-equal? f-name, "%"
    compare remainder?, 0/false
    break-if-=
    apply-remainder args-ah, out, trace
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
    var cons-check?/eax: boolean <- string-equal? f-name, "cons?"
    compare cons-check?, 0/false
    break-if-=
    apply-cons-check args-ah, out, trace
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
    var line?/eax: boolean <- string-equal? f-name, "line"
    compare line?, 0/false
    break-if-=
    apply-line args-ah, out, trace
    return
  }
  {
    var hline?/eax: boolean <- string-equal? f-name, "hline"
    compare hline?, 0/false
    break-if-=
    apply-hline args-ah, out, trace
    return
  }
  {
    var vline?/eax: boolean <- string-equal? f-name, "vline"
    compare vline?, 0/false
    break-if-=
    apply-vline args-ah, out, trace
    return
  }
  {
    var circle?/eax: boolean <- string-equal? f-name, "circle"
    compare circle?, 0/false
    break-if-=
    apply-circle args-ah, out, trace
    return
  }
  {
    var bezier?/eax: boolean <- string-equal? f-name, "bezier"
    compare bezier?, 0/false
    break-if-=
    apply-bezier args-ah, out, trace
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
    var rewind?/eax: boolean <- string-equal? f-name, "rewind"
    compare rewind?, 0/false
    break-if-=
    apply-rewind args-ah, out, trace
    return
  }
  {
    var read?/eax: boolean <- string-equal? f-name, "read"
    compare read?, 0/false
    break-if-=
    apply-read args-ah, out, trace
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to + are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for + is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "+ encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "+ needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
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

fn test-evaluate-missing-arg-in-add {
  var t-storage: trace
  var t/edi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x100/capacity, 0/visible  # we don't use trace UI
  #
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var one-storage: (handle cell)
  var one-ah/edx: (addr handle cell) <- address one-storage
  new-integer one-ah, 1
  var add-storage: (handle cell)
  var add-ah/ebx: (addr handle cell) <- address add-storage
  new-symbol add-ah, "+"
  # input is (+ 1)
  var tmp-storage: (handle cell)
  var tmp-ah/esi: (addr handle cell) <- address tmp-storage
  new-pair tmp-ah, *one-ah, *nil-ah
  new-pair tmp-ah, *add-ah, *tmp-ah
#?   dump-cell tmp-ah
  #
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  #
  evaluate tmp-ah, tmp-ah, *nil-ah, globals, t, 0/no-screen, 0/no-keyboard, 0/definitions-created, 0/call-number
  # no crash
}

fn apply-subtract _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply -"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to - are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for - is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "- encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "- needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to * are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for * is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "* encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "* needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to / are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for / is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "/ encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "/ needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
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

fn apply-remainder _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply %"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to % are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "% needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for % is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
  var right/eax: (addr cell) <- lookup *right-ah
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "% encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "% needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for % is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # divide
  var quotient/xmm0: float <- copy *first-value
  quotient <- divide *second-value
  var quotient-int/eax: int <- truncate quotient
  quotient <- convert quotient-int
  var sub-result/xmm1: float <- copy quotient
  sub-result <- multiply *second-value
  var result/xmm0: float <- copy *first-value
  result <- subtract sub-result
  new-float out, result
}

fn apply-square-root _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply sqrt"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to sqrt are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "arg for sqrt is not a number"
    return
  }
  var first-value/eax: (addr float) <- get first, number-data
  # square-root
  var result/xmm0: float <- square-root *first-value
  new-float out, result
}

fn apply-abs _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply abs"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to abs are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to sgn are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to car are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "car needs 1 arg but got 0"
    return
  }
  # args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 0/pair
    break-if-=
    error trace, "arg for car is not a pair"
    return
  }
  # nil? return nil
  {
    var nil?/eax: boolean <- nil? first
    compare nil?, 0/false
    break-if-=
    copy-object first-ah, out
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to cdr are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "cdr needs 1 arg but got 0"
    return
  }
  # args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 0/pair
    break-if-=
    error trace, "arg for cdr is not a pair"
    return
  }
  # nil? return nil
  {
    var nil?/eax: boolean <- nil? first
    compare nil?, 0/false
    break-if-=
    copy-object first-ah, out
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'cons' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'cons' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'cons' needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  # cons
  new-pair out, *first-ah, *second-ah
}

fn apply-cons-check _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply cons?"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to cons? are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "cons? needs 1 arg but got 0"
    return
  }
  # args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 0/pair
    break-if-=
    nil out
    return
  }
  new-integer out, 1
}


fn apply-structurally-equal _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply '='"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to '=' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'=' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'=' needs 2 args but got 1"
    return
  }
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
  trace-text trace, "eval", "apply 'not'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'not' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'not' needs 1 arg but got 0"
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
  trace-text trace, "eval", "apply 'debug'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'debug' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'debug' needs 1 arg but got 0"
    return
  }
  # dump args->left uglily to screen and wait for a keypress
  var first-ah/eax: (addr handle cell) <- get args, left
  dump-cell-from-cursor-over-full-screen first-ah, 7/fg 0/bg
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to '<' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'<' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'<' needs 2 args but got 1"
    return
  }
  var second-ah/edx: (addr handle cell) <- get right, left
  # compare
  var _first/eax: (addr cell) <- lookup *first-ah
  var first/ecx: (addr cell) <- copy _first
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for '<' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for '<' is not a number"
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to '>' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'>' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'>' needs 2 args but got 1"
    return
  }
  var second-ah/edx: (addr handle cell) <- get right, left
  # compare
  var _first/eax: (addr cell) <- lookup *first-ah
  var first/ecx: (addr cell) <- copy _first
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for '>' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for '>' is not a number"
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to '<=' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'<=' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'<=' needs 2 args but got 1"
    return
  }
  var second-ah/edx: (addr handle cell) <- get right, left
  # compare
  var _first/eax: (addr cell) <- lookup *first-ah
  var first/ecx: (addr cell) <- copy _first
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for '<=' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for '<=' is not a number"
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to '>=' are not a list"
    return
  }
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'>=' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'>=' needs 2 args but got 1"
    return
  }
  var second-ah/edx: (addr handle cell) <- get right, left
  # compare
  var _first/eax: (addr cell) <- lookup *first-ah
  var first/ecx: (addr cell) <- copy _first
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 1/number
    break-if-=
    error trace, "first arg for '>=' is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  var first-float/xmm0: float <- copy *first-value
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for '>=' is not a number"
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
  trace-text trace, "eval", "apply 'print'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'print' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'print' needs 2 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'print' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'print' needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var stream-storage: (stream byte 0x100)
  var stream/edi: (addr stream byte) <- address stream-storage
  print-cell second-ah, stream, trace
  draw-stream-wrapping-right-then-down-from-cursor-over-full-screen screen, stream, 7/fg, 0/bg
  # return what was printed
  copy-object second-ah, out
}

fn apply-clear _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'clear'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'clear' are not a list"
    return
  }
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
  compare *first-type, 3/stream
  {
    break-if-=
    var stream-data-ah/eax: (addr handle stream byte) <- get first, text-data
    var _stream-data/eax: (addr stream byte) <- lookup *stream-data-ah
    var stream-data/ebx: (addr stream byte) <- copy _stream-data
    clear-stream stream-data
    return
  }
  compare *first-type, 5/screen
  {
    break-if-!=
    var screen-ah/eax: (addr handle screen) <- get first, screen-data
    var _screen/eax: (addr screen) <- lookup *screen-ah
    var screen/ecx: (addr screen) <- copy _screen
    clear-screen screen
    return
  }
  error trace, "first arg for 'clear' is not a screen or a stream"
}

fn apply-up _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'up'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'up' are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'down' are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'left' are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'right' are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'cr' are not a list"
    return
  }
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
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  trace-text trace, "eval", "apply 'pixel'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'pixel' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'pixel' needs 4 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'pixel' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'pixel' needs 4 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
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
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'pixel' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'pixel' needs 4 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
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
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'pixel' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'pixel' needs 4 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'pixel' is not an int (color; 0..0xff)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var color/eax: int <- convert *fourth-value
  pixel screen, x, y, color
  # return nothing
}

fn apply-line _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'line'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'line' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'line' needs 6 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
    break-if-=
    error trace, "first arg for 'line' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # x1 = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'line' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'line' needs 6 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'line' is not a number (screen x coordinate of start point)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var x1/edx: int <- convert *second-value
  # y1 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'line' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'line' needs 6 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
    break-if-=
    error trace, "third arg for 'line' is not a number (screen y coordinate of start point)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var y1/ebx: int <- convert *third-value
  # x2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'line' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'line' needs 6 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'line' is not a number (screen x coordinate of end point)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var x2/ecx: int <- convert *fourth-value
  # y2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'line' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'line' needs 6 args but got 4"
    return
  }
  var fifth-ah/eax: (addr handle cell) <- get rest, left
  var fifth/eax: (addr cell) <- lookup *fifth-ah
  {
    var fifth-type/eax: (addr int) <- get fifth, type
    compare *fifth-type, 1/number
    break-if-=
    error trace, "fifth arg for 'line' is not a number (screen y coordinate of end point)"
    return
  }
  var fifth-value/eax: (addr float) <- get fifth, number-data
  var tmp/eax: int <- convert *fifth-value
  var y2: int
  copy-to y2, tmp
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'line' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'line' needs 6 args but got 5"
    return
  }
  var sixth-ah/eax: (addr handle cell) <- get rest, left
  var sixth/eax: (addr cell) <- lookup *sixth-ah
  {
    var sixth-type/eax: (addr int) <- get sixth, type
    compare *sixth-type, 1/number
    break-if-=
    error trace, "sixth arg for 'line' is not an int (color; 0..0xff)"
    return
  }
  var sixth-value/eax: (addr float) <- get sixth, number-data
  var color/eax: int <- convert *sixth-value
  draw-line screen, x1, y1, x2, y2, color
  # return nothing
}

fn apply-hline _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'hline'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'hline' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'hline' needs 5 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
    break-if-=
    error trace, "first arg for 'hline' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # y = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'hline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'hline' needs 5 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'hline' is not a number (screen y coordinate)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var y/edx: int <- convert *second-value
  # x1 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'hline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'hline' needs 5 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
    break-if-=
    error trace, "third arg for 'hline' is not a number (screen x coordinate of start point)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var x1/ebx: int <- convert *third-value
  # x2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'hline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'hline' needs 5 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'hline' is not a number (screen x coordinate of end point)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var x2/ecx: int <- convert *fourth-value
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'hline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'hline' needs 5 args but got 5"
    return
  }
  var fifth-ah/eax: (addr handle cell) <- get rest, left
  var fifth/eax: (addr cell) <- lookup *fifth-ah
  {
    var fifth-type/eax: (addr int) <- get fifth, type
    compare *fifth-type, 1/number
    break-if-=
    error trace, "fifth arg for 'hline' is not an int (color; 0..0xff)"
    return
  }
  var fifth-value/eax: (addr float) <- get fifth, number-data
  var color/eax: int <- convert *fifth-value
  draw-horizontal-line screen, y, x1, x2, color
  # return nothing
}

fn apply-vline _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'vline'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'vline' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'vline' needs 5 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
    break-if-=
    error trace, "first arg for 'vline' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # x = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'vline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'vline' needs 5 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'vline' is not a number (screen x coordinate)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var x/edx: int <- convert *second-value
  # y1 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'vline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'vline' needs 5 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
    break-if-=
    error trace, "third arg for 'vline' is not a number (screen y coordinate of start point)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var y1/ebx: int <- convert *third-value
  # y2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'vline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'vline' needs 5 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'vline' is not a number (screen y coordinate of end point)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var y2/ecx: int <- convert *fourth-value
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'vline' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'vline' needs 5 args but got 5"
    return
  }
  var fifth-ah/eax: (addr handle cell) <- get rest, left
  var fifth/eax: (addr cell) <- lookup *fifth-ah
  {
    var fifth-type/eax: (addr int) <- get fifth, type
    compare *fifth-type, 1/number
    break-if-=
    error trace, "fifth arg for 'vline' is not an int (color; 0..0xff)"
    return
  }
  var fifth-value/eax: (addr float) <- get fifth, number-data
  var color/eax: int <- convert *fifth-value
  draw-vertical-line screen, x, y1, y2, color
  # return nothing
}

fn apply-circle _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'circle'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'circle' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'circle' needs 5 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
    break-if-=
    error trace, "first arg for 'circle' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # cx = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'circle' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'circle' needs 5 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'circle' is not a number (screen x coordinate of center)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var cx/edx: int <- convert *second-value
  # cy = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'circle' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'circle' needs 5 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
    break-if-=
    error trace, "third arg for 'circle' is not a number (screen y coordinate of center)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var cy/ebx: int <- convert *third-value
  # r = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'circle' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'circle' needs 5 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'circle' is not a number (screen radius)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var r/ecx: int <- convert *fourth-value
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'circle' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'circle' needs 5 args but got 5"
    return
  }
  var fifth-ah/eax: (addr handle cell) <- get rest, left
  var fifth/eax: (addr cell) <- lookup *fifth-ah
  {
    var fifth-type/eax: (addr int) <- get fifth, type
    compare *fifth-type, 1/number
    break-if-=
    error trace, "fifth arg for 'circle' is not an int (color; 0..0xff)"
    return
  }
  var fifth-value/eax: (addr float) <- get fifth, number-data
  var color/eax: int <- convert *fifth-value
  draw-circle screen, cx, cy, r, color
  # return nothing
}

fn apply-bezier _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'bezier'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'bezier' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'bezier' needs 8 args but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
    break-if-=
    error trace, "first arg for 'bezier' is not a screen"
    return
  }
  var screen-ah/eax: (addr handle screen) <- get first, screen-data
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # x0 = args->right->left->value
  var rest-ah/eax: (addr handle cell) <- get args, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'bezier' is not a number (screen x coordinate of start point)"
    return
  }
  var second-value/eax: (addr float) <- get second, number-data
  var x0/edx: int <- convert *second-value
  # y0 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 2"
    return
  }
  var third-ah/eax: (addr handle cell) <- get rest, left
  var third/eax: (addr cell) <- lookup *third-ah
  {
    var third-type/eax: (addr int) <- get third, type
    compare *third-type, 1/number
    break-if-=
    error trace, "third arg for 'bezier' is not a number (screen y coordinate of start point)"
    return
  }
  var third-value/eax: (addr float) <- get third, number-data
  var y0/ebx: int <- convert *third-value
  # x1 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 3"
    return
  }
  var fourth-ah/eax: (addr handle cell) <- get rest, left
  var fourth/eax: (addr cell) <- lookup *fourth-ah
  {
    var fourth-type/eax: (addr int) <- get fourth, type
    compare *fourth-type, 1/number
    break-if-=
    error trace, "fourth arg for 'bezier' is not a number (screen x coordinate of control point)"
    return
  }
  var fourth-value/eax: (addr float) <- get fourth, number-data
  var tmp/eax: int <- convert *fourth-value
  var x1: int
  copy-to x1, tmp
  # y1 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 4"
    return
  }
  var fifth-ah/eax: (addr handle cell) <- get rest, left
  var fifth/eax: (addr cell) <- lookup *fifth-ah
  {
    var fifth-type/eax: (addr int) <- get fifth, type
    compare *fifth-type, 1/number
    break-if-=
    error trace, "fifth arg for 'bezier' is not a number (screen y coordinate of control point)"
    return
  }
  var fifth-value/eax: (addr float) <- get fifth, number-data
  var tmp/eax: int <- convert *fifth-value
  var y1: int
  copy-to y1, tmp
  # x2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  var rest/esi: (addr cell) <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 3"
    return
  }
  var sixth-ah/eax: (addr handle cell) <- get rest, left
  var sixth/eax: (addr cell) <- lookup *sixth-ah
  {
    var sixth-type/eax: (addr int) <- get sixth, type
    compare *sixth-type, 1/number
    break-if-=
    error trace, "sixth arg for 'bezier' is not a number (screen x coordinate of end point)"
    return
  }
  var sixth-value/eax: (addr float) <- get sixth, number-data
  var tmp/eax: int <- convert *sixth-value
  var x2: int
  copy-to x2, tmp
  # y2 = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 4"
    return
  }
  var seventh-ah/eax: (addr handle cell) <- get rest, left
  var seventh/eax: (addr cell) <- lookup *seventh-ah
  {
    var seventh-type/eax: (addr int) <- get seventh, type
    compare *seventh-type, 1/number
    break-if-=
    error trace, "seventh arg for 'bezier' is not a number (screen y coordinate of end point)"
    return
  }
  var seventh-value/eax: (addr float) <- get seventh, number-data
  var tmp/eax: int <- convert *seventh-value
  var y2: int
  copy-to y2, tmp
  # color = rest->right->left->value
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var _rest/eax: (addr cell) <- lookup *rest-ah
  rest <- copy _rest
  {
    var rest-type/eax: (addr int) <- get rest, type
    compare *rest-type, 0/pair
    break-if-=
    error trace, "'bezier' encountered non-pair"
    return
  }
  {
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    error trace, "'bezier' needs 8 args but got 5"
    return
  }
  var eighth-ah/eax: (addr handle cell) <- get rest, left
  var eighth/eax: (addr cell) <- lookup *eighth-ah
  {
    var eighth-type/eax: (addr int) <- get eighth, type
    compare *eighth-type, 1/number
    break-if-=
    error trace, "eighth arg for 'bezier' is not an int (color; 0..0xff)"
    return
  }
  var eighth-value/eax: (addr float) <- get eighth, number-data
  var color/eax: int <- convert *eighth-value
  draw-monotonic-bezier screen, x0, y0, x1, y1, x2, y2, color
  # return nothing
}

fn apply-wait-for-key _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'key'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'key' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'key' needs 1 arg but got 0"
    return
  }
  # keyboard = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 6/keyboard
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
  trace-text trace, "eval", "apply 'write'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'write' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'write' needs 2 args but got 0"
    return
  }
  # stream = args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 3/stream
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
  {
    var right-type/eax: (addr int) <- get right, type
    compare *right-type, 0/pair
    break-if-=
    error trace, "'write' encountered non-pair"
    return
  }
  {
    var nil?/eax: boolean <- nil? right
    compare nil?, 0/false
    break-if-=
    error trace, "'write' needs 2 args but got 1"
    return
  }
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  {
    var second-type/eax: (addr int) <- get second, type
    compare *second-type, 1/number
    break-if-=
    error trace, "second arg for 'write' is not a number/grapheme"
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

fn apply-rewind _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'rewind'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'rewind' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'rewind' needs 1 arg but got 0"
    return
  }
  # stream = args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 3/stream
    break-if-=
    error trace, "first arg for 'rewind' is not a stream"
    return
  }
  var stream-data-ah/eax: (addr handle stream byte) <- get first, text-data
  var _stream-data/eax: (addr stream byte) <- lookup *stream-data-ah
  var stream-data/ebx: (addr stream byte) <- copy _stream-data
  rewind-stream stream-data
  copy-object first-ah, out
}

fn apply-read _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'read'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'read' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'read' needs 1 arg but got 0"
    return
  }
  # stream = args->left
  var first-ah/edx: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 3/stream
    break-if-=
    error trace, "first arg for 'read' is not a stream"
    return
  }
  var stream-data-ah/eax: (addr handle stream byte) <- get first, text-data
  var _stream-data/eax: (addr stream byte) <- lookup *stream-data-ah
  var stream-data/ebx: (addr stream byte) <- copy _stream-data
#?   rewind-stream stream-data
  var result-grapheme/eax: grapheme <- read-grapheme stream-data
  var result/eax: int <- copy result-grapheme
  new-integer out, result
}

fn apply-lines _args-ah: (addr handle cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply 'lines'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'lines' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'lines' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  trace-text trace, "eval", "apply 'columns'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'columns' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'columns' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  trace-text trace, "eval", "apply 'width'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'width' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'width' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
  trace-text trace, "eval", "apply 'height'"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  {
    var args-type/eax: (addr int) <- get args, type
    compare *args-type, 0/pair
    break-if-=
    error trace, "args to 'height' are not a list"
    return
  }
  var empty-args?/eax: boolean <- nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "'height' needs 1 arg but got 0"
    return
  }
  # screen = args->left
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var first-type/eax: (addr int) <- get first, type
    compare *first-type, 5/screen
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
