# env is an alist of ((sym . val) (sym . val) ...)
# we never modify `_in-ah` or `env`
# ignore args past 'trace' on a first reading; they're for the environment not the language
# 'call-number' is just for showing intermediate progress; this is a _slow_ interpreter
fn evaluate _in-ah: (addr handle cell), _out-ah: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell), call-number: int {
  # stack overflow?   # disable when enabling Really-debug-print
  check-stack
  {
    var screen-cell/eax: (addr handle cell) <- copy screen-cell
    compare screen-cell, 0
    break-if-=
    var screen-cell-addr/eax: (addr cell) <- lookup *screen-cell
    compare screen-cell-addr, 0
    break-if-=
    # if screen-cell exists, we're probably not in a test
    show-stack-state
  }
  # errors? skip
  {
    compare trace, 0
    break-if-=
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    break-if-=
    return
  }
  var in-ah/esi: (addr handle cell) <- copy _in-ah
  # show intermediate progress on screen if necessary
  {
    compare screen-cell, 0
    break-if-=
    var tmp/eax: int <- copy call-number
    tmp <- and 0xf  # every 16 calls to evaluate
    compare tmp, 0
    break-if-!=
    var screen-cell/eax: (addr handle cell) <- copy screen-cell
    var screen-cell-addr/eax: (addr cell) <- lookup *screen-cell
    compare screen-cell-addr, 0
    break-if-=
    var screen-obj-ah/eax: (addr handle screen) <- get screen-cell-addr, screen-data
    var screen-obj/eax: (addr screen) <- lookup *screen-obj-ah
    compare screen-obj, 0
    break-if-=
    var y/ecx: int <- render-screen 0/screen, screen-obj, 0x70/xmin, 1/ymin
  }
#?   dump-cell in-ah
#?   {
#?     var foo/eax: byte <- read-key 0/keyboard
#?     compare foo, 0
#?     loop-if-=
#?   }
  # trace "evaluate " in " in environment " env {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "evaluate "
    print-cell in-ah, stream, 0/no-trace
    write stream, " in environment "
    var env-ah/eax: (addr handle cell) <- address env-h
    print-cell env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
  trace-lower trace
  var in/eax: (addr cell) <- lookup *in-ah
  {
    var nil?/eax: boolean <- nil? in
    compare nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "eval", "nil"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in, type
  compare *in-type, 1/number
  {
    break-if-!=
    # numbers are literals
    trace-text trace, "eval", "number"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  compare *in-type, 3/stream
  {
    break-if-!=
    # streams are literals
    trace-text trace, "eval", "stream"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  compare *in-type, 2/symbol
  {
    break-if-!=
    trace-text trace, "eval", "symbol"
    debug-print "a", 7/fg, 0xc5/bg=blue-bg
    lookup-symbol in, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell
    debug-print "z", 7/fg, 0xc5/bg=blue-bg
    trace-higher trace
    return
  }
  compare *in-type, 5/screen
  {
    break-if-!=
    trace-text trace, "eval", "screen"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  compare *in-type, 6/keyboard
  {
    break-if-!=
    trace-text trace, "eval", "keyboard"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  # 'in' is a syntax tree
  $evaluate:literal-function: {
    # trees starting with "litfn" are literals
    var expr/esi: (addr cell) <- copy in
    var in/edx: (addr cell) <- copy in
    var first-ah/ecx: (addr handle cell) <- get in, left
    var first/eax: (addr cell) <- lookup *first-ah
    var litfn?/eax: boolean <- litfn? first
    compare litfn?, 0/false
    break-if-=
    trace-text trace, "eval", "literal function"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  $evaluate:literal-macro: {
    # trees starting with "litmac" are literals
    var expr/esi: (addr cell) <- copy in
    var in/edx: (addr cell) <- copy in
    var first-ah/ecx: (addr handle cell) <- get in, left
    var first/eax: (addr cell) <- lookup *first-ah
    var litmac?/eax: boolean <- litmac? first
    compare litmac?, 0/false
    break-if-=
    trace-text trace, "eval", "literal macro"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  $evaluate:anonymous-function: {
    # trees starting with "fn" are anonymous functions
    var expr/esi: (addr cell) <- copy in
    var in/edx: (addr cell) <- copy in
    var first-ah/ecx: (addr handle cell) <- get in, left
    var first/eax: (addr cell) <- lookup *first-ah
    var fn?/eax: boolean <- fn? first
    compare fn?, 0/false
    break-if-=
    # turn (fn ...) into (litfn env ...)
    trace-text trace, "eval", "anonymous function"
    var rest-ah/eax: (addr handle cell) <- get in, right
    var tmp: (handle cell)
    var tmp-ah/edi: (addr handle cell) <- address tmp
    new-pair tmp-ah, env-h, *rest-ah
    var litfn: (handle cell)
    var litfn-ah/eax: (addr handle cell) <- address litfn
    new-symbol litfn-ah, "litfn"
    new-pair _out-ah, *litfn-ah, *tmp-ah
    trace-higher trace
    return
  }
  # builtins with "special" evaluation rules
  $evaluate:quote: {
    # trees starting with single quote create literals
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "'", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var quote?/eax: boolean <- symbol-equal? first, "'"
    compare quote?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "quote"
    copy-object rest-ah, _out-ah
    trace-higher trace
    return
  }
  $evaluate:backquote: {
    # trees starting with single backquote create literals
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "'", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var backquote?/eax: boolean <- symbol-equal? first, "`"
    compare backquote?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "backquote"
    evaluate-backquote rest-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    trace-higher trace
    return
  }
  $evaluate:def: {
    # trees starting with "def" define globals
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "def", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var def?/eax: boolean <- symbol-equal? first, "def"
    compare def?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "def"
    trace-text trace, "eval", "evaluating second arg"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    {
      var first-arg/eax: (addr cell) <- lookup *first-arg-ah
      var first-arg-type/eax: (addr int) <- get first-arg, type
      compare *first-arg-type, 2/symbol
      break-if-=
      error trace, "first arg to def must be a symbol"
      trace-higher trace
      return
    }
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var second-arg-ah/edx: (addr handle cell) <- get rest, left
    debug-print "P", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate second-arg-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "Q", 4/fg, 0xc5/bg=blue-bg
    trace-text trace, "eval", "saving global binding"
    var first-arg/eax: (addr cell) <- lookup *first-arg-ah
    var first-arg-data-ah/eax: (addr handle stream byte) <- get first-arg, text-data
    var first-arg-data/eax: (addr stream byte) <- lookup *first-arg-data-ah
    var tmp-string: (handle array byte)
    var tmp-ah/edx: (addr handle array byte) <- address tmp-string
    rewind-stream first-arg-data
    stream-to-array first-arg-data, tmp-ah
    var first-arg-data-string/eax: (addr array byte) <- lookup *tmp-ah
    var out-ah/edi: (addr handle cell) <- copy _out-ah
    assign-or-create-global globals, first-arg-data-string, *out-ah, trace
    trace-higher trace
    return
  }
  $evaluate:set: {
    # trees starting with "set" mutate bindings
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "set", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var set?/eax: boolean <- symbol-equal? first, "set"
    compare set?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "set"
    trace-text trace, "eval", "evaluating second arg"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    {
      var first-arg/eax: (addr cell) <- lookup *first-arg-ah
      var first-arg-type/eax: (addr int) <- get first-arg, type
      compare *first-arg-type, 2/symbol
      break-if-=
      error trace, "first arg to set must be a symbol"
      trace-higher trace
      return
    }
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var second-arg-ah/edx: (addr handle cell) <- get rest, left
    debug-print "P", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate second-arg-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "Q", 4/fg, 0xc5/bg=blue-bg
    trace-text trace, "eval", "mutating binding"
    var first-arg/eax: (addr cell) <- lookup *first-arg-ah
    var first-arg-data-ah/eax: (addr handle stream byte) <- get first-arg, text-data
    var first-arg-data/eax: (addr stream byte) <- lookup *first-arg-data-ah
    mutate-binding first-arg-data, _out-ah, env-h, globals, trace
    trace-higher trace
    return
  }
  $evaluate:and: {
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "and", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var and?/eax: boolean <- symbol-equal? first, "and"
    compare and?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "and"
    trace-text trace, "eval", "evaluating first arg"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    debug-print "R2", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate first-arg-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "S2", 4/fg, 0xc5/bg=blue-bg
    # if first arg is nil, short-circuit
    var out-ah/eax: (addr handle cell) <- copy _out-ah
    var out/eax: (addr cell) <- lookup *out-ah
    var nil?/eax: boolean <- nil? out
    compare nil?, 0/false
    {
      break-if-=
      return
    }
    var rest/eax: (addr cell) <- lookup *rest-ah
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var second-ah/eax: (addr handle cell) <- get rest, left
    debug-print "T2", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate second-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "U2", 4/fg, 0xc5/bg=blue-bg
    trace-higher trace
    return
  }
  $evaluate:or: {
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "or", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var or?/eax: boolean <- symbol-equal? first, "or"
    compare or?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "or"
    trace-text trace, "eval", "evaluating first arg"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    debug-print "R2", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate first-arg-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "S2", 4/fg, 0xc5/bg=blue-bg
    # if first arg is not nil, short-circuit
    var out-ah/eax: (addr handle cell) <- copy _out-ah
    var out/eax: (addr cell) <- lookup *out-ah
    var nil?/eax: boolean <- nil? out
    compare nil?, 0/false
    {
      break-if-!=
      return
    }
    var rest/eax: (addr cell) <- lookup *rest-ah
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var second-ah/eax: (addr handle cell) <- get rest, left
    debug-print "T2", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate second-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "U2", 4/fg, 0xc5/bg=blue-bg
    trace-higher trace
    return
  }
  $evaluate:if: {
    # trees starting with "if" are conditionals
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "if", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var if?/eax: boolean <- symbol-equal? first, "if"
    compare if?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "if"
    trace-text trace, "eval", "evaluating first arg"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    var guard-h: (handle cell)
    var guard-ah/esi: (addr handle cell) <- address guard-h
    debug-print "R", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate first-arg-ah, guard-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "S", 4/fg, 0xc5/bg=blue-bg
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var branch-ah/edi: (addr handle cell) <- get rest, left
    var guard-a/eax: (addr cell) <- lookup *guard-ah
    var skip-to-third-arg?/eax: boolean <- nil? guard-a
    compare skip-to-third-arg?, 0/false
    {
      break-if-=
      trace-text trace, "eval", "skipping to third arg"
      var rest/eax: (addr cell) <- lookup *rest-ah
      rest-ah <- get rest, right
      rest <- lookup *rest-ah
      branch-ah <- get rest, left
    }
    debug-print "T", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate branch-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "U", 4/fg, 0xc5/bg=blue-bg
    trace-higher trace
    return
  }
  $evaluate:while: {
    # trees starting with "while" are loops
    var expr/esi: (addr cell) <- copy in
    # if its first elem is not "while", break
    var first-ah/ecx: (addr handle cell) <- get in, left
    var rest-ah/edx: (addr handle cell) <- get in, right
    var first/eax: (addr cell) <- lookup *first-ah
    var first-type/ecx: (addr int) <- get first, type
    compare *first-type, 2/symbol
    break-if-!=
    var sym-data-ah/eax: (addr handle stream byte) <- get first, text-data
    var sym-data/eax: (addr stream byte) <- lookup *sym-data-ah
    var while?/eax: boolean <- stream-data-equal? sym-data, "while"
    compare while?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "while"
    var rest/eax: (addr cell) <- lookup *rest-ah
    var first-arg-ah/ecx: (addr handle cell) <- get rest, left
    rest-ah <- get rest, right
    var guard-h: (handle cell)
    var guard-ah/esi: (addr handle cell) <- address guard-h
    $evaluate:while:loop-execution: {
      {
        compare trace, 0
        break-if-=
        var error?/eax: boolean <- has-errors? trace
        compare error?, 0/false
        break-if-!= $evaluate:while:loop-execution
      }
      trace-text trace, "eval", "loop termination check"
      debug-print "V", 4/fg, 0xc5/bg=blue-bg
      increment call-number
      evaluate first-arg-ah, guard-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
      debug-print "W", 4/fg, 0xc5/bg=blue-bg
      var guard-a/eax: (addr cell) <- lookup *guard-ah
      var done?/eax: boolean <- nil? guard-a
      compare done?, 0/false
      break-if-!=
      evaluate-exprs rest-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
      loop
    }
    trace-text trace, "eval", "loop terminated"
    trace-higher trace
    return
  }
  trace-text trace, "eval", "function call"
  trace-text trace, "eval", "evaluating list elements"
  trace-lower trace
  var evaluated-list-storage: (handle cell)
  var evaluated-list-ah/esi: (addr handle cell) <- address evaluated-list-storage
  var curr-out-ah/edx: (addr handle cell) <- copy evaluated-list-ah
  var curr/ecx: (addr cell) <- copy in
  $evaluate-list:loop: {
    allocate-pair curr-out-ah
    var nil?/eax: boolean <- nil? curr
    compare nil?, 0/false
    break-if-!=
    # eval left
    var curr-out/eax: (addr cell) <- lookup *curr-out-ah
    var left-out-ah/edi: (addr handle cell) <- get curr-out, left
    var left-ah/esi: (addr handle cell) <- get curr, left
    debug-print "A", 4/fg, 0xc5/bg=blue-bg
    increment call-number
    evaluate left-ah, left-out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "B", 4/fg, 0xc5/bg=blue-bg
    # a trip wire in case we're running without a trace (e.g. when loading the initial state from disk)
    {
      var left-out/eax: (addr cell) <- lookup *left-out-ah
      compare left-out, 0
      {
        break-if-!=
        abort "unknown variable"
      }
    }
    #
    curr-out-ah <- get curr-out, right
    var right-ah/eax: (addr handle cell) <- get curr, right
    var right/eax: (addr cell) <- lookup *right-ah
    curr <- copy right
    loop
  }
  trace-higher trace
  var evaluated-list/eax: (addr cell) <- lookup *evaluated-list-ah
  var function-ah/ecx: (addr handle cell) <- get evaluated-list, left
  var args-ah/edx: (addr handle cell) <- get evaluated-list, right
  debug-print "C", 4/fg, 0xc5/bg=blue-bg
  apply function-ah, args-ah, _out-ah, globals, trace, screen-cell, keyboard-cell, call-number
  debug-print "Y", 4/fg, 0xc5/bg=blue-bg
  trace-higher trace
  # trace "=> " _out-ah {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> "
    print-cell _out-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
  debug-print "Z", 4/fg, 0xc5/bg=blue-bg
}

fn apply _f-ah: (addr handle cell), args-ah: (addr handle cell), out: (addr handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell), call-number: int {
  var f-ah/eax: (addr handle cell) <- copy _f-ah
  var _f/eax: (addr cell) <- lookup *f-ah
  var f/esi: (addr cell) <- copy _f
  # call primitive functions
  {
    var f-type/eax: (addr int) <- get f, type
    compare *f-type, 4/primitive-function
    break-if-!=
    apply-primitive f, args-ah, out, globals, trace
    return
  }
  # if it's not a primitive function it must be an anonymous function
  # trace "apply anonymous function " f " in environment " env {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "apply anonymous function "
    print-cell _f-ah, stream, 0/no-trace
#?     write stream, " in environment "
#?     var callee-env-ah/eax: (addr handle cell) <- address callee-env-h
#?     print-cell callee-env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
  trace-lower trace
  {
    var f-type/ecx: (addr int) <- get f, type
    compare *f-type, 0/pair
    break-if-!=
    var first-ah/eax: (addr handle cell) <- get f, left
    var first/eax: (addr cell) <- lookup *first-ah
    var litfn?/eax: boolean <- litfn? first
    compare litfn?, 0/false
    break-if-=
    var rest-ah/esi: (addr handle cell) <- get f, right
    var rest/eax: (addr cell) <- lookup *rest-ah
    var callee-env-ah/edx: (addr handle cell) <- get rest, left
    rest-ah <- get rest, right
    rest <- lookup *rest-ah
    var params-ah/ecx: (addr handle cell) <- get rest, left
    var body-ah/eax: (addr handle cell) <- get rest, right
    debug-print "D", 7/fg, 0xc5/bg=blue-bg
    apply-function params-ah, args-ah, body-ah, out, *callee-env-ah, globals, trace, screen-cell, keyboard-cell, call-number
    debug-print "Y", 7/fg, 0xc5/bg=blue-bg
    trace-higher trace
    return
  }
  error trace, "unknown function"
}

fn apply-function params-ah: (addr handle cell), args-ah: (addr handle cell), body-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell), call-number: int {
  # push bindings for params to env
  var new-env-h: (handle cell)
  var new-env-ah/esi: (addr handle cell) <- address new-env-h
  push-bindings params-ah, args-ah, env-h, new-env-ah, trace
  #
  evaluate-exprs body-ah, out, new-env-h, globals, trace, screen-cell, keyboard-cell, call-number
}

fn evaluate-exprs _exprs-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell), call-number: int {
  # eval all exprs, writing result to `out` each time
  var exprs-ah/ecx: (addr handle cell) <- copy _exprs-ah
  $evaluate-exprs:loop: {
    var exprs/eax: (addr cell) <- lookup *exprs-ah
    # stop when exprs is nil
    {
      var exprs-nil?/eax: boolean <- nil? exprs
      compare exprs-nil?, 0/false
      break-if-!= $evaluate-exprs:loop
    }
    # evaluate each expression, writing result to `out`
    {
      var curr-ah/eax: (addr handle cell) <- get exprs, left
      debug-print "E", 7/fg, 0xc5/bg=blue-bg
      increment call-number
      evaluate curr-ah, out, env-h, globals, trace, screen-cell, keyboard-cell, call-number
      debug-print "X", 7/fg, 0xc5/bg=blue-bg
    }
    #
    exprs-ah <- get exprs, right
    loop
  }
  # `out` contains result of evaluating final expression
}

# Bind params to corresponding args and add the bindings to old-env. Return
# the result in env-ah.
#
# We never modify old-env, but we point to it. This way other parts of the
# interpreter can continue using old-env, and everything works harmoniously
# even though no cells are copied around.
#
# env should always be a DAG (ignoring internals of values). It doesn't have
# to be a tree (some values may be shared), but there are also no cycles.
#
# Learn more: https://en.wikipedia.org/wiki/Persistent_data_structure
fn push-bindings _params-ah: (addr handle cell), _args-ah: (addr handle cell), old-env-h: (handle cell), env-ah: (addr handle cell), trace: (addr trace) {
  var params-ah/edx: (addr handle cell) <- copy _params-ah
  var args-ah/ebx: (addr handle cell) <- copy _args-ah
  var _params/eax: (addr cell) <- lookup *params-ah
  var params/esi: (addr cell) <- copy _params
  {
    var params-nil?/eax: boolean <- nil? params
    compare params-nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "eval", "done with push-bindings"
    copy-handle old-env-h, env-ah
    return
  }
  # Params can only be symbols or pairs. Args can be anything.
  # trace "pushing bindings from " params " to " args {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "pushing bindings from "
    print-cell params-ah, stream, 0/no-trace
    write stream, " to "
    print-cell args-ah, stream, 0/no-trace
    write stream, " onto "
    var old-env-ah/eax: (addr handle cell) <- address old-env-h
    print-cell old-env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
  trace-lower trace
  var params-type/eax: (addr int) <- get params, type
  compare *params-type, 2/symbol
  {
    break-if-!=
    trace-text trace, "eval", "symbol; binding to all remaining args"
    # create a new binding
    var new-binding-storage: (handle cell)
    var new-binding-ah/eax: (addr handle cell) <- address new-binding-storage
    new-pair new-binding-ah, *params-ah, *args-ah
    # push it to env
    new-pair env-ah, *new-binding-ah, old-env-h
    trace-higher trace
    return
  }
  compare *params-type, 0/pair
  {
    break-if-=
    error trace, "cannot bind a non-symbol"
    trace-higher trace
    return
  }
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/edi: (addr cell) <- copy _args
  # params is now a pair, so args must be also
  var args-type/eax: (addr int) <- get args, type
  compare *args-type, 0/pair
  {
    break-if-=
    error trace, "args not in a proper list"
    trace-higher trace
    return
  }
  var intermediate-env-storage: (handle cell)
  var intermediate-env-ah/edx: (addr handle cell) <- address intermediate-env-storage
  var first-param-ah/eax: (addr handle cell) <- get params, left
  var first-arg-ah/ecx: (addr handle cell) <- get args, left
  push-bindings first-param-ah, first-arg-ah, old-env-h, intermediate-env-ah, trace
  var remaining-params-ah/eax: (addr handle cell) <- get params, right
  var remaining-args-ah/ecx: (addr handle cell) <- get args, right
  push-bindings remaining-params-ah, remaining-args-ah, *intermediate-env-ah, env-ah, trace
  trace-higher trace
}

fn lookup-symbol sym: (addr cell), out: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell) {
  # trace sym
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x800)  # pessimistically sized just for the large alist loaded from disk in `main`
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "look up "
    var sym2/eax: (addr cell) <- copy sym
    var sym-data-ah/eax: (addr handle stream byte) <- get sym2, text-data
    var sym-data/eax: (addr stream byte) <- lookup *sym-data-ah
    rewind-stream sym-data
    write-stream stream, sym-data
    write stream, " in "
    var env-ah/eax: (addr handle cell) <- address env-h
    print-cell env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  trace-lower trace
  var _env/eax: (addr cell) <- lookup env-h
  var env/ebx: (addr cell) <- copy _env
  # if env is not a list, abort
  {
    var env-type/ecx: (addr int) <- get env, type
    compare *env-type, 0/pair
    break-if-=
    error trace, "eval found a non-list environment"
    trace-higher trace
    return
  }
  # if env is nil, look up in globals
  {
    var env-nil?/eax: boolean <- nil? env
    compare env-nil?, 0/false
    break-if-=
    debug-print "b", 7/fg, 0xc5/bg=blue-bg
    lookup-symbol-in-globals sym, out, globals, trace, screen-cell, keyboard-cell
    debug-print "x", 7/fg, 0xc5/bg=blue-bg
    trace-higher trace
    # trace "=> " out " (global)" {{{
    {
      compare trace, 0
      break-if-=
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell out, stream, 0/no-trace
      write stream, " (global)"
      trace trace, "eval", stream
    }
    # }}}
    debug-print "y", 7/fg, 0xc5/bg=blue-bg
    return
  }
  # check car
  var env-head-storage: (handle cell)
  var env-head-ah/eax: (addr handle cell) <- address env-head-storage
  car env, env-head-ah, 0/no-trace
  var _env-head/eax: (addr cell) <- lookup *env-head-ah
  var env-head/ecx: (addr cell) <- copy _env-head
  # if car is not a list, abort
  {
    var env-head-type/eax: (addr int) <- get env-head, type
    compare *env-head-type, 0/pair
    break-if-=
    error trace, "environment is not a list of (key . value) pairs"
    trace-higher trace
    return
  }
  # check key
  var curr-key-storage: (handle cell)
  var curr-key-ah/eax: (addr handle cell) <- address curr-key-storage
  car env-head, curr-key-ah, trace
  var curr-key/eax: (addr cell) <- lookup *curr-key-ah
  # if key is not a symbol, abort
  {
    var curr-key-type/eax: (addr int) <- get curr-key, type
    compare *curr-key-type, 2/symbol
    break-if-=
    error trace, "environment contains a binding for a non-symbol"
    trace-higher trace
    return
  }
  # if key matches sym, return val
  var match?/eax: boolean <- cell-isomorphic? curr-key, sym, trace
  compare match?, 0/false
  {
    break-if-=
    cdr env-head, out, 0/no-trace
    # trace "=> " out " (match)" {{{
    {
      compare trace, 0
      break-if-=
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x800)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell out, stream, 0/no-trace
      write stream, " (match)"
      trace trace, "eval", stream
    }
    # }}}
    trace-higher trace
    return
  }
  # otherwise recurse
  var env-tail-storage: (handle cell)
  var env-tail-ah/eax: (addr handle cell) <- address env-tail-storage
  cdr env, env-tail-ah, trace
  lookup-symbol sym, out, *env-tail-ah, globals, trace, screen-cell, keyboard-cell
  trace-higher trace
    # trace "=> " out " (recurse)" {{{
    {
      compare trace, 0
      break-if-=
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell out, stream, 0/no-trace
      write stream, " (recurse)"
      trace trace, "eval", stream
    }
    # }}}
}

fn test-lookup-symbol-in-env {
  # tmp = (a . 3)
  var val-storage: (handle cell)
  var val-ah/ecx: (addr handle cell) <- address val-storage
  new-integer val-ah, 3
  var key-storage: (handle cell)
  var key-ah/edx: (addr handle cell) <- address key-storage
  new-symbol key-ah, "a"
  var env-storage: (handle cell)
  var env-ah/ebx: (addr handle cell) <- address env-storage
  new-pair env-ah, *key-ah, *val-ah
  # env = ((a . 3))
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  new-pair env-ah, *env-ah, *nil-ah
  # lookup sym(a) in env tmp
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "a"
  var in/eax: (addr cell) <- lookup *tmp-ah
  lookup-symbol in, tmp-ah, *env-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-lookup-symbol-in-env/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-lookup-symbol-in-env/1"
}

fn test-lookup-symbol-in-globals {
  var globals-storage: global-table
  var globals/edi: (addr global-table) <- address globals-storage
  initialize-globals globals
  # env = nil
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  # lookup sym(a), env
  var tmp-storage: (handle cell)
  var tmp-ah/ebx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "+"
  var in/eax: (addr cell) <- lookup *tmp-ah
  lookup-symbol in, tmp-ah, *nil-ah, globals, 0/no-trace, 0/no-screen, 0/no-keyboard
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 4/primitive-function, "F - test-lookup-symbol-in-globals/0"
  var result-value/eax: (addr int) <- get result, index-data
  check-ints-equal *result-value, 1/add, "F - test-lookup-symbol-in-globals/1"
}

fn mutate-binding name: (addr stream byte), val: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace) {
  # trace name
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x800)  # pessimistically sized just for the large alist loaded from disk in `main`
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "bind "
    rewind-stream name
    write-stream stream, name
    write stream, " to "
    print-cell val, stream, 0/no-trace
    write stream, " in "
    var env-ah/eax: (addr handle cell) <- address env-h
    print-cell env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  trace-lower trace
  var _env/eax: (addr cell) <- lookup env-h
  var env/ebx: (addr cell) <- copy _env
  # if env is not a list, abort
  {
    var env-type/ecx: (addr int) <- get env, type
    compare *env-type, 0/pair
    break-if-=
    error trace, "eval found a non-list environment"
    trace-higher trace
    return
  }
  # if env is nil, look in globals
  {
    var env-nil?/eax: boolean <- nil? env
    compare env-nil?, 0/false
    break-if-=
    debug-print "b", 3/fg, 0xc5/bg=blue-bg
    mutate-binding-in-globals name, val, globals, trace
    debug-print "x", 3/fg, 0xc5/bg=blue-bg
    trace-higher trace
    # trace "=> " val " (global)" {{{
    {
      compare trace, 0
      break-if-=
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell val, stream, 0/no-trace
      write stream, " (global)"
      trace trace, "eval", stream
    }
    # }}}
    debug-print "y", 3/fg, 0xc5/bg=blue-bg
    return
  }
  # check car
  var env-head-storage: (handle cell)
  var env-head-ah/eax: (addr handle cell) <- address env-head-storage
  car env, env-head-ah, 0/no-trace
  var _env-head/eax: (addr cell) <- lookup *env-head-ah
  var env-head/ecx: (addr cell) <- copy _env-head
  # if car is not a list, abort
  {
    var env-head-type/eax: (addr int) <- get env-head, type
    compare *env-head-type, 0/pair
    break-if-=
    error trace, "environment is not a list of (key . value) pairs"
    trace-higher trace
    return
  }
  # check key
  var curr-key-storage: (handle cell)
  var curr-key-ah/eax: (addr handle cell) <- address curr-key-storage
  car env-head, curr-key-ah, trace
  var curr-key/eax: (addr cell) <- lookup *curr-key-ah
  # if key is not a symbol, abort
  {
    var curr-key-type/eax: (addr int) <- get curr-key, type
    compare *curr-key-type, 2/symbol
    break-if-=
    error trace, "environment contains a binding for a non-symbol"
    trace-higher trace
    return
  }
  # if key matches name, return val
  var curr-key-data-ah/eax: (addr handle stream byte) <- get curr-key, text-data
  var curr-key-data/eax: (addr stream byte) <- lookup *curr-key-data-ah
  var match?/eax: boolean <- streams-data-equal? curr-key-data, name
  compare match?, 0/false
  {
    break-if-=
    var dest/eax: (addr handle cell) <- get env-head, right
    copy-object val, dest
    trace-text trace, "eval", "=> done"
    trace-higher trace
    return
  }
  # otherwise recurse
  var env-tail-storage: (handle cell)
  var env-tail-ah/eax: (addr handle cell) <- address env-tail-storage
  cdr env, env-tail-ah, trace
  mutate-binding name, val, *env-tail-ah, globals, trace
  trace-higher trace
}

