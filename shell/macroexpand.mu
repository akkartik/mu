fn macroexpand expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) {
  # trace "macroexpand " expr-ah {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "macroexpand "
    print-cell expr-ah, stream, 0/no-trace
    trace trace, "mac", stream
  }
  # }}}
  # loop until convergence
  {
    var expanded?/eax: boolean <- macroexpand-iter expr-ah, globals, trace
    compare expanded?, 0/false
    loop-if-!=
  }
  # trace "=> " expr-ah {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> "
    print-cell expr-ah, stream, 0/no-trace
    trace trace, "mac", stream
  }
  # }}}
}

# return true if we found any macros
fn macroexpand-iter _expr-ah: (addr handle cell), globals: (addr global-table), trace: (addr trace) -> _/eax: boolean {
  var expr-ah/esi: (addr handle cell) <- copy _expr-ah
  # trace "macroexpand-iter " expr {{{
  {
    compare trace, 0
    break-if-=
    var stream-storage: (stream byte 0x200)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "macroexpand-iter "
    print-cell expr-ah, stream, 0/no-trace
    trace trace, "mac", stream
  }
  # }}}
  # if expr is a non-pair, return
  var expr/eax: (addr cell) <- lookup *expr-ah
  {
    var nil?/eax: boolean <- nil? expr
    compare nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "mac", "nil"
    trace-higher trace
    return 0/false
  }
  {
    var expr-type/eax: (addr int) <- get expr, type
    compare *expr-type, 0/pair
    break-if-=
    # non-pairs are literals
    trace-text trace, "mac", "non-pair"
    trace-higher trace
    return 0/false
  }
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
  {
    var litmac?/eax: boolean <- litmac? first
    compare litmac?, 0/false
    break-if-=
    # litmac is a literal
    trace-text trace, "mac", "literal macro"
    trace-higher trace
    return 0/false
  }
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
      loop
    }
    trace-higher trace
    return result
  }
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
  $macroexpand-iter:backquote: {
    # nested backquote not supported for now
    var backquote?/eax: boolean <- symbol-equal? first, "`"
    compare backquote?, 0/false
    break-if-=
    #
    error trace, "nested backquote not supported yet"
    trace-higher trace
    return 0/false
  }
  $macroexpand-iter:def: {
    # trees starting with "def" define globals
    var def?/eax: boolean <- symbol-equal? first, "def"
    compare def?, 0/false
    break-if-=
    #
    trace-text trace, "mac", "def"
    var rest/eax: (addr cell) <- lookup *rest-ah
    rest-ah <- get rest, right  # skip name
    rest <- lookup *rest-ah
    var val-ah/edx: (addr handle cell) <- get rest, left
    var macro-found?/eax: boolean <- macroexpand-iter val-ah, globals, trace
    trace-higher trace
    return macro-found?
  }
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
    return macro-found?
  }
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
    apply macro-definition-ah, rest-ah, expr-ah, globals, trace, 0/no-screen, 0/no-keyboard, 0/call-number
    return 1/true
  }
  # no macro found; process any macros within args
  trace-text trace, "mac", "recursing into function definition"
  var curr-ah/ebx: (addr handle cell) <- copy first-ah
  $macroexpand-iter:loop: {
#?     clear-screen 0/screen
#?     dump-trace trace
    var macro-found?/eax: boolean <- macroexpand-iter curr-ah, globals, trace
    result <- or macro-found?
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
  return result
}

fn test-macroexpand {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(def m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk, 0/no-screen, 0/no-tweak-screen
  var trace-ah/eax: (addr handle trace) <- get sandbox, trace
  var trace/eax: (addr trace) <- lookup *trace-ah
  # invoke macro
  initialize-sandbox-with sandbox, "(m 3 4)"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  read-cell gap, result-ah, 0/no-trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "(+ 3 4)"
  var expected-gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/ecx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, 0/no-trace
  check assertion, "F - test-macroexpand"
}

fn test-macroexpand-inside-anonymous-fn {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(def m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk, 0/no-screen, 0/no-tweak-screen
  var trace-ah/eax: (addr handle trace) <- get sandbox, trace
  var trace/eax: (addr trace) <- lookup *trace-ah
  # invoke macro
  initialize-sandbox-with sandbox, "(fn() (m 3 4))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  read-cell gap, result-ah, 0/no-trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "(fn() (+ 3 4))"
  var expected-gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/ecx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, 0/no-trace
  check assertion, "F - test-macroexpand-inside-anonymous-fn"
}

fn test-macroexpand-inside-fn-call {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(def m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk, 0/no-screen, 0/no-tweak-screen
  # invoke macro
  initialize-sandbox-with sandbox, "((fn() (m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  read-cell gap, result-ah, 0/no-trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "((fn() (+ 3 4)))"
  var expected-gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/ecx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, 0/no-trace
#?   dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, 0/no-trace
  check assertion, "F - test-macroexpand-inside-fn-call"
}

fn pending-test-macroexpand-inside-backquote-unquote {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(def m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk, 0/no-screen, 0/no-tweak-screen
  # invoke macro
  initialize-sandbox-with sandbox, "`(print [result is ] ,(m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  read-cell gap, result-ah, 0/no-trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, 0/no-trace
  dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "`(print [result is ] ,(+ 3 4)))"
  var expected-gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/ecx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, 0/no-trace
  dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, 0/no-trace
  check assertion, "F - test-macroexpand-inside-backquote-unquote"
}

fn pending-test-macroexpand-inside-nested-backquote-unquote {
  var globals-storage: global-table
  var globals/edx: (addr global-table) <- address globals-storage
  initialize-globals globals
  # new macro: m
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "(def m (litmac litfn () (a b) `(+ ,a ,b)))"
  edit-sandbox sandbox, 0x13/ctrl-s, globals, 0/no-disk, 0/no-screen, 0/no-tweak-screen
  # invoke macro
  initialize-sandbox-with sandbox, "`(a ,(m 3 4) `(b ,(m 3 4) ,,(m 3 4)))"
  var gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  var result-h: (handle cell)
  var result-ah/ebx: (addr handle cell) <- address result-h
  read-cell gap, result-ah, 0/no-trace
  var dummy/eax: boolean <- macroexpand-iter result-ah, globals, 0/no-trace
  dump-cell-from-cursor-over-full-screen result-ah
  var _result/eax: (addr cell) <- lookup *result-ah
  var result/edi: (addr cell) <- copy _result
  # expected
  initialize-sandbox-with sandbox, "`(a ,(+ 3 4) `(b ,(m 3 4) ,,(+ 3 4)))"
  var expected-gap-ah/ecx: (addr handle gap-buffer) <- get sandbox, data
  var expected-gap/eax: (addr gap-buffer) <- lookup *expected-gap-ah
  var expected-h: (handle cell)
  var expected-ah/ecx: (addr handle cell) <- address expected-h
  read-cell expected-gap, expected-ah, 0/no-trace
  dump-cell-from-cursor-over-full-screen expected-ah
  var expected/eax: (addr cell) <- lookup *expected-ah
  #
  var assertion/eax: boolean <- cell-isomorphic? result, expected, 0/no-trace
  check assertion, "F - test-macroexpand-inside-nested-backquote-unquote"
}

# TODO: unquote-splice, nested and unnested
