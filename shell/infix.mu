fn transform-infix x-ah: (addr handle cell), trace: (addr trace) {
  trace-text trace, "infix", "transform infix"
  trace-lower trace
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "a:", 2/fg 0/bg
#?   dump-cell-from-cursor-over-full-screen x-ah, 7/fg 0/bg
  transform-infix-2 x-ah, trace
  trace-higher trace
}

# Break any symbols containing operators down in place into s-expressions
# Transform (... sym op sym ...) greedily in place into (... (op sym sym) ...)
# Lisp code typed in at the keyboard will never have cycles
fn transform-infix-2 _x-ah: (addr handle cell), trace: (addr trace) {
  var x-ah/edi: (addr handle cell) <- copy _x-ah
  var x/eax: (addr cell) <- lookup *x-ah
  # trace x-ah {{{
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x300)
    var stream/ecx: (addr stream byte) <- address stream-storage
    var nested-trace-storage: trace
    var nested-trace/esi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-cell x-ah, stream, nested-trace
    trace trace, "infix", stream
  }
  # }}}
  trace-lower trace
#?   {
#?     var foo/eax: int <- copy x
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg 0/bg
#?   }
#?   dump-cell-from-cursor-over-full-screen x-ah, 5/fg 0/bg
  # null? return
  compare x, 0
  {
    break-if-!=
    trace-higher trace
    trace-text trace, "infix", "=> NULL"
    return
  }
  # nil? return
  {
    var nil?/eax: boolean <- nil? x
    compare nil?, 0/false
    break-if-=
    trace-higher trace
    trace-text trace, "infix", "=> nil"
    return
  }
  var x-type/ecx: (addr int) <- get x, type
  # symbol? maybe break it down into a pair
  {
    compare *x-type, 2/symbol
    break-if-=
    tokenize-infix x-ah, trace
  }
  # not a pair? return
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "a", 4/fg 0/bg
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, *x-type, 5/fg 0/bg
  {
    compare *x-type, 0/pair
    break-if-=
    trace-higher trace
    # trace "=> " x-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x300)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      var nested-trace-storage: trace
      var nested-trace/esi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell x-ah, stream, nested-trace
      trace trace, "infix", stream
    }
    # }}}
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "^", 4/fg 0/bg
    return
  }
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "b", 4/fg 0/bg
  # singleton operator? unwrap
  {
    var first-ah/ecx: (addr handle cell) <- get x, left
    {
      var first/eax: (addr cell) <- lookup *first-ah
      var infix?/eax: boolean <- operator-symbol? first
      compare infix?, 0/false
    }
    break-if-=
    var rest-ah/eax: (addr handle cell) <- get x, right
    var rest/eax: (addr cell) <- lookup *rest-ah
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-=
    copy-object first-ah, x-ah
    trace-higher trace
    # trace "=> " x-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x300)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      var nested-trace-storage: trace
      var nested-trace/esi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell x-ah, stream, nested-trace
      trace trace, "infix", stream
    }
    # }}}
    return
  }
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "c", 4/fg 0/bg
  # non-singleton pair. try to "pinch out" infix pattern at root
  $transform-infix-2:pinch: {
    # scan past first three elements
    var first-ah/ecx: (addr handle cell) <- get x, left
    var rest-ah/esi: (addr handle cell) <- get x, right
    var rest/eax: (addr cell) <- lookup *rest-ah
    compare rest, 0
    break-if-=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "d", 4/fg 0/bg
    var second-ah/edx: (addr handle cell) <- get rest, left
    rest-ah <- get rest, right
    var rest/eax: (addr cell) <- lookup *rest-ah
    compare rest, 0
    break-if-=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "e", 4/fg 0/bg
    var third-ah/ebx: (addr handle cell) <- get rest, left
    rest-ah <- get rest, right
    # if second is not an operator, break
    {
      var second/eax: (addr cell) <- lookup *second-ah
      var infix?/eax: boolean <- operator-symbol? second
      compare infix?, 0/false
    }
    break-if-=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "f", 4/fg 0/bg
    # swap the top 2
    swap-cells first-ah, second-ah
    # if there's more than three elements, perform a more complex 'rotation'
    rest <- lookup *rest-ah
    var rest-nil?/eax: boolean <- nil? rest
    compare rest-nil?, 0/false
    break-if-!=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "g", 4/fg 0/bg
    # save and clear third->right
    var saved-rest-h: (handle cell)
    var saved-rest-ah/eax: (addr handle cell) <- address saved-rest-h
    copy-object rest-ah, saved-rest-ah
    nil rest-ah
    # create new-node out of first..third and rest
    var result-h: (handle cell)
    var result-ah/eax: (addr handle cell) <- address result-h
    new-pair result-ah, *x-ah, saved-rest-h
    # save
    copy-object result-ah, x-ah
  }
  # recurse after any pinching
  var x/eax: (addr cell) <- lookup *x-ah  # refresh