fn car _in: (addr cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "car"
  trace-lower trace
  var in/eax: (addr cell) <- copy _in
  # if in is not a list, abort
  {
    var in-type/ecx: (addr int) <- get in, type
    compare *in-type, 0/pair
    break-if-=
    error trace, "car on a non-list"
    trace-higher trace
    return
  }
  # if in is nil, abort
  {
    var in-nil?/eax: boolean <- nil? in
    compare in-nil?, 0/false
    break-if-=
    error trace, "car on nil"
    trace-higher trace
    return
  }
  var in-left/eax: (addr handle cell) <- get in, left
  copy-object in-left, out
  trace-higher trace
  return
}

fn cdr _in: (addr cell), out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "eval", "cdr"
  trace-lower trace
  var in/eax: (addr cell) <- copy _in
  # if in is not a list, abort
  {
    var in-type/ecx: (addr int) <- get in, type
    compare *in-type, 0/pair
    break-if-=
    error trace, "car on a non-list"
    trace-higher trace
    return
  }
  # if in is nil, abort
  {
    var in-nil?/eax: boolean <- nil? in
    compare in-nil?, 0/false
    break-if-=
    error trace, "car on nil"
    trace-higher trace
    return
  }
  var in-right/eax: (addr handle cell) <- get in, right
  copy-object in-right, out
  trace-higher trace
  return
}

