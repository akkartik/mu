# evaluator (and parser) for the Mu shell language
# inputs:
#   a list of lines, each a list of words, each an editable gap-buffer
#   end: a word to stop at
# output:
#   a stack of values to render that summarizes the result of evaluation until 'end'

# Key features of the language:
#   words matching '=___' create bindings
#   line boundaries clear the stack (but not bindings)
#   { and } for grouping words
#   break and loop for control flow within groups
#   -> for conditionally skipping the next word or group

# Example: Pushing numbers from 1 to n on the stack
#
#   3 =n
#   { n 1 <     -> break n n 1- =n loop }
#
# Stack as we evaluate each word in the second line:
#     3 1 false          3 3 2  3   1
#       3                  3 3      2
#                                   3

# Rules beyond simple postfix:
#   If the final word is `->`, clear stack
#   If the final word is `break`, pop top of stack
#
#   `{` and `}` don't affect evaluation
#   If the final word is `{` or `}`, clear stack (to suppress rendering it)
#
#   If `->` in middle and top of stack is falsy, skip next word or group
#
#   If `break` in middle executes, skip to next containing `}`
#     If no containing `}`, clear stack (incomplete)
#
#   If `loop` in middle executes, skip to previous containing `{`
#     If no containing `}`, clear stack (error)

fn evaluate _in: (addr line), end: (addr word), out: (addr value-stack) {
  clear-value-stack out
  var line/eax: (addr line) <- copy _in
  var curr-ah/eax: (addr handle word) <- get line, data
  var curr/eax: (addr word) <- lookup *curr-ah
  evaluate-sub curr, end, out, 1/top-level
}

