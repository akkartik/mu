# env is an alist of ((sym . val) (sym . val) ...)
# we never modify `in` or `env`
fn evaluate _in: (addr handle cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  var in/esi: (addr handle cell) <- copy _in
  # trace "evaluate " in " in environment " env {{{
  {
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "evaluate "
    print-cell in, stream, 0/no-trace
    write stream, " in environment "
    var env-ah/eax: (addr handle cell) <- address env-h
    print-cell env-ah, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
  trace-lower trace
  var in-addr/eax: (addr cell) <- lookup *in
  {
    var is-nil?/eax: boolean <- is-nil? in-addr
    compare is-nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "eval", "nil"
    copy-object _in, out
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in-addr, type
  compare *in-type, 1/number
  {
    break-if-!=
    # numbers are literals
    trace-text trace, "eval", "number"
    copy-object _in, out
    trace-higher trace
    return
  }
  compare *in-type, 2/symbol
  {
    break-if-!=
    trace-text trace, "eval", "symbol"
    lookup-symbol in-addr, out, env-h, trace
    trace-higher trace
    return
  }
  # in-addr is a syntax tree
  $evaluate:anonymous-function: {
    # trees starting with "fn" are anonymous functions and therefore literals
    var expr/esi: (addr cell) <- copy in-addr
    # if its first elem is not "fn", break
    var first-ah/ecx: (addr handle cell) <- get in-addr, left
    var first/eax: (addr cell) <- lookup *first-ah
    var is-fn?/eax: boolean <- is-fn? first
    compare is-fn?, 0/false
    break-if-=
    #
    trace-text trace, "eval", "anonymous function"
    copy-object _in, out
    trace-higher trace
    return
  }
  trace-text trace, "eval", "function call"
  trace-text trace, "eval", "evaluating list elements"
  var evaluated-list-storage: (handle cell)
  var evaluated-list-ah/esi: (addr handle cell) <- address evaluated-list-storage
  var curr-out-ah/edx: (addr handle cell) <- copy evaluated-list-ah
  var curr/ecx: (addr cell) <- copy in-addr
  $evaluate-list:loop: {
    allocate-pair curr-out-ah
    var is-nil?/eax: boolean <- is-nil? curr
    compare is-nil?, 0/false
    break-if-!=
    # eval left
    var curr-out/eax: (addr cell) <- lookup *curr-out-ah
    var left-out-ah/edi: (addr handle cell) <- get curr-out, left
    var left-ah/esi: (addr handle cell) <- get curr, left
    evaluate left-ah, left-out-ah, env-h, trace
    #
    curr-out-ah <- get curr-out, right
    var right-ah/eax: (addr handle cell) <- get curr, right
    var right/eax: (addr cell) <- lookup *right-ah
    curr <- copy right
    loop
  }
  var evaluated-list/eax: (addr cell) <- lookup *evaluated-list-ah
  var function-ah/ecx: (addr handle cell) <- get evaluated-list, left
  var args-ah/edx: (addr handle cell) <- get evaluated-list, right
#?   dump-cell args-ah
#?   abort "aaa"
  apply function-ah, args-ah, out, env-h, trace
  trace-higher trace
  # trace "=> " out {{{
  {
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> "
    print-cell out, stream, 0/no-trace
    trace trace, "eval", stream
  }
  # }}}
}

fn apply _f-ah: (addr handle cell), args-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  var f-ah/eax: (addr handle cell) <- copy _f-ah
  var _f/eax: (addr cell) <- lookup *f-ah
  var f/esi: (addr cell) <- copy _f
  # call primitive functions
  {
    var f-type/eax: (addr int) <- get f, type
    compare *f-type, 4/primitive-function
    break-if-!=
    apply-primitive f, args-ah, out, env-h, trace
    return
  }
  # if it's not a primitive function it must be an anonymous function
  # trace "apply anonymous function " f " in environment " env {{{
  {
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "apply anonymous function "
    print-cell _f-ah, stream, 0/no-trace
    write stream, " in environment "
    var env-ah/eax: (addr handle cell) <- address env-h
    print-cell env-ah, stream, 0/no-trace
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
    var is-fn?/eax: boolean <- is-fn? first
    compare is-fn?, 0/false
    break-if-=
    var rest-ah/esi: (addr handle cell) <- get f, right
    var rest/eax: (addr cell) <- lookup *rest-ah
    var params-ah/ecx: (addr handle cell) <- get rest, left
    var body-ah/eax: (addr handle cell) <- get rest, right
    apply-function params-ah, args-ah, body-ah, out, env-h, trace
    trace-higher trace
    return
  }
  error trace, "unknown function"
}

fn apply-function params-ah: (addr handle cell), args-ah: (addr handle cell), _body-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  # push bindings for params to env
  var new-env-storage: (handle cell)
  var new-env-ah/esi: (addr handle cell) <- address new-env-storage
  push-bindings params-ah, args-ah, env-h, new-env-ah, trace
  # eval all expressions in body, writing result to `out` each time
  var body-ah/ecx: (addr handle cell) <- copy _body-ah
  $apply-function:body: {
    var body/eax: (addr cell) <- lookup *body-ah
    # stop when body is nil
    {
      var body-is-nil?/eax: boolean <- is-nil? body
      compare body-is-nil?, 0/false
      break-if-!= $apply-function:body
    }
    # evaluate each expression, writing result to `out`
    {
      var curr-ah/eax: (addr handle cell) <- get body, left
      evaluate curr-ah, out, *new-env-ah, trace
    }
    #
    body-ah <- get body, right
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
    var params-is-nil?/eax: boolean <- is-nil? params
    compare params-is-nil?, 0/false
    break-if-=
    # nil is a literal
    trace-text trace, "eval", "done with push-bindings"
    copy-handle old-env-h, env-ah
    return
  }
  # Params can only be symbols or pairs. Args can be anything.
  # trace "pushing bindings from " params " to " args {{{
  {
    var stream-storage: (stream byte 0x40)
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

fn apply-primitive _f: (addr cell), args-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  var f/esi: (addr cell) <- copy _f
  var f-index/eax: (addr int) <- get f, index-data
  {
    compare *f-index, 1/add
    break-if-!=
    apply-add args-ah, out, env-h, trace
    return
  }
  abort "unknown primitive function"
}

fn apply-add _args-ah: (addr handle cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  trace-text trace, "eval", "apply +"
  var args-ah/eax: (addr handle cell) <- copy _args-ah
  var _args/eax: (addr cell) <- lookup *args-ah
  var args/esi: (addr cell) <- copy _args
  var _env/eax: (addr cell) <- lookup env-h
  var env/edi: (addr cell) <- copy _env
  # TODO: check that args is a pair
  var empty-args?/eax: boolean <- is-nil? args
  compare empty-args?, 0/false
  {
    break-if-=
    error trace, "+ needs 2 args but got 0"
    return
  }
  # args->left->value
  var first-ah/eax: (addr handle cell) <- get args, left
  var first/eax: (addr cell) <- lookup *first-ah
  var first-type/ecx: (addr int) <- get first, type
  compare *first-type, 1/number
  {
    break-if-=
    error trace, "first arg for + is not a number"
    return
  }
  var first-value/ecx: (addr float) <- get first, number-data
  # args->right->left->value
  var right-ah/eax: (addr handle cell) <- get args, right
#?   dump-cell right-ah
#?   abort "aaa"
  var right/eax: (addr cell) <- lookup *right-ah
  # TODO: check that right is a pair
  var second-ah/eax: (addr handle cell) <- get right, left
  var second/eax: (addr cell) <- lookup *second-ah
  var second-type/edx: (addr int) <- get second, type
  compare *second-type, 1/number
  {
    break-if-=
    error trace, "second arg for + is not a number"
    return
  }
  var second-value/edx: (addr float) <- get second, number-data
  # add
  var result/xmm0: float <- copy *first-value
  result <- add *second-value
  new-float out, result
}

fn lookup-symbol sym: (addr cell), out: (addr handle cell), env-h: (handle cell), trace: (addr trace) {
  # trace sym
  {
    var stream-storage: (stream byte 0x40)
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
    var env-is-nil?/eax: boolean <- is-nil? env
    compare env-is-nil?, 0/false
    break-if-=
    lookup-symbol-in-hardcoded-globals sym, out, trace
    trace-higher trace
    # trace "=> " out " (global)" {{{
    {
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x40)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell out, stream, 0/no-trace
      write stream, " (global)"
      trace trace, "eval", stream
    }
    # }}}
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
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x40)
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
  lookup-symbol sym, out, *env-tail-ah, trace
  trace-higher trace
    # trace "=> " out " (recurse)" {{{
    {
      var error?/eax: boolean <- has-errors? trace
      compare error?, 0/false
      break-if-!=
      var stream-storage: (stream byte 0x40)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> "
      print-cell out, stream, 0/no-trace
      write stream, " (recurse)"
      trace trace, "eval", stream
    }
    # }}}
}