fn cell-isomorphic? _a: (addr cell), _b: (addr cell), trace: (addr trace) -> _/eax: boolean {
  trace-text trace, "eval", "cell-isomorphic?"
  trace-lower trace
  var a/esi: (addr cell) <- copy _a
  var b/edi: (addr cell) <- copy _b
  # if types don't match, return false
  var a-type-addr/eax: (addr int) <- get a, type
  var b-type-addr/ecx: (addr int) <- get b, type
  var b-type/ecx: int <- copy *b-type-addr
  compare b-type, *a-type-addr
  {
    break-if-=
    trace-higher trace
    trace-text trace, "eval", "=> false (type)"
    return 0/false
  }
  # if types are number, compare number-data
  # TODO: exactly comparing floats is a bad idea
  compare b-type, 1/number
  {
    break-if-!=
    var a-val-addr/eax: (addr float) <- get a, number-data
    var b-val-addr/ecx: (addr float) <- get b, number-data
    var a-val/xmm0: float <- copy *a-val-addr
    compare a-val, *b-val-addr
    {
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> false (numbers)"
      return 0/false
    }
    trace-higher trace
    trace-text trace, "eval", "=> true (numbers)"
    return 1/true
  }
  $cell-isomorphic?:text-data: {
    {
      compare b-type, 2/symbol
      break-if-=
      compare b-type, 3/stream
      break-if-=
      break $cell-isomorphic?:text-data
    }
    var b-val-ah/eax: (addr handle stream byte) <- get b, text-data
    var _b-val/eax: (addr stream byte) <- lookup *b-val-ah
    var b-val/ecx: (addr stream byte) <- copy _b-val
    var a-val-ah/eax: (addr handle stream byte) <- get a, text-data
    var a-val/eax: (addr stream byte) <- lookup *a-val-ah
    var tmp-array: (handle array byte)
    var tmp-ah/edx: (addr handle array byte) <- address tmp-array
    rewind-stream a-val
    stream-to-array a-val, tmp-ah
    var tmp/eax: (addr array byte) <- lookup *tmp-ah
    var match?/eax: boolean <- stream-data-equal? b-val, tmp
    trace-higher trace
    {
      compare match?, 0/false
      break-if-=
      trace-text trace, "eval", "=> true (symbols)"
    }
    {
      compare match?, 0/false
      break-if-!=
      trace-text trace, "eval", "=> false (symbols)"
    }
    return match?
  }
  # if objects are primitive functions, compare index-data
  compare b-type, 4/primitive
  {
    break-if-!=
    var a-val-addr/eax: (addr int) <- get a, index-data
    var b-val-addr/ecx: (addr int) <- get b, index-data
    var a-val/eax: int <- copy *a-val-addr
    compare a-val, *b-val-addr
    {
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> false (primitives)"
      return 0/false
    }
    trace-higher trace
    trace-text trace, "eval", "=> true (primitives)"
    return 1/true
  }
  # if objects are screens, check if they're the same object
  compare b-type, 5/screen
  {
    break-if-!=
    var a-val-addr/eax: (addr handle screen) <- get a, screen-data
    var b-val-addr/ecx: (addr handle screen) <- get b, screen-data
    var result/eax: boolean <- handle-equal? *a-val-addr, *b-val-addr
    compare result, 0/false
    return result
  }
  # if objects are keyboards, check if they have the same contents
  compare b-type, 6/keyboard
  {
    break-if-!=
    var a-val-addr/ecx: (addr handle gap-buffer) <- get a, keyboard-data
    var _a/eax: (addr gap-buffer) <- lookup *a-val-addr
    var a/ecx: (addr gap-buffer) <- copy _a
    var b-val-addr/eax: (addr handle gap-buffer) <- get b, keyboard-data
    var b/eax: (addr gap-buffer) <- lookup *b-val-addr
    var result/eax: boolean <- gap-buffers-equal? a, b
    return result
  }
  # if a is nil, b should be nil
  {
    # (assumes nil? returns 0 or 1)
    var _b-nil?/eax: boolean <- nil? b
    var b-nil?/ecx: boolean <- copy _b-nil?
    var a-nil?/eax: boolean <- nil? a
    # a == nil and b == nil => return true
    {
      compare a-nil?, 0/false
      break-if-=
      compare b-nil?, 0/false
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> true (nils)"
      return 1/true
    }
    # a == nil => return false
    {
      compare a-nil?, 0/false
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> false (b != nil)"
      return 0/false
    }
    # b == nil => return false
    {
      compare b-nil?, 0/false
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> false (a != nil)"
      return 0/false
    }
  }
  # a and b are pairs
  var a-tmp-storage: (handle cell)
  var a-tmp-ah/edx: (addr handle cell) <- address a-tmp-storage
  var b-tmp-storage: (handle cell)
  var b-tmp-ah/ebx: (addr handle cell) <- address b-tmp-storage
  # if cars aren't equal, return false
  car a, a-tmp-ah, trace
  car b, b-tmp-ah, trace
  {
    var _a-tmp/eax: (addr cell) <- lookup *a-tmp-ah
    var a-tmp/ecx: (addr cell) <- copy _a-tmp
    var b-tmp/eax: (addr cell) <- lookup *b-tmp-ah
    var result/eax: boolean <- cell-isomorphic? a-tmp, b-tmp, trace
    compare result, 0/false
    break-if-!=
    trace-higher trace
    trace-text trace, "eval", "=> false (car mismatch)"
    return 0/false
  }
  # recurse on cdrs
  cdr a, a-tmp-ah, trace
  cdr b, b-tmp-ah, trace
  var _a-tmp/eax: (addr cell) <- lookup *a-tmp-ah
  var a-tmp/ecx: (addr cell) <- copy _a-tmp
  var b-tmp/eax: (addr cell) <- lookup *b-tmp-ah
  var result/eax: boolean <- cell-isomorphic? a-tmp, b-tmp, trace
  trace-higher trace
  return result
}

