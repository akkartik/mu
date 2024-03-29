fn macroexpand expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  # trace "macroexpand " expr-ah {{{
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "macroexpand "
    var nested-trace-storage: trace
    var nested-trace/edi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-cell expr-ah, stream, nested-trace
    trace trace, "mac", stream
  }
  # }}}
  trace-lower trace
#?   clear-screen 0
#?   set-cursor-position 0, 0x20 0x20
  # loop until convergence
  {
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    break-if-!=
    var expanded?/eax: boolean <- macroexpand-iter expr-ah, globals, trace
    compare expanded?, 0/false
    loop-if-!=
  }
  trace-higher trace
  # trace "=> " expr-ah {{{
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> "
    var nested-trace-storage: trace
    var nested-trace/edi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-cell expr-ah, stream, nested-trace
    trace trace, "mac", stream
  }
  # }}}
}

# return true if we found any macros
fn macroexpand-iter _expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) -> _/eax: boolean {
  var expr-ah/esi: (addr handle cell) <- copy _expr-ah
  {
    compare expr-ah, 0
    break-if-!=
    abort "macroexpand-iter: NULL expr-ah"
  }
  # trace "macroexpand-iter " expr {{{
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "macroexpand-iter "
    var nested-trace-storage: trace
    var nested-trace/edi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-cell expr-ah, stream, nested-trace
    trace trace, "mac", stream
  }
  # }}}
  trace-lower trace
  debug-print "a", 7/fg, 0/bg
  # if expr is a non-pair, return
  var expr/eax: (addr cell) <- lookup *expr-ah
  {
    compare expr, 0
    break-if-!=
    abort "macroexpand-iter: NULL expr"
  }
  {
    var nil?/eax: boolean <- nil? expr
    compare nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "mac", "nil"
    trace-higher trace
    return 0/false
  }
  debug-print "b", 7/fg, 0/bg
  {
    var expr-type/eax: (addr int) <- get expr, type
    compare *expr-type, 0/pair
    break-if-=
    # non-pairs are literals
    trace-text trace, "mac", "non-pair"
    trace-higher trace
    return 0/false
  }
  debug-print "c", 7/fg, 0/bg
  # if expr is a literal pair, return
  var first-ah/ebx: (addr handle cell) <- get expr, left
  var rest-ah/ecx: (addr handle cell) <- get expr, right
  var first/eax: (addr cell) <- lookup *first-ah
  {
    var litfn?/eax: boolean <- litfn? first
    compare litfn?, 0/false
    break-if-=
    # litfn is a literal
    trace-text trace, "mac", "literal function"
    trace-higher trace
    return 0/false
  }
  debug-print "d", 7/fg, 0/bg
  {
    var litmac?/eax: boolean <- litmac? first
    compare litmac?, 0/false
    break-if-=
    # litmac is a literal
    trace-text trace, "mac", "literal macro"
    trace-higher trace
    return 0/false
  }
  debug-print "e", 7/fg, 0/bg
  {
    var litimg?/eax: boolean <- litimg? first
    compare litimg?, 0/false
    break-if-=
    # litimg is a literal
    trace-text trace, "mac", "literal image"
    trace-higher trace
    return 0/false
  }
  debug-print "f", 7/fg, 0/bg
  var result/edi: boolean <- copy 0/false
  # for each builtin, expand only what will later be evaluated
  $macroexpand-iter:anonymous-function: {
    var fn?/eax: boolean <- fn? first
    compare fn?, 0/false
    break-if-=
    # fn: expand every expression in the body
    trace-text trace, "mac", "anonymous function"
    # skip parameters
    var rest/eax: (addr cell) <- lookup *rest-ah
    {
      rest-ah <- get rest, right
      rest <- lookup *rest-ah
      {
        var done?/eax: boolean <- nil? rest
        compare done?, 0/false
      }
      break-if-!=
      var curr-ah/eax: (addr handle cell) <- get rest, left
      var macro-found?/eax: boolean <- macroexpand-iter curr-ah, globals, trace
      result <- or macro-found?
      {
        var error?/eax: boolean <- has-errors? trace
        compare error?, 0/false
        break-if-=
        trace-higher trace
        return result
      }
      loop
    }
    trace-higher trace
    # trace "fn=> " _expr-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "fn=> "
      var nested-trace-storage: trace
      var nested-trace/edi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell _expr-ah, stream, nested-trace
      trace trace, "mac", stream
    }
    # }}}
    return result
  }
  debug-print "g", 7/fg, 0/bg
  # builtins with "special" evaluation rules
  $macroexpand-iter:quote: {
    # trees starting with single quote create literals
    var quote?/eax: boolean <- symbol-equal? first, "'"
    compare quote?, 0/false
    break-if-=
    #
    trace-text trace, "mac", "quote"
    trace-higher trace
    return 0/false
  }
  debug-print "h", 7/fg, 0/bg
  $macroexpand-iter:backquote: {
    # nested backquote not supported for now
    var backquote?/eax: boolean <- symbol-equal? first, "`"
    compare backquote?, 0/false
    break-if-=
    #
#?     set-cursor-position 0/screen, 0x40/x 0x10/y
#?     dump-cell-from-cursor-over-full-screen rest-ah
    var double-unquote-found?/eax: boolean <- look-for-double-unquote rest-ah
    compare double-unquote-found?, 0/false
    {
      break-if-=
      error trace, "double unquote not supported yet"
    }
    trace-higher trace
    return 0/false
  }
  $macroexpand-iter:unquote: {
    # nested backquote not supported for now
    var unquote?/eax: boolean <- symbol-equal? first, ","
    compare unquote?, 0/false
    break-if-=
    error trace, "unquote (,) must be within backquote (`)"
    return 0/false
  }
  $macroexpand-iter:unquote-splice: {
    # nested backquote not supported for now
    var unquote-splice?/eax: boolean <- symbol-equal? first, ",@"
    compare unquote-splice?, 0/false
    break-if-=
    error trace, "unquote (,@) must be within backquote (`)"
    return 0/false
  }
  debug-print "i", 7/fg, 0/bg
  $macroexpand-iter:define: {
    # trees starting with "define" define globals
    var define?/eax: boolean <- symbol-equal? first, "define"
    compare define?, 0/false
    break-if-=
    #
    trace-text trace, "mac", "define"
    var rest/eax: (addr cell) <- lookup *rest-ah
    rest-ah <- get rest, right  # skip name
    rest <- lookup *rest-ah
    var val-ah/edx: (addr handle cell) <- get rest, left
    var macro-found?/eax: boolean <- macroexpand-iter val-ah, globals, trace
    trace-higher trace
    # trace "define=> " _expr-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "define=> "
      var nested-trace-storage: trace
      var nested-trace/edi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell _expr-ah, stream, nested-trace
      trace trace, "mac", stream
    }
    # }}}
    return macro-found?
  }
  debug-print "j", 7/fg, 0/bg
  $macroexpand-iter:set: {
    # trees starting with "set" mutate bindings
    var set?/eax: boolean <- symbol-equal? first, "set"
    compare set?, 0/false
    break-if-=
    #
    trace-text trace, "mac", "set"
    var rest/eax: (addr cell) <- lookup *rest-ah
    rest-ah <- get rest, right  # skip name
    rest <- lookup *rest-ah
    var val-ah/edx: (addr handle cell) <- get rest, left
    var macro-found?/eax: boolean <- macroexpand-iter val-ah, globals, trace
    trace-higher trace
    # trace "set=> " _expr-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "set=> "
      var nested-trace-storage: trace
      var nested-trace/edi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell _expr-ah, stream, nested-trace
      trace trace, "mac", stream
    }
    # }}}
    return macro-found?
  }
  debug-print "k", 7/fg, 0/bg
  # 'and' is like a function for macroexpansion purposes
  # 'or' is like a function for macroexpansion purposes
  # 'if' is like a function for macroexpansion purposes
  # 'while' is like a function for macroexpansion purposes
  # if car(expr) is a symbol defined as a macro, expand it
  {
    var definition-h: (handle cell)
    var definition-ah/edx: (addr handle cell) <- address definition-h
    maybe-lookup-symbol-in-globals first, definition-ah, globals, trace
    var definition/eax: (addr cell) <- lookup *definition-ah
    compare definition, 0
    break-if-=
    # definition found
    {
      var definition-type/eax: (addr int) <- get definition, type
      compare *definition-type, 0/pair
    }
    break-if-!=
    # definition is a pair
    {
      var definition-car-ah/eax: (addr handle cell) <- get definition, left
      var definition-car/eax: (addr cell) <- lookup *definition-car-ah
      var macro?/eax: boolean <- litmac? definition-car
      compare macro?, 0/false
    }
    break-if-=
    # definition is a macro
    var macro-definition-ah/eax: (addr handle cell) <- get definition, right
    # TODO: check car(macro-definition) is litfn
#?     turn-on-debug-print
    apply macro-definition-ah, rest-ah, expr-ah, globals, trace, 0/no-screen, 0/no-keyboard, 0/definitions-created, 0/call-number
    trace-higher trace
    # trace "1=> " _expr-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x200)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "1=> "
      var nested-trace-storage: trace
      var nested-trace/edi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell _expr-ah, stream, nested-trace
      trace trace, "mac", stream
    }
    # }}}
    return 1/true
  }
  # no macro found; process any macros within args
  trace-text trace, "mac", "recursing into function definition"
  var curr-ah/ebx: (addr handle cell) <- copy first-ah
  $macroexpand-iter:loop: {
    debug-print "l", 7/fg, 0/bg
#?     clear-screen 0/screen
#?     dump-trace trace
    {
      var foo/eax: (addr cell) <- lookup *curr-ah
      compare foo, 0
      break-if-!=
      abort "macroexpand-iter: NULL in loop"
    }
    var macro-found?/eax: boolean <- macroexpand-iter curr-ah, globals, trace
    result <- or macro-found?
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    break-if-!=
    var rest/eax: (addr cell) <- lookup *rest-ah
    {
      var nil?/eax: boolean <- nil? rest
      compare nil?, 0/false
    }
    break-if-!=
    curr-ah <- get rest, left
    rest-ah <- get rest, right
    loop
  }
  trace-higher trace
  # trace "=> " _expr-ah {{{
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> "
    var nested-trace-storage: trace
    var nested-trace/edi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-cell _expr-ah, stream, nested-trace
    trace trace, "mac", stream
  }
  # }}}
  return result
}

