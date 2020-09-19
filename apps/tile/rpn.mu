fn simplify in: (addr stream byte), out: (addr int-stack) {
  var word-storage: slice
  var word/ecx: (addr slice) <- address word-storage
  clear-int-stack out
  $simplify:word-loop: {
    next-word in, word
    var done?/eax: boolean <- slice-empty? word
    compare done?, 0
    break-if-!=
    # if word is an operator, perform it
    {
      var is-add?/eax: boolean <- slice-equal? word, "+"
      compare is-add?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack out
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack out
      a <- add b
      push-int-stack out, a
      loop $simplify:word-loop
    }
    {
      var is-sub?/eax: boolean <- slice-equal? word, "-"
      compare is-sub?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack out
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack out
      a <- subtract b
      push-int-stack out, a
      loop $simplify:word-loop
    }
    {
      var is-mul?/eax: boolean <- slice-equal? word, "*"
      compare is-mul?, 0
      break-if-=
      var _b/eax: int <- pop-int-stack out
      var b/edx: int <- copy _b
      var a/eax: int <- pop-int-stack out
      a <- multiply b
      push-int-stack out, a
      loop $simplify:word-loop
    }
    # otherwise it's an int
    var n/eax: int <- parse-decimal-int-from-slice word
    push-int-stack out, n
    loop
  }
}

# Copy of 'simplify' that just tracks the maximum stack depth needed
# Doesn't actually need to simulate the stack, since every word has a predictable effect.
fn max-stack-depth first-word: (addr word), final-word: (addr word) -> result/edi: int {
  var curr-word/eax: (addr word) <- copy first-word
  var curr-depth/ecx: int <- copy 0
  result <- copy 0
  $max-stack-depth:word-loop: {
    # handle operators
    {
      var is-add?/eax: boolean <- word-equal? curr-word, "+"
      compare is-add?, 0
      break-if-=
      curr-depth <- decrement
      loop $max-stack-depth:word-loop
    }
    {
      var is-sub?/eax: boolean <- word-equal? curr-word, "-"
      compare is-sub?, 0
      break-if-=
      curr-depth <- decrement
      loop $max-stack-depth:word-loop
    }
    {
      var is-mul?/eax: boolean <- word-equal? curr-word, "*"
      compare is-mul?, 0
      break-if-=
      curr-depth <- decrement
      loop $max-stack-depth:word-loop
    }
    # otherwise it's an int (do we need error-checking?)
    curr-depth <- increment
    # update max depth if necessary
    {
      compare curr-depth, result
      break-if-<=
      result <- copy curr-depth
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
