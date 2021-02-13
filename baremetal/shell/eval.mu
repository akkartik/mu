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
#   If the final word is `{` or `}`, clear stack
#
#   If `->` in middle and top of stack is falsy, skip next word or group
#
#   If `break` in middle executes, skip to next containing `}`
#     If no containing `}`, clear stack (incomplete)
#
#   If `loop` in middle executes, skip to previous containing `{`
#     If no containing `}`, clear stack (error)

fn evaluate _in: (addr line), end: (addr word), out: (addr value-stack) {
  var line/eax: (addr line) <- copy _in
  var curr-ah/eax: (addr handle word) <- get line, data
  var curr/eax: (addr word) <- lookup *curr-ah
  var curr-stream-storage: (stream byte 0x10)
  var curr-stream/edi: (addr stream byte) <- address curr-stream-storage
  clear-value-stack out
  $evaluate:loop: {
    # safety net (should never hit)
    compare curr, 0
    break-if-=
    # pull next word in for parsing
    emit-word curr, curr-stream
    $evaluate:process-word: {
      ### if curr-stream is an operator, perform it
      {
        var is-add?/eax: boolean <- stream-data-equal? curr-stream, "+"
        compare is-add?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- add b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sub?/eax: boolean <- stream-data-equal? curr-stream, "-"
        compare is-sub?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- subtract b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-mul?/eax: boolean <- stream-data-equal? curr-stream, "*"
        compare is-mul?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- multiply b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-div?/eax: boolean <- stream-data-equal? curr-stream, "/"
        compare is-div?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- divide b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sqrt?/eax: boolean <- stream-data-equal? curr-stream, "sqrt"
        compare is-sqrt?, 0
        break-if-=
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- square-root a
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      ## HACKS: we're trying to avoid turning this into Forth
      {
        var is-dup?/eax: boolean <- stream-data-equal? curr-stream, "dup"
        compare is-dup?, 0
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
        break $evaluate:process-word
      }
      {
        var is-swap?/eax: boolean <- stream-data-equal? curr-stream, "swap"
        compare is-swap?, 0
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
        break $evaluate:process-word
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
        break $evaluate:process-word
      }
      ### if the word starts with a '[' and ends with a ']', turn it into an array
      {
        rewind-stream curr-stream
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x5b/[
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x5d/]
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
        break $evaluate:process-word
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
    curr <- lookup *next-word-ah
    #
    loop
  }
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
  parse-line "\"abc\"", in
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