fn look-for-double-unquote _expr-ah: (addr handle cell) -> _/eax: boolean {
  # if expr is a non-pair, return false
  var expr-ah/eax: (addr handle cell) <- copy _expr-ah
  var expr/eax: (addr cell) <- lookup *expr-ah
  {
    var nil?/eax: boolean <- nil? expr
    compare nil?, 0/false
    break-if-=
    return 0/false
  }
  {
    var expr-type/eax: (addr int) <- get expr, type
    compare *expr-type, 0/pair
    break-if-=
    return 0/false
  }
  var cdr-ah/ecx: (addr handle cell) <- get expr, right
  var car-ah/ebx: (addr handle cell) <- get expr, left
  var car/eax: (addr cell) <- lookup *car-ah
  # if car is unquote or unquote-splice, check if cadr is unquote or
  # unquote-splice.
  $look-for-double-unquote:check: {
    # if car is not an unquote, break
    {
      {
        var unquote?/eax: boolean <- symbol-equal? car, ","
        compare unquote?, 0/false
      }
      break-if-!=
      var unquote-splice?/eax: boolean <- symbol-equal? car, ",@"
      compare unquote-splice?, 0/false
      break-if-!=
      break $look-for-double-unquote:check
    }
    # if cdr is not a pair, break
    var cdr/eax: (addr cell) <- lookup *cdr-ah
    var cdr-type/ecx: (addr int) <- get cdr, type
    compare *cdr-type, 0/pair
    break-if-!=
    # if cadr is not an unquote, break
    var cadr-ah/eax: (addr handle cell) <- get cdr, left
    var cadr/eax: (addr cell) <- lookup *cadr-ah
    {
      {
        var unquote?/eax: boolean <- symbol-equal? cadr, ","
        compare unquote?, 0/false
      }
      break-if-!=
      var unquote-splice?/eax: boolean <- symbol-equal? cadr, ",@"
      compare unquote-splice?, 0/false
      break-if-!=
      break $look-for-double-unquote:check
    }
    # error
    return 1/true
  }
  var result/eax: boolean <- look-for-double-unquote car-ah
  compare result, 0/false
  {
    break-if-=
    return result
  }
  result <- look-for-double-unquote cdr-ah
  return result
}