fn evaluate-sub _curr: (addr word), end: (addr word), out: (addr value-stack), top-level?: boolean {
  var curr/ecx: (addr word) <- copy _curr
  var curr-stream-storage: (stream byte 0x10)
  var curr-stream/edi: (addr stream byte) <- address curr-stream-storage
  $evaluate-sub:loop: {
    # safety net (should never hit)
    compare curr, 0
    break-if-=
    # pull next word in for parsing
    emit-word curr, curr-stream
#?     {
#?       clear-screen 0/screen
#?       dump-stack out
#?       var foo/eax: int <- render-word 0/screen, curr, 0/x, 0/y, 0/no-cursor
#?       {
#?         var key/eax: byte <- read-key 0/keyboard
#?         compare key, 0
#?         loop-if-=
#?       }
#?     }
    $evaluate-sub:process-word: {
      ### if curr-stream is an operator, perform it
      {
        var is-add?/eax: boolean <- stream-data-equal? curr-stream, "+"
        compare is-add?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- add b
        push-number-to-value-stack out, a
        break $evaluate-sub:process-word
      }
      {
        var is-sub?/eax: boolean <- stream-data-equal? curr-stream, "-"
        compare is-sub?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- subtract b
        push-number-to-value-stack out, a
        break $evaluate-sub:process-word
      }
      {
        var is-mul?/eax: boolean <- stream-data-equal? curr-stream, "*"
        compare is-mul?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- multiply b
        push-number-to-value-stack out, a
        break $evaluate-sub:process-word
      }
      {
        var is-div?/eax: boolean <- stream-data-equal? curr-stream, "/"
        compare is-div?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- divide b
        push-number-to-value-stack out, a
        break $evaluate-sub:process-word
      }
      {
        var is-sqrt?/eax: boolean <- stream-data-equal? curr-stream, "sqrt"
        compare is-sqrt?, 0/false
        break-if-=
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- square-root a
        push-number-to-value-stack out, a
        break $evaluate-sub:process-word
      }
      {
        var is-lesser?/eax: boolean <- stream-data-equal? curr-stream, "<"
        compare is-lesser?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        compare a, b
        {
          break-if-float<
          push-boolean-to-value-stack out, 0/false
          break $evaluate-sub:process-word
        }
        push-boolean-to-value-stack out, 1/true
        break $evaluate-sub:process-word
      }
      {
        var is-greater?/eax: boolean <- stream-data-equal? curr-stream, ">"
        compare is-greater?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        compare a, b
        {
          break-if-float>
          push-boolean-to-value-stack out, 0/false
          break $evaluate-sub:process-word
        }
        push-boolean-to-value-stack out, 1/true
        break $evaluate-sub:process-word
      }
      {
        var is-equal?/eax: boolean <- stream-data-equal? curr-stream, "=="  # TODO support non-numbers
        compare is-equal?, 0/false
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        compare a, b
        {
          break-if-=
          push-boolean-to-value-stack out, 0/false
          break $evaluate-sub:process-word
        }
        push-boolean-to-value-stack out, 1/true
        break $evaluate-sub:process-word
      }
      ## control flow
      {
        var is-conditional?/eax: boolean <- stream-data-equal? curr-stream, "->"
        compare is-conditional?, 0/false
        break-if-=
        var a/eax: boolean <- pop-boolean-from-value-stack out
        compare a, 0/false
        {
          break-if-!=
          # if a is false, skip one word
          var next-word: (handle word)
          var next-word-ah/eax: (addr handle word) <- address next-word
          skip-word curr, end, next-word-ah
          var _curr/eax: (addr word) <- lookup *next-word-ah
          curr <- copy _curr
        }
        break $evaluate-sub:process-word
      }
      {
        var is-group-start?/eax: boolean <- stream-data-equal? curr-stream, "{"
        compare is-group-start?, 0/false
        break-if-=
        # if top-level? and this is the final word, clear the stack
        compare top-level?, 0/false
        break-if-= $evaluate-sub:process-word
        compare curr, end
        break-if-!= $evaluate-sub:process-word
        clear-value-stack out
        break $evaluate-sub:process-word
      }
      {
        var is-group-end?/eax: boolean <- stream-data-equal? curr-stream, "}"
        compare is-group-end?, 0/false
        break-if-=
        # if top-level? and this is the final word, clear the stack
        compare top-level?, 0/false
        break-if-= $evaluate-sub:process-word
        compare curr, end
        break-if-!= $evaluate-sub:process-word
        clear-value-stack out
        break $evaluate-sub:process-word
      }
      {
        var is-break?/eax: boolean <- stream-data-equal? curr-stream, "break"
        compare is-break?, 0/false
        break-if-=
        # scan ahead to containing '}'
        var next-word: (handle word)
        var next-word-ah/eax: (addr handle word) <- address next-word
        skip-rest-of-group curr, end, next-word-ah
        var _curr/eax: (addr word) <- lookup *next-word-ah
        curr <- copy _curr
        loop $evaluate-sub:loop
      }
      {
        var is-loop?/eax: boolean <- stream-data-equal? curr-stream, "loop"
        compare is-loop?, 0/false
        break-if-=
        # scan back to containing '{'
        var open-word: (handle word)
        var open-word-ah/edx: (addr handle word) <- address open-word
        scan-to-start-of-group curr, end, open-word-ah
        # scan ahead to the containing '}'; record that as next word to eval at
        var close-word: (handle word)
        var close-word-ah/ebx: (addr handle word) <- address close-word
        skip-rest-of-group curr, end, close-word-ah
        var _curr/eax: (addr word) <- lookup *close-word-ah
        curr <- copy _curr
        # now eval until getting there
        # TODO: can 'curr' be after 'end' at this point?
        var open/eax: (addr word) <- lookup *open-word-ah
        evaluate-sub open, curr, out, 0/nested
        loop $evaluate-sub:loop
      }
      ## TEMPORARY HACKS; we're trying to avoid turning this into Forth
      {
        var is-dup?/eax: boolean <- stream-data-equal? curr-stream, "dup"
        compare is-dup?, 0/false
        break-if-=
        # read src-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/ecx: int <- copy *top-addr
        top <- decrement
        var offset/edx: (offset value) <- compute-offset data, top
        var src-val/edx: (addr value) <- index data, offset
        # push a copy of it
        top <- increment
        var offset/ebx: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, offset
        copy-object src-val, target-val
        # commit
        var top-addr/ecx: (addr int) <- get out2, top
        increment *top-addr
        break $evaluate-sub:process-word
      }
      {
        var is-swap?/eax: boolean <- stream-data-equal? curr-stream, "swap"
        compare is-swap?, 0/false
        break-if-=
        # read top-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/ecx: int <- copy *top-addr
        top <- decrement
        var offset/edx: (offset value) <- compute-offset data, top
        var top-val/edx: (addr value) <- index data, offset
        # read next val from out
        top <- decrement
        var offset/ebx: (offset value) <- compute-offset data, top
        var pen-top-val/ebx: (addr value) <- index data, offset
        # swap
        var tmp: value
        var tmp-a/eax: (addr value) <- address tmp
        copy-object top-val, tmp-a
        copy-object pen-top-val, top-val
        copy-object tmp-a, pen-top-val
        break $evaluate-sub:process-word
      }
      ### if the word starts with a quote and ends with a quote, turn it into a string
      {
        rewind-stream curr-stream
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x22/double-quote
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x22/double-quote
        break-if-!=
        var h: (handle array byte)
        var s/eax: (addr handle array byte) <- address h
        unquote-stream-to-array curr-stream, s  # leak
        push-string-to-value-stack out, *s
        break $evaluate-sub:process-word
      }
      ### if the word starts with a '[' and ends with a ']', turn it into an array
      {
        rewind-stream curr-stream
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x5b/open-bracket
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x5d/close-bracket
        break-if-!=
        # wastefully create a new input string to strip quotes
        var h: (handle array value)
        var input-ah/eax: (addr handle array byte) <- address h
        unquote-stream-to-array curr-stream, input-ah  # leak
        # wastefully parse input into int-array
        # TODO: support parsing arrays of other types
        var input/eax: (addr array byte) <- lookup *input-ah
        var h2: (handle array int)
        var int-array-ah/esi: (addr handle array int) <- address h2
        parse-array-of-decimal-ints input, int-array-ah  # leak
        var _int-array/eax: (addr array int) <- lookup *int-array-ah
        var int-array/esi: (addr array int) <- copy _int-array
        var len/ebx: int <- length int-array
        # push value-array of same size as int-array
        var h3: (handle array value)
        var value-array-ah/eax: (addr handle array value) <- address h3
        populate value-array-ah, len
        push-array-to-value-stack out, *value-array-ah
        # copy int-array into value-array
        var _value-array/eax: (addr array value) <- lookup *value-array-ah
        var value-array/edi: (addr array value) <- copy _value-array
        var i/eax: int <- copy 0
        {
          compare i, len
          break-if->=
          var src-addr/ecx: (addr int) <- index int-array, i
          var src/ecx: int <- copy *src-addr
          var src-f/xmm0: float <- convert src
          var dest-offset/edx: (offset value) <- compute-offset value-array, i
          var dest-val/edx: (addr value) <- index value-array, dest-offset
          var dest/edx: (addr float) <- get dest-val, number-data
          copy-to *dest, src-f
          i <- increment
          loop
        }
        break $evaluate-sub:process-word
      }
      ### otherwise assume it's a literal number and push it (can't parse floats yet)
      {
        var n/eax: int <- parse-decimal-int-from-stream curr-stream
        var n-f/xmm0: float <- convert n
        push-number-to-value-stack out, n-f
      }
    }
    # termination check
    compare curr, end
    break-if-=
    # update
    var next-word-ah/edx: (addr handle word) <- get curr, next
    var _curr/eax: (addr word) <- lookup *next-word-ah
    curr <- copy _curr
    #
    loop
  }
}