fn fn? _x: (addr cell) -> _/eax: boolean {
  var x/esi: (addr cell) <- copy _x
  var type/eax: (addr int) <- get x, type
  compare *type, 2/symbol
  {
    break-if-=
    return 0/false
  }
  var contents-ah/eax: (addr handle stream byte) <- get x, text-data
  var contents/eax: (addr stream byte) <- lookup *contents-ah
  var result/eax: boolean <- stream-data-equal? contents, "fn"
  return result
}

fn litfn? _x: (addr cell) -> _/eax: boolean {
  var x/esi: (addr cell) <- copy _x
  var type/eax: (addr int) <- get x, type
  compare *type, 2/symbol
  {
    break-if-=
    return 0/false
  }
  var contents-ah/eax: (addr handle stream byte) <- get x, text-data
  var contents/eax: (addr stream byte) <- lookup *contents-ah
  var result/eax: boolean <- stream-data-equal? contents, "litfn"
  return result
}

fn litmac? _x: (addr cell) -> _/eax: boolean {
  var x/esi: (addr cell) <- copy _x
  var type/eax: (addr int) <- get x, type
  compare *type, 2/symbol
  {
    break-if-=
    return 0/false
  }
  var contents-ah/eax: (addr handle stream byte) <- get x, text-data
  var contents/eax: (addr stream byte) <- lookup *contents-ah
  var result/eax: boolean <- stream-data-equal? contents, "litmac"
  return result
}