#?   dump-cell-from-cursor-over-full-screen x-ah, 1/fg 0/bg
  var left-ah/ecx: (addr handle cell) <- get x, left
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "x", 1/fg 0/bg
#?   dump-cell-from-cursor-over-full-screen left-ah, 2/fg 0/bg
  transform-infix-2 left-ah, trace
  var right-ah/ecx: (addr handle cell) <- get x, right
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "y", 1/fg 0/bg
#?   dump-cell-from-cursor-over-full-screen right-ah, 3/fg 0/bg
  transform-infix-2 right-ah, trace
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "z", 1/fg 0/bg
  trace-higher trace
    # trace "=> " x-ah {{{
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
      break-if-=
      var stream-storage: (stream byte 0x300)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      var nested-trace-storage: trace
      var nested-trace/esi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-cell x-ah, stream, nested-trace
      trace trace, "infix", stream
    }
    # }}}
}

fn swap-cells a-ah: (addr handle cell), b-ah: (addr handle cell) {
  var tmp-h: (handle cell)
  var tmp-ah/eax: (addr handle cell) <- address tmp-h
  copy-object a-ah, tmp-ah
  copy-object b-ah, a-ah
  copy-object tmp-ah, b-ah
}

fn tokenize-infix _sym-ah: (addr handle cell), trace: (addr trace) {
#?     # non-symbol operators
#?     {
#?       var operator?/eax: boolean <- operator-grapheme? g
#?       compare operator?, 0/false
#?       break-if-=
#?       next-operator-token in, out, trace
#?       break $next-token:case
#?     }
}

fn test-infix {
  check-infix "abc", "abc", "F - test-infix/regular-symbol"
  check-infix "-3", "-3", "F - test-infix/negative-integer-literal"
  check-infix "[a b+c]", "[a b+c]", "F - test-infix/string-literal"
  check-infix "$a", "$a", "F - test-infix/dollar-var"
  check-infix "$+", "$+", "F - test-infix/dollar-operator"
  check-infix "(+)", "+", "F - test-infix/operator-without-args"
  check-infix "(= (+) 3)", "(= + 3)", "F - test-infix/operator-without-args-2"
  check-infix "($+)", "$+", "F - test-infix/dollar-operator-without-args"
  check-infix "',(a + b)", "',(+ a b)", "F - test-infix/nested-quotes"
#?   check-infix "',(+)", "',+", "F - test-infix/nested-quotes-2"
  check-infix "(a + b)", "(+ a b)", "F - test-infix/simple-list"
  check-infix "(a (+) b)", "(a + b)", "F - test-infix/wrapped-operator"
  check-infix "(+ a b)", "(+ a b)", "F - test-infix/prefix-operator"
  check-infix "(a . b)", "(a . b)", "F - test-infix/dot-operator"
  check-infix "(a b . c)", "(a b . c)", "F - test-infix/dotted-list"
  check-infix "(+ . b)", "(+ . b)", "F - test-infix/dotted-list-with-operator"
  check-infix "(+ a)", "(+ a)", "F - test-infix/unary-operator"
  check-infix "((a + b))", "((+ a b))", "F - test-infix/nested-list"
  check-infix "(do (a + b))", "(do (+ a b))", "F - test-infix/nested-list-2"
  check-infix "(a = (a + 1))", "(= a (+ a 1))", "F - test-infix/nested-list-3"
#?   check-infix "(a + b + c)", "(+ (+ a b) c)", "F - test-infix/left-associative"
#?   check-infix "(f a + b)", "(f (+ a b))", "F - test-infix/higher-precedence-than-call"
#?   check-infix "(f a + b c + d)", "(f (+ a b) (+ c d))", "F - test-infix/multiple"
#?   check-infix "+a", "(+ a)", "F - test-infix/unary-operator-2"
#?   check-infix "-a", "(- a)", "F - test-infix/unary-operator-3"
#?   check-infix "a+b", "(+ a b)", "F - test-infix/no-spaces"
#?   check-infix "',a+b", "',(+ a b)", "F - test-infix/no-spaces-with-nested-quotes"
#?   check-infix "$a+b", "(+ $a b)", "F - test-infix/no-spaces-2"
#?   check-infix "-a+b", "(+ (- a) b)", "F - test-infix/unary-over-binary"
#?   check-infix "~a+b", "(+ (~ a) b)", "F - test-infix/unary-complement"
#?   check-infix "(n * n-1)", "(* n (- n 1))", "F - test-infix/no-spaces-over-spaces"
#?   check-infix "`(a + b)", "`(+ a b)", "F - test-infix/backquote"
#?   check-infix ",@a+b", ",@(+ a b)", "F - test-infix/unquote-splice"
#?   check-infix ",@(a + b)", ",@(+ a b)", "F - test-infix/unquote-splice-2"
}