fn skip-word _curr: (addr word), end: (addr word), out: (addr handle word) {
  var curr/eax: (addr word) <- copy _curr
  var bracket-count/ecx: int <- copy 0
  var result-ah/esi: (addr handle word) <- get curr, next
  {
    var result-val/eax: (addr word) <- lookup *result-ah
    compare result-val, end
    break-if-=
    {
      var open?/eax: boolean <- word-equal? result-val, "{"
      compare open?, 0/false
      break-if-=
      bracket-count <- increment
    }
    {
      var close?/eax: boolean <- word-equal? result-val, "}"
      compare close?, 0/false
      break-if-=
      bracket-count <- decrement
      compare bracket-count, 0
      {
        break-if->=
        abort "'->' cannot be final word in a {} group"  # TODO: error-handling
      }
    }
    compare bracket-count, 0
    break-if-=
    result-ah <- get result-val, next
    loop
  }
  copy-object result-ah, out
}

fn skip-rest-of-group _curr: (addr word), end: (addr word), out: (addr handle word) {
  var curr/eax: (addr word) <- copy _curr
  var bracket-count/ecx: int <- copy 0
  var result-ah/esi: (addr handle word) <- get curr, next
  $skip-rest-of-group:loop: {
    var result-val/eax: (addr word) <- lookup *result-ah
    compare result-val, end
    break-if-=
    {
      var open?/eax: boolean <- word-equal? result-val, "{"
      compare open?, 0/false
      break-if-=
      bracket-count <- increment
    }
    {
      var close?/eax: boolean <- word-equal? result-val, "}"
      compare close?, 0/false
      break-if-=
      compare bracket-count, 0
      break-if-= $skip-rest-of-group:loop
      bracket-count <- decrement
    }
    result-ah <- get result-val, next
    loop
  }
  copy-object result-ah, out
}