fn test-evaluate-is-well-behaved {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0/visible  # we don't use trace UI
  # env = nil
  var env-storage: (handle cell)
  var env-ah/ecx: (addr handle cell) <- address env-storage
  allocate-pair env-ah
  # eval sym(a), nil env
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "a"
  evaluate tmp-ah, tmp-ah, *env-ah, 0/no-globals, t, 0/no-screen, 0/no-keyboard, 0/call-number
  # doesn't die
  check-trace-contains t, "error", "unbound symbol: a", "F - test-evaluate-is-well-behaved"
}

fn test-evaluate-number {
  # env = nil
  var env-storage: (handle cell)
  var env-ah/ecx: (addr handle cell) <- address env-storage
  allocate-pair env-ah
  # tmp = 3
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-integer tmp-ah, 3
  evaluate tmp-ah, tmp-ah, *env-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  #
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-number/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-evaluate-number/1"
}

fn test-evaluate-symbol {
  # tmp = (a . 3)
  var val-storage: (handle cell)
  var val-ah/ecx: (addr handle cell) <- address val-storage
  new-integer val-ah, 3
  var key-storage: (handle cell)
  var key-ah/edx: (addr handle cell) <- address key-storage
  new-symbol key-ah, "a"
  var env-storage: (handle cell)
  var env-ah/ebx: (addr handle cell) <- address env-storage
  new-pair env-ah, *key-ah, *val-ah
  # env = ((a . 3))
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  new-pair env-ah, *env-ah, *nil-ah
  # eval sym(a), env
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "a"
  evaluate tmp-ah, tmp-ah, *env-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-symbol/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-evaluate-symbol/1"
}

