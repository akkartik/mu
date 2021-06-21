## insert explicit parens based on indentation

# Design goals:
#  keywords in other languages should look different from functions: def, if, while, etc.
#  fully-parenthesized expressions should not be messed with
#    ignore indent when lines start with parens
#    ignore indent inside parens
#    no modes to disable this pass
#  introduce no new operators
#    the language doesn't use nested lists like Scheme's `cond`
#    lines with one word are never wrapped in parens
#  encourage macros to explicitly insert all parens
#    ignore indent inside backquote

fn parenthesize in: (addr stream token), out: (addr stream token), trace: (addr trace) {
  trace-text trace, "parenthesize", "insert parens"
  trace-lower trace
  var buffer-storage: (stream token 0x40)
  var buffer/edi: (addr stream token) <- address buffer-storage
  var curr-line-indent: int
  var num-words-in-line: int
  var paren-at-start-of-line?: boolean
  var explicit-open-parens-storage: int
  var explicit-open-parens/ebx: (addr int) <- address explicit-open-parens-storage
  var implicit-open-parens-storage: int-stack
  var implicit-open-parens/esi: (addr int-stack) <- address implicit-open-parens-storage
  initialize-int-stack implicit-open-parens, 0x10  # potentially a major memory leak
  rewind-stream in
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    #
    var curr-token-storage: token
    var curr-token/ecx: (addr token) <- address curr-token-storage
    read-from-stream in, curr-token
#?     dump-token-from-cursor curr-token
    # update state
    {
      var is-indent?/eax: boolean <- indent-token? curr-token
      compare is-indent?, 0/false
      break-if-=
      copy-to num-words-in-line, 0
      copy-to paren-at-start-of-line?, 0/false
      var tmp/eax: int <- indent-level curr-token
      copy-to curr-line-indent, tmp
    }
    {
      var is-word?/eax: boolean <- word-token? curr-token
      compare is-word?, 0/false
      break-if-=
      increment num-words-in-line
    }
    {
      compare num-words-in-line, 0
      break-if-!=
      var is-open?/eax: boolean <- open-paren-token? curr-token
      compare is-open?, 0/false
      break-if-=
      copy-to paren-at-start-of-line?, 1/true
    }
    #
    $parenthesize:emit: {
      {
        compare paren-at-start-of-line?, 0/false
        break-if-=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen "A", 7/fg 0/bg
        emit-all buffer, curr-token, out, explicit-open-parens
        break $parenthesize:emit
      }
      {
        var is-indent?/eax: boolean <- indent-token? curr-token
        compare is-indent?, 0/false
        break-if-=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen "B", 7/fg 0/bg
        emit-all buffer, curr-token, out, explicit-open-parens
        break $parenthesize:emit
      }
      {
        compare num-words-in-line, 2
        break-if->=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen "C", 7/fg 0/bg
        write-to-stream buffer, curr-token
        break $parenthesize:emit
      }
      {
        compare num-words-in-line, 2
        break-if-!=
        var is-word?/eax: boolean <- word-token? curr-token
        compare is-word?, 0/false
        break-if-=
        compare *explicit-open-parens, 0
        break-if-!=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen "(\n", 7/fg 0/bg
        var paren-storage: token
        var paren-token/eax: (addr token) <- address paren-storage
        initialize-token paren-token, "("
        write-to-stream out, paren-token
        push-int-stack implicit-open-parens, curr-line-indent
      }
      emit-all buffer, curr-token, out, explicit-open-parens
    }
    {
      var is-indent?/eax: boolean <- indent-token? curr-token
      compare is-indent?, 0/false
      break-if-=
      {
        # . loop check
        var done?/eax: boolean <- int-stack-empty? implicit-open-parens
        compare done?, 0/false
        break-if-!=
        var top-indent/eax: int <- int-stack-top implicit-open-parens
        compare top-indent, curr-line-indent
        break-if-<
        # . loop body
        var paren-storage: token
        var paren-token/eax: (addr token) <- address paren-storage
        initialize-token paren-token, ")"
        write-to-stream out, paren-token
        # . update
        var dummy/eax: int <- pop-int-stack implicit-open-parens
        loop
      }
    }
    loop
  }
  emit-all buffer, 0/no-curr-token, out, explicit-open-parens
  {
    # . loop check
    var done?/eax: boolean <- int-stack-empty? implicit-open-parens
    compare done?, 0/false
    break-if-!=
    # . loop body
    var paren-storage: token
    var paren-token/eax: (addr token) <- address paren-storage
    initialize-token paren-token, ")"
    write-to-stream out, paren-token
    # . update
    var dummy/eax: int <- pop-int-stack implicit-open-parens
    loop
  }
  trace-higher trace
}

