fn evaluate functions: (addr handle function), bindings: (addr table), scratch: (addr line), end: (addr word), out: (addr value-stack) {
  var line/eax: (addr line) <- copy scratch
  var word-ah/eax: (addr handle word) <- get line, data
  var curr/eax: (addr word) <- lookup *word-ah
  var curr-stream-storage: (stream byte 0x10)
  var curr-stream/edi: (addr stream byte) <- address curr-stream-storage
  clear-value-stack out
  $evaluate:loop: {
    # precondition (should never hit)
    compare curr, 0
    break-if-=
    # update curr-stream
    emit-word curr, curr-stream
#?     print-stream-to-real-screen curr-stream
#?     print-string-to-real-screen "\n"
    $evaluate:process-word: {
      # if curr-stream is an operator, perform it
      {
        var is-add?/eax: boolean <- stream-data-equal? curr-stream, "+"
        compare is-add?, 0
        break-if-=
        var _b/eax: int <- pop-int-from-value-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-from-value-stack out
        a <- add b
        push-int-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sub?/eax: boolean <- stream-data-equal? curr-stream, "-"
        compare is-sub?, 0
        break-if-=
        var _b/eax: int <- pop-int-from-value-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-from-value-stack out
        a <- subtract b
        push-int-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-mul?/eax: boolean <- stream-data-equal? curr-stream, "*"
        compare is-mul?, 0
        break-if-=
        var _b/eax: int <- pop-int-from-value-stack out
        var b/edx: int <- copy _b
        var a/eax: int <- pop-int-from-value-stack out
        a <- multiply b
        push-int-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-len?/eax: boolean <- stream-data-equal? curr-stream, "len"
        compare is-len?, 0
        break-if-=
#?         print-string 0, "is len\n"
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
#?         print-string 0, "stack has stuff\n"
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a string or array
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 1  # string
        {
          break-if-!=
          # compute length
          var src-ah/eax: (addr handle array byte) <- get target-val, text-data
          var src/eax: (addr array byte) <- lookup *src-ah
          var result/ebx: int <- length src
          # save result into target-val
          var type-addr/eax: (addr int) <- get target-val, type
          copy-to *type-addr, 0  # int
          var target-string-ah/eax: (addr handle array byte) <- get target-val, text-data
          var empty: (handle array byte)
          copy-handle empty, target-string-ah
          var target/eax: (addr int) <- get target-val, int-data
          copy-to *target, result
          break $evaluate:process-word
        }
        compare *target-type-addr, 2  # array of ints
        {
          break-if-!=
          # compute length
          var src-ah/eax: (addr handle array int) <- get target-val, array-data
          var src/eax: (addr array int) <- lookup *src-ah
          var result/ebx: int <- length src
          # save result into target-val
          var type-addr/eax: (addr int) <- get target-val, type
          copy-to *type-addr, 0  # int
          var target-array-ah/eax: (addr handle array int) <- get target-val, array-data
          var empty: (handle array int)
          copy-handle empty, target-array-ah
          var target/eax: (addr int) <- get target-val, int-data
          copy-to *target, result
          break $evaluate:process-word
        }
      }
      # if curr-stream defines a binding, save top of stack to bindings
      {
        var done?/eax: boolean <- stream-empty? curr-stream
        compare done?, 0  # false
        break-if-!=
        var new-byte/eax: byte <- read-byte curr-stream
        compare new-byte, 0x3d  # '='
        break-if-!=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # create binding from curr-stream to target-val
        var key-h: (handle array byte)
        var key/ecx: (addr handle array byte) <- address key-h
        stream-to-string curr-stream, key
        bind-in-table bindings, key, target-val
        # process next line if necessary
        var line/eax: (addr line) <- copy scratch
        var next-line-ah/eax: (addr handle line) <- get line, next
        var next-line/eax: (addr line) <- lookup *next-line-ah
        compare next-line, 0
        break-if-= $evaluate:process-word
        evaluate functions, bindings, next-line, end, out
        break $evaluate:process-word
      }
      rewind-stream curr-stream
      # if curr-stream is a known function name, call it appropriately
      {
        var callee-h: (handle function)
        var callee-ah/eax: (addr handle function) <- address callee-h
        find-function functions, curr-stream, callee-ah
        var callee/eax: (addr function) <- lookup *callee-ah
        compare callee, 0
        break-if-=
        perform-call callee, out, functions
        break $evaluate:process-word
      }
      # if it's a name, push its value
      {
        compare bindings, 0
        break-if-=
        var tmp: (handle array byte)
        var curr-string-ah/edx: (addr handle array byte) <- address tmp
        stream-to-string curr-stream, curr-string-ah  # unfortunate leak
        var curr-string/eax: (addr array byte) <- lookup *curr-string-ah
        var val-storage: (handle value)
        var val-ah/edi: (addr handle value) <- address val-storage
        lookup-binding bindings, curr-string, val-ah
        var val/eax: (addr value) <- lookup *val-ah
        compare val, 0
        break-if-=
        push-value-stack out, val
        break $evaluate:process-word
      }
      # if the word starts with a quote and ends with a quote, turn it into a string
      {
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x22  # double-quote
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x22  # double-quote
        break-if-!=
        var h: (handle array byte)
        var s/eax: (addr handle array byte) <- address h
        unquote-stream-to-string curr-stream, s  # leak
        push-string-to-value-stack out, *s
        break $evaluate:process-word
      }
      # if the word starts with a '[' and ends with a ']', turn it into an array
      {
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x5b  # '['
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x5d  # ']'
        break-if-!=
        # wastefully create a new string to strip quotes
        var h: (handle array int)
        var tmp-ah/eax: (addr handle array byte) <- address h
        unquote-stream-to-string curr-stream, tmp-ah  # leak
        var tmp/eax: (addr array byte) <- lookup *tmp-ah
        var h2: (handle array int)
        var array-ah/ecx: (addr handle array int) <- address h2
        parse-array-of-ints tmp, array-ah  # leak
        push-array-to-value-stack out, *array-ah
        break $evaluate:process-word
      }
      # otherwise assume it's a literal int and push it
      {
        var n/eax: int <- parse-decimal-int-from-stream curr-stream
        push-int-to-value-stack out, n
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
  var line-storage: line
  var line/esi: (addr line) <- address line-storage
  var first-word-ah/eax: (addr handle word) <- get line-storage, data
  allocate-word-with first-word-ah, "3"
  append-word-with *first-word-ah, "=a"
  var next-line-ah/eax: (addr handle line) <- get line-storage, next
  allocate next-line-ah
  var next-line/eax: (addr line) <- lookup *next-line-ah
  var first-word-ah/eax: (addr handle word) <- get next-line, data
  allocate-word-with first-word-ah, "a"
  var functions-storage: (handle function)
  var functions/ecx: (addr handle function) <- address functions-storage
  var table-storage: table
  var table/ebx: (addr table) <- address table-storage
  initialize-table table, 0x10
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  initialize-value-stack stack, 0x10
  evaluate functions, table, line, 0, stack
  var x/eax: int <- pop-int-from-value-stack stack
  check-ints-equal x, 3, "F - test-evaluate"
}

fn find-function first: (addr handle function), name: (addr stream byte), out: (addr handle function) {
  var curr/esi: (addr handle function) <- copy first
  $find-function:loop: {
    var _f/eax: (addr function) <- lookup *curr
    var f/ecx: (addr function) <- copy _f
    compare f, 0
    break-if-=
    var curr-name-ah/eax: (addr handle array byte) <- get f, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var done?/eax: boolean <- stream-data-equal? name, curr-name
    compare done?, 0  # false
    {
      break-if-=
      copy-handle *curr, out
      break $find-function:loop
    }
    curr <- get f, next
    loop
  }
}

fn perform-call _callee: (addr function), caller-stack: (addr value-stack), functions: (addr handle function) {
  var callee/ecx: (addr function) <- copy _callee
  # create bindings for args
  var table-storage: table
  var table/esi: (addr table) <- address table-storage
  initialize-table table, 0x10
  bind-args callee, caller-stack, table
  # obtain body
  var body-ah/eax: (addr handle line) <- get callee, body
  var body/eax: (addr line) <- lookup *body-ah
  # perform call
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  initialize-value-stack stack, 0x10
#?   print-string-to-real-screen "about to enter recursive eval\n"
  evaluate functions, table, body, 0, stack
#?   print-string-to-real-screen "exited recursive eval\n"
  # pop target-val from out
  var top-addr/ecx: (addr int) <- get stack, top
  compare *top-addr, 0
  break-if-<=
  var data-ah/eax: (addr handle array value) <- get stack, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  top <- decrement
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var target-val/edx: (addr value) <- index data, dest-offset
  # stitch target-val into caller-stack
  push-value-stack caller-stack, target-val
}

# pop args from the caller-stack and bind them to successive args
# implies: function args are stored in reverse order
fn bind-args _callee: (addr function), _caller-stack: (addr value-stack), table: (addr table) {
  var callee/ecx: (addr function) <- copy _callee
  var curr-arg-ah/eax: (addr handle word) <- get callee, args
  var curr-arg/eax: (addr word) <- lookup *curr-arg-ah
  #
  var curr-key-storage: (handle array byte)
  var curr-key/edx: (addr handle array byte) <- address curr-key-storage
  {
    compare curr-arg, 0
    break-if-=
    # create binding
    word-to-string curr-arg, curr-key
    {
      # pop target-val from caller-stack
      var caller-stack/esi: (addr value-stack) <- copy _caller-stack
      var top-addr/ecx: (addr int) <- get caller-stack, top
      compare *top-addr, 0
      break-if-<=
      decrement *top-addr
      var data-ah/eax: (addr handle array value) <- get caller-stack, data
      var data/eax: (addr array value) <- lookup *data-ah
      var top/ebx: int <- copy *top-addr
      var dest-offset/ebx: (offset value) <- compute-offset data, top
      var target-val/ebx: (addr value) <- index data, dest-offset
      # create binding from curr-key to target-val
      bind-in-table table, curr-key, target-val
    }
    #
    var next-arg-ah/edx: (addr handle word) <- get curr-arg, next
    curr-arg <- lookup *next-arg-ah
    loop
  }
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