fn test-evaluate-quote {
  # env = nil
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  # eval `a, env
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "'"
  var tmp2-storage: (handle cell)
  var tmp2-ah/ebx: (addr handle cell) <- address tmp2-storage
  new-symbol tmp2-ah, "a"
  new-pair tmp-ah, *tmp-ah, *tmp2-ah
  evaluate tmp-ah, tmp-ah, *nil-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 2/symbol, "F - test-evaluate-quote/0"
  var sym?/eax: boolean <- symbol-equal? result, "a"
  check sym?, "F - test-evaluate-quote/1"
}

fn test-evaluate-primitive-function {
  var globals-storage: global-table
  var globals/edi: (addr global-table) <- address globals-storage
  initialize-globals globals
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var add-storage: (handle cell)
  var add-ah/ebx: (addr handle cell) <- address add-storage
  new-symbol add-ah, "+"
  # eval +, nil env
  var tmp-storage: (handle cell)
  var tmp-ah/esi: (addr handle cell) <- address tmp-storage
  evaluate add-ah, tmp-ah, *nil-ah, globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  #
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 4/primitive-function, "F - test-evaluate-primitive-function/0"
  var result-value/eax: (addr int) <- get result, index-data
  check-ints-equal *result-value, 1/add, "F - test-evaluate-primitive-function/1"
}

