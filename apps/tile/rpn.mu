fn evaluate start: (addr word), end: (addr word), out: (addr int-stack) {
  var curr/eax: (addr word) <- copy start
  var curr-text-storage: (stream byte 0x10)
  var curr-text/edi: (addr stream byte) <- address curr-text-storage
  clear-int-stack out
  $evaluate:loop: {
    # precondition (should never hit)
    compare curr, 0
    break-if-=
    # update curr-text
    emit-word curr, curr-text
    $evaluate:process-word: {
      # if curr-text is an operator, perform it
      {
        var is-add?/eax: boolean <- stream-data-equal? curr-text, "+"
        compare is-add?, 0
        break-if-=
        var _b/eax: int <- pop-int-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-stack out
        a <- add b
        push-int-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sub?/eax: boolean <- stream-data-equal? curr-text, "-"
        compare is-sub?, 0
        break-if-=
        var _b/eax: int <- pop-int-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-stack out
        a <- subtract b
        push-int-stack out, a
        break $evaluate:process-word
      }
      {
        var is-mul?/eax: boolean <- stream-data-equal? curr-text, "*"
        compare is-mul?, 0
        break-if-=
        var _b/eax: int <- pop-int-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-stack out
        a <- multiply b
        push-int-stack out, a
        break $evaluate:process-word
      }
      # otherwise it's an int
      {
        var n/eax: int <- parse-decimal-int-from-stream curr-text
        push-int-stack out, n
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

fn test-evaluate {
  # input = [1, 2, +]
  var w: (handle word)
  var wah/eax: (addr handle word) <- address w
  allocate wah
  var wa/eax: (addr word) <- lookup w
  initialize-word-with wa, "1"
  append-word-with w, "2"
  var next/ecx: (addr handle word) <- get wa, next
  append-word-with *next, "+"
  # initialize output
  var stack-storage: int-stack
  var stack/edx: (addr int-stack) <- address stack-storage
  initialize-int-stack stack, 0x10
  #
  evaluate wa, 0, stack
  # check output
  var x/eax: int <- pop-int-stack stack
  check-ints-equal x, 3, "F - test-evaluate"
}

# Copy of 'simplify' that just tracks the maximum stack depth needed
# Doesn't actually need to simulate the stack, since every word has a predictable effect.
fn max-stack-depth first-word: (addr word), final-word: (addr word) -> result/edi: int {
  var curr-word/eax: (addr word) <- copy first-word
  var curr-depth/ecx: int <- copy 0
  result <- copy 0
  $max-stack-depth:loop: {
    $max-stack-depth:process-word: {
      # handle operators
      {
        var is-add?/eax: boolean <- word-equal? curr-word, "+"
        compare is-add?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      {
        var is-sub?/eax: boolean <- word-equal? curr-word, "-"
        compare is-sub?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      {
        var is-mul?/eax: boolean <- word-equal? curr-word, "*"
        compare is-mul?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      # otherwise it's an int (do we need error-checking?)
      curr-depth <- increment
      # update max depth if necessary
      {
        compare curr-depth, result
        break-if-<=
        result <- copy curr-depth
      }
    }
    # if curr-word == final-word break
    compare curr-word, final-word
    break-if-=
    # curr-word = curr-word->next
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    #
    loop
  }
}