fn lookup-symbol-in-hardcoded-globals _sym: (addr cell), out: (addr handle cell), trace: (addr trace) {
  var sym/eax: (addr cell) <- copy _sym
  var sym-data-ah/eax: (addr handle stream byte) <- get sym, text-data
  var _sym-data/eax: (addr stream byte) <- lookup *sym-data-ah
  var sym-data/esi: (addr stream byte) <- copy _sym-data
  {
    var is-add?/eax: boolean <- stream-data-equal? sym-data, "+"
    compare is-add?, 0/false
    break-if-=
    new-primitive-function out, 1/add
    trace-text trace, "eval", "global +"
    return
  }
  # otherwise error "unbound symbol: ", sym
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "unbound symbol: "
  rewind-stream sym-data
  write-stream stream, sym-data
  trace trace, "error", stream
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
  lookup-symbol in, tmp-ah, *env-ah, 0/no-trace
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-lookup-symbol-in-env/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-lookup-symbol-in-env/1"
}

fn test-lookup-symbol-in-hardcoded-globals {
  # env = nil
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  # lookup sym(a), env
  var tmp-storage: (handle cell)
  var tmp-ah/ebx: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "+"
  var in/eax: (addr cell) <- lookup *tmp-ah
  lookup-symbol in, tmp-ah, *nil-ah, 0/no-trace
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 4/primitive-function, "F - test-lookup-symbol-in-hardcoded-globals/0"
  var result-value/eax: (addr int) <- get result, index-data
  check-ints-equal *result-value, 1/add, "F - test-lookup-symbol-in-hardcoded-globals/1"
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
    var in-is-nil?/eax: boolean <- is-nil? in
    compare in-is-nil?, 0/false
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
    var in-is-nil?/eax: boolean <- is-nil? in
    compare in-is-nil?, 0/false
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
  compare b-type, 2/symbol
  {
    break-if-!=
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
  # if a is nil, b should be nil
  {
    # (assumes is-nil? returns 0 or 1)
    var _b-is-nil?/eax: boolean <- is-nil? b
    var b-is-nil?/ecx: boolean <- copy _b-is-nil?
    var a-is-nil?/eax: boolean <- is-nil? a
    # a == nil and b == nil => return true
    {
      compare a-is-nil?, 0/false
      break-if-=
      compare b-is-nil?, 0/false
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> true (nils)"
      return 1/true
    }
    # a == nil => return false
    {
      compare a-is-nil?, 0/false
      break-if-=
      trace-higher trace
      trace-text trace, "eval", "=> false (b != nil)"
      return 0/false
    }
    # b == nil => return false
    {
      compare b-is-nil?, 0/false
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

fn is-fn? _x: (addr cell) -> _/eax: boolean {
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
  evaluate tmp-ah, tmp-ah, *env-ah, t
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
  evaluate tmp-ah, tmp-ah, *env-ah, 0/no-trace
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
  evaluate tmp-ah, tmp-ah, *env-ah, 0/no-trace
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-symbol/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-evaluate-symbol/1"
}

fn test-evaluate-primitive-function {
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var add-storage: (handle cell)
  var add-ah/ebx: (addr handle cell) <- address add-storage
  new-symbol add-ah, "+"
  # eval +, nil env
  var tmp-storage: (handle cell)
  var tmp-ah/esi: (addr handle cell) <- address tmp-storage
  evaluate add-ah, tmp-ah, *nil-ah, 0/no-trace
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
  # eval (+ 1 1), nil env
  var tmp-storage: (handle cell)
  var tmp-ah/esi: (addr handle cell) <- address tmp-storage
  new-pair tmp-ah, *one-ah, *nil-ah
  new-pair tmp-ah, *one-ah, *tmp-ah
  new-pair tmp-ah, *add-ah, *tmp-ah
#?   dump-cell tmp-ah
  evaluate tmp-ah, tmp-ah, *nil-ah, t
#?   dump-trace t
  #
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-primitive-function-call/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 2, "F - test-evaluate-primitive-function-call/1"
}