# helpers

# assumes symbol? is already fully tokenized,
# consists entirely of either operator or non-operator graphemes
fn operator-symbol? _x: (addr cell) -> _/eax: boolean {
  var x/esi: (addr cell) <- copy _x
  {
    var x-type/eax: (addr int) <- get x, type
    compare *x-type, 2/symbol
    break-if-=
    return 0/false
  }
  var x-data-ah/eax: (addr handle stream byte) <- get x, text-data
  var _x-data/eax: (addr stream byte) <- lookup *x-data-ah
  var x-data/esi: (addr stream byte) <- copy _x-data
  rewind-stream x-data
  var g/eax: grapheme <- read-grapheme x-data
  # special case: '$' is reserved for gensyms, and can work with either
  # operator or non-operator symbols.
  {
    compare g, 0x24/dollar
    break-if-!=
    {
      var all-dollars?/eax: boolean <- stream-empty? x-data
      compare all-dollars?, 0/false
      break-if-=
      # '$', '$$', '$$$', etc. are regular symbols
      return 0/false
    }
    g <- read-grapheme x-data
    loop
  }
  var result/eax: boolean <- operator-grapheme? g
  return result
}

fn non-operator-grapheme? g: grapheme -> _/eax: boolean {
  ## whitespace
  compare g, 9/tab
  {
    break-if-!=
    return 0/false
  }
  compare g, 0xa/newline
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x20/space
  {
    break-if-!=
    return 0/false
  }
  ## we don't really use double quotes
  compare g, 0x22/double-quote
  {
    break-if-!=
    return 1/true
  }
  ## brackets
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
  # quotes and unquotes are like symbols for this purpose
  compare g, 0x27/single-quote
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2c/comma
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 1/true
  }
  # - other punctuation
  compare g, 0x23/hash
  {
    break-if-!=
    return 0/false
  }
  return 1/true
}

fn operator-grapheme? g: grapheme -> _/eax: boolean {
  # '$' is a symbol char
  compare g, 0x25/percent
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x26/ampersand
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x27/single-quote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2c/comma
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2a/asterisk
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2b/plus
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2d/dash  # '-' not allowed in symbols
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2e/period
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2f/slash
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3a/colon
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3b/semi-colon
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3c/less-than
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3d/equal
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3e/greater-than
  {
    break-if-!=
    return 1/true
  }
  # '?' is a symbol char
  compare g, 0x5c/backslash
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x5e/caret
  {
    break-if-!=
    return 1/true
  }
  # '_' is a symbol char
  compare g, 0x7c/vertical-line
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x7e/tilde
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

# helpers for tests

fn check-infix actual: (addr array byte), expected: (addr array byte), message: (addr array byte) {
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
#?   initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  initialize-trace trace, 0x10/levels, 0x1000/capacity, 0/visible
  #
  var actual-buffer-storage: gap-buffer
  var actual-buffer/eax: (addr gap-buffer) <- address actual-buffer-storage
  initialize-gap-buffer-with actual-buffer, actual
  var actual-tree-h: (handle cell)
  var actual-tree-ah/esi: (addr handle cell) <- address actual-tree-h
  read-cell actual-buffer, actual-tree-ah, trace
#?   dump-trace-with-label trace, "infix"
  dump-cell-from-cursor-over-full-screen actual-tree-ah, 7/fg 0/bg
  var _actual-tree/eax: (addr cell) <- lookup *actual-tree-ah
  var actual-tree/esi: (addr cell) <- copy _actual-tree
  #
  var expected-buffer-storage: gap-buffer
  var expected-buffer/eax: (addr gap-buffer) <- address expected-buffer-storage
  initialize-gap-buffer-with expected-buffer, expected
  var expected-tree-h: (handle cell)
  var expected-tree-ah/edi: (addr handle cell) <- address expected-tree-h
  read-without-infix expected-buffer, expected-tree-ah, trace
  var expected-tree/eax: (addr cell) <- lookup *expected-tree-ah
  #
  var match?/eax: boolean <- cell-isomorphic? actual-tree, expected-tree, trace
  check match?, message
}

fn read-without-infix in: (addr gap-buffer), out: (addr handle cell), trace: (addr trace) {
  # eagerly tokenize everything so that the phases are easier to see in the trace
  var tokens-storage: (stream token 0x400)
  var tokens/edx: (addr stream token) <- address tokens-storage
  tokenize in, tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    dump-trace trace
    return
  }
  # insert more parens based on indentation
  var parenthesized-tokens-storage: (stream token 0x400)
  var parenthesized-tokens/ecx: (addr stream token) <- address parenthesized-tokens-storage
  parenthesize tokens, parenthesized-tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    dump-trace trace
    return
  }
  parse-input parenthesized-tokens, out, trace
}