fn test-evaluate-primitive-function-call {
  var t-storage: trace
  var t/edi: (addr trace) <- address t-storage
  initialize-trace t, 0x100, 0/visible  # we don't use trace UI
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
  # input is (+ 1 1)
  var tmp-storage: (handle cell)
  var tmp-ah/esi: (addr handle cell) <- address tmp-storage
  new-pair tmp-ah, *one-ah, *nil-ah
  new-pair tmp-ah, *one-ah, *tmp-ah
  new-pair tmp-ah, *add-ah, *tmp-ah
#?   dump-cell tmp-ah
  #
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  #
  evaluate tmp-ah, tmp-ah, *nil-ah, globals, t, 0/no-screen, 0/no-keyboard, 0/call-number
#?   dump-trace t
  #
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-primitive-function-call/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 2, "F - test-evaluate-primitive-function-call/1"
}

fn test-evaluate-backquote {
  # env = nil
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  # eval `a, env
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "`"
  var tmp2-storage: (handle cell)
  var tmp2-ah/ebx: (addr handle cell) <- address tmp2-storage
  new-symbol tmp2-ah, "a"
  new-pair tmp-ah, *tmp-ah, *tmp2-ah
  clear-object tmp2-ah
  evaluate tmp-ah, tmp2-ah, *nil-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  var result/eax: (addr cell) <- lookup *tmp2-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 2/symbol, "F - test-evaluate-backquote/0"
  var sym?/eax: boolean <- symbol-equal? result, "a"
  check sym?, "F - test-evaluate-backquote/1"
}