fn test-macroexpand {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(define m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk
  # invoke macro
  initialize-sandbox-with sandbox, "(m 3 4)"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand/error"
#?   dump-cell-from-cursor-over-full-screen result-ah, 4/fg 0/bg
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "(+ 3 4)"
  var expected-gap-ah/edx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/edx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, trace
  check assertion, "F - test-macroexpand"
}

fn test-macroexpand-inside-anonymous-fn {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(define m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk
  # invoke macro
  initialize-sandbox-with sandbox, "(fn() (m 3 4))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand-inside-anonymous-fn/error"
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "(fn() (+ 3 4))"
  var expected-gap-ah/edx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/edx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, trace
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, trace
  check assertion, "F - test-macroexpand-inside-anonymous-fn"
}

fn test-macroexpand-inside-fn-call {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(define m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk
  # invoke macro
  initialize-sandbox-with sandbox, "((fn() (m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand-inside-fn-call/error"
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "((fn() (+ 3 4)))"
  var expected-gap-ah/edx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/edx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, trace
  check assertion, "F - test-macroexpand-inside-fn-call"
}

fn test-macroexpand-repeatedly-with-backquoted-arg {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # macroexpand an expression with a backquote but no macro
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(cons 1 `(3))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand-repeatedly-with-backquoted-arg"
  {
    compare error?, 0/false
    break-if-=
    # we need space to display traces, so just stop rendering future tests on failure here
    dump-trace trace
    {
      loop
    }
  }
}

fn pending-test-macroexpand-inside-backquote-unquote {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(define m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk
  # invoke macro
  initialize-sandbox-with sandbox, "`(print [result is ] ,(m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand-inside-backquote-unquote/error"
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "`(print [result is ] ,(+ 3 4)))"
  var expected-gap-ah/edx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/edx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, trace
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, trace
  check assertion, "F - test-macroexpand-inside-backquote-unquote"
}

fn pending-test-macroexpand-inside-nested-backquote-unquote {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(define m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk
  # invoke macro
  initialize-sandbox-with sandbox, "`(a ,(m 3 4) `(b ,(m 3 4) ,,(m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  var trace-storage: trace
  var trace/ecx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell gap, result-ah, trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  check-not error?, "F - test-macroexpand-inside-nested-backquote-unquote/error"
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "`(a ,(+ 3 4) `(b ,(m 3 4) ,,(+ 3 4)))"
  var expected-gap-ah/edx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/edx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, trace
  check assertion, "F - test-macroexpand-inside-nested-backquote-unquote"
}

# TODO: unquote-splice, nested and unnested