fn scan-to-start-of-group _curr: (addr word), end: (addr word), out: (addr handle word) {
  var curr/eax: (addr word) <- copy _curr
  var bracket-count/ecx: int <- copy 0
  var result-ah/esi: (addr handle word) <- get curr, prev
  $scan-to-start-of-group:loop: {
    var result-val/eax: (addr word) <- lookup *result-ah
    compare result-val, end
    break-if-=
    {
      var open?/eax: boolean <- word-equal? result-val, "{"
      compare open?, 0/false
      break-if-=
      compare bracket-count, 0
      break-if-= $scan-to-start-of-group:loop
      bracket-count <- increment
    }
    {
      var close?/eax: boolean <- word-equal? result-val, "}"
      compare close?, 0/false
      break-if-=
      bracket-count <- decrement
    }
    result-ah <- get result-val, prev
    loop
  }
  copy-object result-ah, out
}

fn test-eval-arithmetic {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 1 +", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-arithmetic stack size"
  var n/xmm0: float <- pop-number-from-value-stack out
  var n2/eax: int <- convert n
  check-ints-equal n2, 2, "F - test-eval-arithmetic result"
}

fn test-eval-string {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "\"abc\"", in  # TODO support spaces within strings
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-string stack size"
  var out-data-ah/eax: (addr handle array value) <- get out, data
  var out-data/eax: (addr array value) <- lookup *out-data-ah
  var v/eax: (addr value) <- index out-data, 0
  var type/ecx: (addr int) <- get v, type
  check-ints-equal *type, 1/text, "F - test-eval-string type"
  var text-ah/eax: (addr handle array byte) <- get v, text-data
  var text/eax: (addr array byte) <- lookup *text-ah
  check-strings-equal text, "abc", "F - test-eval-string result"
}

fn test-eval-compare-lesser {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 <", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-compare-lesser stack size"
  var result/eax: boolean <- pop-boolean-from-value-stack out
  check result, "F - test-eval-compare-lesser result"
}

fn test-eval-compare-greater {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "2 1 >", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-compare-greater stack size"
  var result/eax: boolean <- pop-boolean-from-value-stack out
  check result, "F - test-eval-compare-greater result"
}

fn test-eval-compare-equal-fails {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 ==", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-compare-equal-fails stack size"
  var result/eax: boolean <- pop-boolean-from-value-stack out
  check-not result, "F - test-eval-compare-equal-fails result"
}

fn test-eval-compare-equal {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "2 2 ==", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-compare-equal stack size"
  var result/eax: boolean <- pop-boolean-from-value-stack out
  check result, "F - test-eval-compare-equal result"
}

fn test-eval-conditional {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 < -> 3", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-conditional stack size"
  var n/xmm0: float <- pop-number-from-value-stack out
  var n2/eax: int <- convert n
  check-ints-equal n2, 3, "F - test-eval-conditional result"
}

# if top of stack is false, `->` skips one word
fn test-eval-conditional-skipped {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 > -> 3", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 0, "F - test-eval-conditional-skipped stack size"
}