fn indent-level _in: (addr token) -> _/eax: int {
  var in/eax: (addr token) <- copy _in
  var result/eax: (addr int) <- get in, number-data
  return *result
}

fn word-token? in: (addr token) -> _/eax: boolean {
  {
    var is-indent?/eax: boolean <- indent-token? in
    compare is-indent?, 0/false
    break-if-!=
    var is-bracket?/eax: boolean <- bracket-token? in  # overzealously checks for [], but shouldn't ever encounter it
    compare is-bracket?, 0/false
    break-if-!=
    var is-quote?/eax: boolean <- quote-token? in
    compare is-quote?, 0/false
    break-if-!=
    var is-backquote?/eax: boolean <- backquote-token? in
    compare is-backquote?, 0/false
    break-if-!=
    var is-unquote?/eax: boolean <- unquote-token? in
    compare is-unquote?, 0/false
    break-if-!=
    var is-unquote-splice?/eax: boolean <- unquote-splice-token? in
    compare is-unquote-splice?, 0/false
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn emit-all first: (addr stream token), second: (addr token), out: (addr stream token), explicit-open-parens: (addr int) {
  rewind-stream first
  {
    var done?/eax: boolean <- stream-empty? first
    compare done?, 0/false
    break-if-!=
    var curr-token-storage: token
    var curr-token/eax: (addr token) <- address curr-token-storage
    read-from-stream first, curr-token
    emit curr-token, out, explicit-open-parens
    loop
  }
  clear-stream first
  {
    compare second, 0
    break-if-=
    emit second, out, explicit-open-parens
  }
}

fn emit t: (addr token), out: (addr stream token), explicit-open-parens: (addr int) {
  {
    var is-indent?/eax: boolean <- indent-token? t
    compare is-indent?, 0/false
    break-if-=
    return
  }
  write-to-stream out, t
  var explicit-open-parens/edi: (addr int) <- copy explicit-open-parens
  {
    var is-open?/eax: boolean <- open-paren-token? t
    compare is-open?, 0/false
    break-if-=
    increment *explicit-open-parens
  }
  {
    var is-close?/eax: boolean <- close-paren-token? t
    compare is-close?, 0/false
    break-if-=
    decrement *explicit-open-parens
    compare *explicit-open-parens, 0
    break-if->=
    abort "emit: extra ')'"
  }
}

# helper for checking parenthesize
fn emit-salient-tokens in: (addr stream token), out: (addr stream token) {
  rewind-stream in
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var token-storage: token
    var token/edx: (addr token) <- address token-storage
    read-from-stream in, token
    # skip tokens should be skipped
    var is-skip?/eax: boolean <- skip-token? token
    compare is-skip?, 0/false
    loop-if-!=
    # indent tokens should be skipped
    var is-indent?/eax: boolean <- indent-token? token
    compare is-indent?, 0/false
    loop-if-!=
    #
    write-to-stream out, token  # shallow copy
    loop
  }
}

fn test-parenthesize {
  check-parenthesize "a b c  ", "(a b c)", "F - test-parenthesize/1"
  check-parenthesize "a (b)", "(a (b))", "F - test-parenthesize/2"
  check-parenthesize "a (b c)", "(a (b c))", "F - test-parenthesize/3"
  check-parenthesize "a (b c) d", "(a (b c) d)", "F - test-parenthesize/4"
  check-parenthesize "a b c\nd ef", "(a b c) (d ef)", "F - test-parenthesize/5-multiple-lines"
  check-parenthesize "a b c\n  d ef", "(a b c (d ef))", "F - test-parenthesize/6-indented"
  check-parenthesize "a b c\n  (d ef)", "(a b c (d ef))", "F - test-parenthesize/7-indented"
  check-parenthesize "a b c\n  (d ef)\n  g", "(a b c (d ef) g)", "F - test-parenthesize/8-indented"
  check-parenthesize "a b c\n  d e\n    f\ny", "(a b c (d e f)) y", "F - test-parenthesize/9-indented"
  check-parenthesize "#a\na b", "(a b)", "F - test-parenthesize/10-initial-comment"
#? a b c
#?     d ef
#? 
#?   g
#?   check-parenthesize "a b c\n    d ef\n\n  g", "(a b c (d ef) g)", "F - test-parenthesize/11-comments"
#?   check-parenthesize "a b c\n    d ef\n\n  g #abc", "(a b c (d ef)) g", "F - test-parenthesize/11-comments"
  check-parenthesize "a b c\n    d ef\n\n  g #abc", "(a b c (d ef) g)", "F - test-parenthesize/11-comments"
#? a b c
#?   '(d ef)
#? 
#?   g #abc
#?   check-parenthesize "a b c\n  '(d ef)\n  g #abc", "(a b c '(d ef) g)", "F - test-parenthesize/12-quotes-and-comments"
  check-parenthesize "a b c\n  '(d ef)\n\n  g #abc", "(a b c '(d ef) g)", "F - test-parenthesize/12-quotes-and-comments"
  check-parenthesize "  a b c", "(a b c)", "F - test-parenthesize/13-initial-indent"
  check-parenthesize "    a b c\n  34", "(a b c) 34", "F - test-parenthesize/14-initial-indent"
  check-parenthesize "def foo\n    a b c\n  d e\nnewdef", "(def foo (a b c) (d e)) newdef", "F - test-parenthesize/14"
  check-parenthesize "  a a\n    a\ny", "(a a a) y", "F - test-parenthesize/15-group-before-too-much-outdent"
  check-parenthesize "a `(b c)", "(a `(b c))", "F - test-parenthesize/16-backquote"
  check-parenthesize "'a b c", "('a b c)", "F - test-parenthesize/17-quote"
  check-parenthesize ",a b c", "(,a b c)", "F - test-parenthesize/18-unquote"
  check-parenthesize ",@a b c", "(,@a b c)", "F - test-parenthesize/19-unquote-splice"
  check-parenthesize "a b\n  'c\n  ,d\n  e", "(a b 'c ,d e)", "F - test-parenthesize/20-quotes-are-not-words"
  check-parenthesize "def foo\n#a b c\n  d e\nnew", "(def foo (d e)) new", "F - test-parenthesize/21-group-across-comments"
}

fn test-parenthesize-skips-lines-with-initial-parens {
  check-parenthesize "(a b c)", "(a b c)", "F - test-parenthesize-skips-lines-with-initial-parens/1"
  check-parenthesize "(a (b c))", "(a (b c))", "F - test-parenthesize-skips-lines-with-initial-parens/2"
  check-parenthesize "(a () b)", "(a () b)", "F - test-parenthesize-skips-lines-with-initial-parens/3"
  check-parenthesize "  (a b c)", "(a b c)", "F - test-parenthesize-skips-lines-with-initial-parens/initial-indent"
  check-parenthesize "(a b c\n  bc\n    def\n  gh)", "(a b c bc def gh)", "F - test-parenthesize-skips-lines-with-initial-parens/outdent"
  check-parenthesize "(a b c\n  (def gh)\n    (i j k)\n  lm\n\n\n    (no p))", "(a b c (def gh) (i j k) lm (no p))", "F - test-parenthesize-skips-lines-with-initial-parens/fully-parenthesized"
  check-parenthesize ",(a b c)", ",(a b c)", "F - test-parenthesize-skips-lines-with-initial-parens/after-unquote"
  check-parenthesize ",@(a b c)", ",@(a b c)", "F - test-parenthesize-skips-lines-with-initial-parens/after-unquote-splice"
  check-parenthesize ",,(a b c)", ",,(a b c)", "F - test-parenthesize-skips-lines-with-initial-parens/after-nested-unquote"
  check-parenthesize "(def foo\n    #a b c\n  d e)\nnew", "(def foo d e) new", "F - test-parenthesize-skips-lines-with-initial-parens/across-comment"
  check-parenthesize "`(def foo\n    #a b c\n  d e)\nnew", "`(def foo d e) new", "F - test-parenthesize-skips-lines-with-initial-parens/across-comment-after-backquote"
  check-parenthesize "  (a b c\n    d e)", "(a b c d e)", "F - test-parenthesize-skips-lines-with-initial-parens/with-indent"
  check-parenthesize "def foo(a (b)\n    c d)\n  d e\nnew", "(def foo (a (b) c d) (d e)) new", "F - test-parenthesize-skips-lines-with-initial-parens/inside-arg-lists"
}

fn test-parenthesize-skips-single-word-lines {
  # lines usually get grouped with later indented lines
  check-parenthesize "a b\n  c", "(a b c)", "F - test-parenthesize-skips-single-word-lines/0"
  # but single-word lines don't
  check-parenthesize "a\n  c", "a c", "F - test-parenthesize-skips-single-word-lines/1"
  check-parenthesize "a", "a", "F - test-parenthesize-skips-single-word-lines/2"
  check-parenthesize "a  \nb\nc", "a b c", "F - test-parenthesize-skips-single-word-lines/3"
}

fn check-parenthesize actual: (addr array byte), expected: (addr array byte), message: (addr array byte) {
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  #
  var actual-buffer-storage: gap-buffer
  var actual-buffer/eax: (addr gap-buffer) <- address actual-buffer-storage
  initialize-gap-buffer-with actual-buffer, actual
  var actual-tokens-storage: (stream token 0x40)
  var actual-tokens/esi: (addr stream token) <- address actual-tokens-storage
  tokenize-and-parenthesize actual-buffer, actual-tokens, trace
  #
  var expected-buffer-storage: gap-buffer
  var expected-buffer/eax: (addr gap-buffer) <- address expected-buffer-storage
  initialize-gap-buffer-with expected-buffer, expected
  var expected-tokens-storage: (stream token 0x40)
  var expected-tokens/edi: (addr stream token) <- address expected-tokens-storage
  tokenize-salient expected-buffer, expected-tokens, trace
  #
  rewind-stream actual-tokens
  check-token-streams-data-equal actual-tokens, expected-tokens, message
}

fn check-token-streams-data-equal actual: (addr stream token), expected: (addr stream token), message: (addr array byte) {
  rewind-stream actual
  rewind-stream expected
  {
    # loop termination checks
    var actual-done?/eax: boolean <- stream-empty? actual
    {
      compare actual-done?, 0/false
      break-if-=
      var expected-done?/eax: boolean <- stream-empty? expected
      compare expected-done?, 0/false
      {
        break-if-!=
        # actual empty, but expected not empty
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, message, 3/fg=cyan 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": too short\n", 3/fg=cyan 0/bg
        count-test-failure
        return
      }
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg/cyan, 0/bg
      return
    }
    var expected-done?/eax: boolean <- stream-empty? expected
    compare expected-done?, 0/false
    {
      break-if-=
      # actual not empty, but expected empty
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, message, 3/fg=cyan 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": too long\n", 3/fg=cyan 0/bg
      count-test-failure
      return
    }
    # loop body
    var curr-token-storage: token
    var curr-token/ecx: (addr token) <- address curr-token-storage
    read-from-stream actual, curr-token
#?     dump-token-from-cursor curr-token
    var expected-token-storage: token
    var expected-token/edx: (addr token) <- address expected-token-storage
    read-from-stream expected, expected-token
#?     dump-token-from-cursor expected-token
    var match?/eax: boolean <- tokens-equal? curr-token, expected-token
    compare match?, 0/false
    {
      break-if-!=
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, message, 3/fg=cyan 0/bg
      count-test-failure
      return
    }
    loop
  }
}

fn tokenize-and-parenthesize in: (addr gap-buffer), out: (addr stream token), trace: (addr trace) {
  var tokens-storage: (stream token 0x400)
  var tokens/edx: (addr stream token) <- address tokens-storage
  tokenize in, tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    return
  }
  parenthesize tokens, out, trace
}

fn tokenize-salient in: (addr gap-buffer), out: (addr stream token), trace: (addr trace) {
  var tokens-storage: (stream token 0x400)
  var tokens/edx: (addr stream token) <- address tokens-storage
  tokenize in, tokens, trace
  var error?/eax: boolean <- has-errors? trace
  compare error?, 0/false
  {
    break-if-=
    return
  }
  emit-salient-tokens tokens, out
}