fn evaluate-backquote _in-ah: (addr handle cell), _out-ah: (addr handle cell), env-h: (handle cell), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell), call-number: int {
  # stack overflow?   # disable when enabling Really-debug-print
  check-stack
  {
    var screen-cell/eax: (addr handle cell) <- copy screen-cell
    compare screen-cell, 0
    break-if-=
    var screen-cell-addr/eax: (addr cell) <- lookup *screen-cell
    compare screen-cell-addr, 0
    break-if-=
    # if screen-cell exists, we're probably not in a test
    show-stack-state
  }
  # errors? skip
  {
    compare trace, 0
    break-if-=
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    break-if-=
    return
  }
  var in-ah/esi: (addr handle cell) <- copy _in-ah
  var in/eax: (addr cell) <- lookup *in-ah
  {
    var nil?/eax: boolean <- nil? in
    compare nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "eval", "backquote nil"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in, type
  compare *in-type, 0/pair
  {
    break-if-=
    # copy non-pairs directly
    # TODO: streams might need to be copied
    trace-text trace, "eval", "backquote atom"
    copy-object _in-ah, _out-ah
    trace-higher trace
    return
  }
  # 'in' is a pair
  var in-ah/esi: (addr handle cell) <- copy _in-ah
  var _in/eax: (addr cell) <- lookup *in-ah
  var in/ebx: (addr cell) <- copy _in
  var in-left-ah/ecx: (addr handle cell) <- get in, left
  # check for unquote
  {
    var in-left/eax: (addr cell) <- lookup *in-left-ah
    var unquote?/eax: boolean <- symbol-equal? in-left, ","
    compare unquote?, 0/false
    break-if-=
    trace-text trace, "eval", "unquote"
    var rest-ah/eax: (addr handle cell) <- get in, right
    increment call-number
    evaluate rest-ah, _out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    return
  }
  # check for unquote-splice in in-left
  var out-ah/edi: (addr handle cell) <- copy _out-ah
  {
    var in-left/eax: (addr cell) <- lookup *in-left-ah
    {
      var in-left-left-ah/eax: (addr handle cell) <- get in-left, left
      var in-left-left/eax: (addr cell) <- lookup *in-left-left-ah
      var left-is-unquote-splice?/eax: boolean <- symbol-equal? in-left-left, ",@"
      compare left-is-unquote-splice?, 0/false
    }
    break-if-=
    trace-text trace, "eval", "unquote-splice"
    var in-unquote-payload-ah/eax: (addr handle cell) <- get in-left, right
    increment call-number
    evaluate in-unquote-payload-ah, out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    # while (*out-ah != null) out-ah = cdr(out-ah)
    {
      var out/eax: (addr cell) <- lookup *out-ah
      {
        var done?/eax: boolean <- nil? out
        compare done?, 0/false
      }
      break-if-!=
      out-ah <- get out, right
      loop
    }
    # append result of in-right
    var in-right-ah/ecx: (addr handle cell) <- get in, right
    evaluate-backquote in-right-ah, out-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
    return
  }
  # otherwise continue copying
  trace-text trace, "eval", "backquote: copy"
  var out-ah/edi: (addr handle cell) <- copy _out-ah
  allocate-pair out-ah
  var out/eax: (addr cell) <- lookup *out-ah
  var out-left-ah/edx: (addr handle cell) <- get out, left
  evaluate-backquote in-left-ah, out-left-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
  var in-right-ah/ecx: (addr handle cell) <- get in, right
  var out-right-ah/edx: (addr handle cell) <- get out, right
  evaluate-backquote in-right-ah, out-right-ah, env-h, globals, trace, screen-cell, keyboard-cell, call-number
}

fn test-evaluate-backquote-list {
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var backquote-storage: (handle cell)
  var backquote-ah/edx: (addr handle cell) <- address backquote-storage
  new-symbol backquote-ah, "`"
  # input is `(a b)
  var a-storage: (handle cell)
  var a-ah/ebx: (addr handle cell) <- address a-storage
  new-symbol a-ah, "a"
  var b-storage: (handle cell)
  var b-ah/esi: (addr handle cell) <- address b-storage
  new-symbol b-ah, "b"
  var tmp-storage: (handle cell)
  var tmp-ah/eax: (addr handle cell) <- address tmp-storage
  new-pair tmp-ah, *b-ah, *nil-ah
  new-pair tmp-ah, *a-ah, *tmp-ah
  new-pair tmp-ah, *backquote-ah, *tmp-ah
  #
  evaluate tmp-ah, tmp-ah, *nil-ah, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  # result is (a b)
  var result/eax: (addr cell) <- lookup *tmp-ah
  {
    var result-type/eax: (addr int) <- get result, type
    check-ints-equal *result-type, 0/pair, "F - test-evaluate-backquote-list/0"
  }
  {
    var a1-ah/eax: (addr handle cell) <- get result, left
    var a1/eax: (addr cell) <- lookup *a1-ah
    var check1/eax: boolean <- symbol-equal? a1, "a"
    check check1, "F - test-evaluate-backquote-list/1"
  }
  var rest-ah/eax: (addr handle cell) <- get result, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  {
    var a2-ah/eax: (addr handle cell) <- get rest, left
    var a2/eax: (addr cell) <- lookup *a2-ah
    var check2/eax: boolean <- symbol-equal? a2, "b"
    check check2, "F - test-evaluate-backquote-list/2"
  }
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  var check3/eax: boolean <- nil? rest
  check check3, "F - test-evaluate-backquote-list/3"
}

fn test-evaluate-backquote-list-with-unquote {
  var nil-h: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-h
  allocate-pair nil-ah
  var backquote-h: (handle cell)
  var backquote-ah/eax: (addr handle cell) <- address backquote-h
  new-symbol backquote-ah, "`"
  var unquote-h: (handle cell)
  var unquote-ah/eax: (addr handle cell) <- address unquote-h
  new-symbol unquote-ah, ","
  var a-h: (handle cell)
  var a-ah/eax: (addr handle cell) <- address a-h
  new-symbol a-ah, "a"
  var b-h: (handle cell)
  var b-ah/eax: (addr handle cell) <- address b-h
  new-symbol b-ah, "b"
  # env = ((b . 3))
  var val-h: (handle cell)
  var val-ah/eax: (addr handle cell) <- address val-h
  new-integer val-ah, 3
  var env-h: (handle cell)
  var env-ah/eax: (addr handle cell) <- address env-h
  new-pair env-ah, b-h, val-h
  new-pair env-ah, env-h, nil-h
  # input is `(a ,b)
  var tmp-h: (handle cell)
  var tmp-ah/eax: (addr handle cell) <- address tmp-h
  # tmp = cons(unquote, b)
  new-pair tmp-ah, unquote-h, b-h
  # tmp = cons(tmp, nil)
  new-pair tmp-ah, tmp-h, nil-h
  # tmp = cons(a, tmp)
  new-pair tmp-ah, a-h, tmp-h
  # tmp = cons(backquote, tmp)
  new-pair tmp-ah, backquote-h, tmp-h
  #
  evaluate tmp-ah, tmp-ah, env-h, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  # result is (a 3)
  var result/eax: (addr cell) <- lookup *tmp-ah
  {
    var result-type/eax: (addr int) <- get result, type
    check-ints-equal *result-type, 0/pair, "F - test-evaluate-backquote-list-with-unquote/0"
  }
  {
    var a1-ah/eax: (addr handle cell) <- get result, left
    var a1/eax: (addr cell) <- lookup *a1-ah
    var check1/eax: boolean <- symbol-equal? a1, "a"
    check check1, "F - test-evaluate-backquote-list-with-unquote/1"
  }
  var rest-ah/eax: (addr handle cell) <- get result, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  {
    var a2-ah/eax: (addr handle cell) <- get rest, left
    var a2/eax: (addr cell) <- lookup *a2-ah
    var a2-value-addr/eax: (addr float) <- get a2, number-data
    var a2-value/eax: int <- convert *a2-value-addr
    check-ints-equal a2-value, 3, "F - test-evaluate-backquote-list-with-unquote/2"
  }
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  var check3/eax: boolean <- nil? rest
  check check3, "F - test-evaluate-backquote-list-with-unquote/3"
}

fn test-evaluate-backquote-list-with-unquote-splice {
  var nil-h: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-h
  allocate-pair nil-ah
  var backquote-h: (handle cell)
  var backquote-ah/eax: (addr handle cell) <- address backquote-h
  new-symbol backquote-ah, "`"
  var unquote-splice-h: (handle cell)
  var unquote-splice-ah/eax: (addr handle cell) <- address unquote-splice-h
  new-symbol unquote-splice-ah, ",@"
  var a-h: (handle cell)
  var a-ah/eax: (addr handle cell) <- address a-h
  new-symbol a-ah, "a"
  var b-h: (handle cell)
  var b-ah/eax: (addr handle cell) <- address b-h
  new-symbol b-ah, "b"
  # env = ((b . (a 3)))
  var val-h: (handle cell)
  var val-ah/eax: (addr handle cell) <- address val-h
  new-integer val-ah, 3
  new-pair val-ah, val-h, nil-h
  new-pair val-ah, a-h, val-h
  var env-h: (handle cell)
  var env-ah/eax: (addr handle cell) <- address env-h
  new-pair env-ah, b-h, val-h
  new-pair env-ah, env-h, nil-h
  # input is `(a ,@b b)
  var tmp-h: (handle cell)
  var tmp-ah/eax: (addr handle cell) <- address tmp-h
  # tmp = cons(b, nil)
  new-pair tmp-ah, b-h, nil-h
  # tmp2 = cons(unquote-splice, b)
  var tmp2-h: (handle cell)
  var tmp2-ah/ecx: (addr handle cell) <- address tmp2-h
  new-pair tmp2-ah, unquote-splice-h, b-h
  # tmp = cons(tmp2, tmp)
  new-pair tmp-ah, tmp2-h, tmp-h
  # tmp = cons(a, tmp)
  new-pair tmp-ah, a-h, tmp-h
  # tmp = cons(backquote, tmp)
  new-pair tmp-ah, backquote-h, tmp-h
#?   dump-cell-from-cursor-over-full-screen tmp-ah
  #
  evaluate tmp-ah, tmp-ah, env-h, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard, 0/call-number
  # result is (a a 3 b)
#?   dump-cell-from-cursor-over-full-screen tmp-ah
  var result/eax: (addr cell) <- lookup *tmp-ah
  {
    var result-type/eax: (addr int) <- get result, type
    check-ints-equal *result-type, 0/pair, "F - test-evaluate-backquote-list-with-unquote-splice/0"
  }
  {
    var a1-ah/eax: (addr handle cell) <- get result, left
    var a1/eax: (addr cell) <- lookup *a1-ah
    var check1/eax: boolean <- symbol-equal? a1, "a"
    check check1, "F - test-evaluate-backquote-list-with-unquote-splice/1"
  }
  var rest-ah/eax: (addr handle cell) <- get result, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  {
    var a2-ah/eax: (addr handle cell) <- get rest, left
    var a2/eax: (addr cell) <- lookup *a2-ah
    var check2/eax: boolean <- symbol-equal? a2, "a"
    check check2, "F - test-evaluate-backquote-list-with-unquote-splice/2"
  }
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  {
    var a3-ah/eax: (addr handle cell) <- get rest, left
    var a3/eax: (addr cell) <- lookup *a3-ah
    var a3-value-addr/eax: (addr float) <- get a3, number-data
    var a3-value/eax: int <- convert *a3-value-addr
    check-ints-equal a3-value, 3, "F - test-evaluate-backquote-list-with-unquote-splice/3"
  }
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  {
    var a4-ah/eax: (addr handle cell) <- get rest, left
    var a4/eax: (addr cell) <- lookup *a4-ah
    var check4/eax: boolean <- symbol-equal? a4, "b"
    check check4, "F - test-evaluate-backquote-list-with-unquote-splice/4"
  }
  var rest-ah/eax: (addr handle cell) <- get rest, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  var check5/eax: boolean <- nil? rest
  check check5, "F - test-evaluate-backquote-list-with-unquote-splice/5"
}