# curlies have no effect in isolation
fn test-eval-group {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "{ 1 } 1 +", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-group stack size"
  var n/xmm0: float <- pop-number-from-value-stack out
  var n2/eax: int <- convert n
  check-ints-equal n2, 2, "F - test-eval-group result"
}

fn test-eval-group-open-at-end {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 1 + {", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 0, "F - test-eval-group-open-at-end stack size"
}

fn test-eval-group-close-at-end {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "{ 1 1 + }", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  #
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 0, "F - test-eval-group-close-at-end stack size"
}

fn test-eval-conditional-skips-group {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 > -> { 3 } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # out contains just the final sentinel '9'
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-conditional-skips-group stack size"
}

fn test-eval-conditional-skips-nested-group {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 > -> { { 3 } 4 } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # out contains just the final sentinel '9'
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-conditional-skips-nested-group stack size"
}

# TODO: test error-handling on:
#   1 2 > -> }

# break skips to next containing `}`
fn test-eval-break {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "3 { 4 break 5 } +", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # result is 3+4, not 4+5
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-break stack size"
  var n/xmm0: float <- pop-number-from-value-stack out
  var n2/eax: int <- convert n
  check-ints-equal n2, 7, "F - test-eval-break result"
}

fn test-eval-break-nested {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "3 { 4 break { 5 } 6 } +", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # result is 3+4, skipping remaining numbers
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-break-nested stack size"
  var n/xmm0: float <- pop-number-from-value-stack out
  var n2/eax: int <- convert n
  check-ints-equal n2, 7, "F - test-eval-break-nested result"
}

#? 1 2 3 4 6 5 { <       -> break loop }
#?  1 2 3 4 6 5   false            2
#?    1 2 3 4 6   4                1
#?      1 2 3 4   3
#?        1 2 3   2
#?          1 2   1
#?            1

#? 1 2 3 4 { 3 ==     -> return loop }
#?  1 2 3 4   3 false            2      => 3
#?    1 2 3   4 3                1
#?      1 2   3 2
#?        1   2 1
#?            1

# loop skips to previous containing `{` and continues evaluating until control
# leaves the group
fn test-eval-loop {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 4 3 { < -> break loop } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # evaluation order: 1 2 4 3 { < -> loop { < -> break 9
  # stack contents: 9
  var len/eax: int <- value-stack-length out
  check-ints-equal len, 1, "F - test-eval-loop stack size"
}

fn test-eval-loop-2 {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 4 3 { 4 == -> break loop } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # evaluation order: 1 2 4 3 { 4 == -> loop { 4 == -> break 9
  # stack contents: 1 2 9
#?   dump-stack out
  var len/eax: int <- value-stack-length out
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, len, 0xc/red, 0/black
  check-ints-equal len, 3, "F - test-eval-loop-2 stack size"
}

fn test-eval-loop-conditional {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 3 { 3 == -> loop } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # evaluation order: 1 2 3 { 3 == -> loop { 3 == -> 9
  # stack contents: 1 9
#?   dump-stack out
  var len/eax: int <- value-stack-length out
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, len, 0xc/red, 0/black
  check-ints-equal len, 2, "F - test-eval-loop-2-conditional stack size"
}

fn test-eval-loop-with-words-after-in-group {
  # in
  var in-storage: line
  var in/esi: (addr line) <- address in-storage
  parse-line "1 2 3 { 3 == -> loop 37 } 9", in
  # end
  var w-ah/eax: (addr handle word) <- get in, data
  var end-h: (handle word)
  var end-ah/ecx: (addr handle word) <- address end-h
  final-word w-ah, end-ah
  var end/eax: (addr word) <- lookup *end-ah
  # out
  var out-storage: value-stack
  var out/edi: (addr value-stack) <- address out-storage
  initialize-value-stack out, 8
  #
  evaluate in, end, out
  # evaluation order: 1 2 3 { 3 == -> loop { 3 == -> 37 } 9
  # stack contents: 1 37 9
#?   dump-stack out
  var len/eax: int <- value-stack-length out
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, len, 0xc/red, 0/black
  check-ints-equal len, 3, "F - test-eval-loop-with-words-after-in-group stack size"
}
