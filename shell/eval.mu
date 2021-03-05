# env is an alist of ((sym . val) (sym . val) ...)
fn evaluate _in: (addr handle cell), out: (addr handle cell), env: (addr cell), trace: (addr trace) {
  trace-text trace, "eval", "evaluate"
  trace-lower trace
  var in/eax: (addr handle cell) <- copy _in
  var in-addr/eax: (addr cell) <- lookup *in
  {
    var is-nil?/eax: boolean <- is-nil? in-addr
    compare is-nil?, 0/false
    break-if-=
    # nil is a literal
    copy-object _in, out
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in-addr, type
  compare *in-type, 1/number
  {
    break-if-!=
    # numbers are literals
    copy-object _in, out
    trace-higher trace
    return
  }
  compare *in-type, 2/symbol
  {
    break-if-!=
    lookup-symbol in-addr, out, env, trace
    trace-higher trace
    return
  }
  # TODO: pairs
  copy-object _in, out
  trace-higher trace
}

fn lookup-symbol sym: (addr cell), out: (addr handle cell), _env: (addr cell), trace: (addr trace) {
  # trace sym
  {
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "lookup "
    var sym2/eax: (addr cell) <- copy sym
    var sym-data-ah/eax: (addr handle stream byte) <- get sym2, text-data
    var sym-data/eax: (addr stream byte) <- lookup *sym-data-ah
    rewind-stream sym-data
    write-stream stream, sym-data
    trace trace, "eval", stream
  }
  trace-lower trace
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
  # if env is nil, abort
  {
    var env-is-nil?/eax: boolean <- is-nil? env
    compare env-is-nil?, 0/false
    break-if-=
    # error "unbound symbol: ", sym
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "unbound symbol: "
    var sym2/eax: (addr cell) <- copy sym
    var sym-data-ah/eax: (addr handle stream byte) <- get sym2, text-data
    var sym-data/eax: (addr stream byte) <- lookup *sym-data-ah
    rewind-stream sym-data
    write-stream stream, sym-data
    trace trace, "error", stream
    trace-higher trace
    return
  }
  # check car
  var env-head-storage: (handle cell)
  var env-head-ah/eax: (addr handle cell) <- address env-head-storage
  car env, env-head-ah, trace
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
    cdr env-head, out, trace
    trace-higher trace
    return
  }
  # otherwise recurse
  var env-tail-storage: (handle cell)
  var env-tail-ah/eax: (addr handle cell) <- address env-tail-storage
  cdr env, env-tail-ah, trace
  var env-tail/eax: (addr cell) <- lookup *env-tail-ah
  lookup-symbol sym, out, env-tail, trace
  trace-higher trace
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
    trace-text trace, "eval", "=> false (type)"
    trace-higher trace
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
      trace-text trace, "eval", "=> false (numbers)"
      trace-higher trace
      return 0/false
    }
    trace-text trace, "eval", "=> true (numbers)"
    trace-higher trace
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
    stream-to-array a-val, tmp-ah
    var tmp/eax: (addr array byte) <- lookup *tmp-ah
    var match?/eax: boolean <- stream-data-equal? b-val, tmp
    trace-text trace, "eval", "=> ? (symbols)"
    trace-higher trace
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
      trace-text trace, "eval", "=> true (nils)"
      trace-higher trace
      return 1/true
    }
    # a == nil => return false
    {
      compare a-is-nil?, 0/false
      break-if-=
      trace-text trace, "eval", "=> false (b != nil)"
      trace-higher trace
      return 0/false
    }
    # b == nil => return false
    {
      compare b-is-nil?, 0/false
      break-if-=
      trace-text trace, "eval", "=> false (a != nil)"
      trace-higher trace
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
    return 0/false
  }
  # recurse on cdrs
  cdr a, a-tmp-ah, trace
  cdr b, b-tmp-ah, trace
  var _a-tmp/eax: (addr cell) <- lookup *a-tmp-ah
  var a-tmp/ecx: (addr cell) <- copy _a-tmp
  var b-tmp/eax: (addr cell) <- lookup *b-tmp-ah
  var result/eax: boolean <- cell-isomorphic? a-tmp, b-tmp, trace
  return result
}

fn test-evaluate-is-well-behaved {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0/visible  # we don't use trace UI
  #
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  # eval sym(a), nil env
  allocate-pair tmp-ah
  var env/eax: (addr cell) <- lookup *tmp-ah
  new-symbol tmp-ah, "a"
  evaluate tmp-ah, tmp-ah, env, t
  # doesn't die
  check-trace-contains t, "error", "unbound symbol: a", "F - test-evaluate-is-well-behaved"
}

fn test-evaluate-number {
  var tmp-storage: (handle cell)
  var tmp-ah/edx: (addr handle cell) <- address tmp-storage
  # eval 3, nil env
  allocate-pair tmp-ah
  var env/eax: (addr cell) <- lookup *tmp-ah
  new-integer tmp-ah, 3
  evaluate tmp-ah, tmp-ah, env, 0/no-trace
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
  var tmp-storage: (handle cell)
  var tmp-ah/ebx: (addr handle cell) <- address tmp-storage
  new-pair tmp-ah, *key-ah, *val-ah
  # env = ((a . 3))
  var nil-storage: (handle cell)
  var nil-ah/ecx: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  new-pair tmp-ah, *tmp-ah, *nil-ah
  var env/eax: (addr cell) <- lookup *tmp-ah
  # eval sym(a), env
  new-symbol tmp-ah, "a"
  evaluate tmp-ah, tmp-ah, env, 0/no-trace
  var result/eax: (addr cell) <- lookup *tmp-ah
  var result-type/edx: (addr int) <- get result, type
  check-ints-equal *result-type, 1/number, "F - test-evaluate-symbol/0"
  var result-value-addr/eax: (addr float) <- get result, number-data
  var result-value/eax: int <- convert *result-value-addr
  check-ints-equal result-value, 3, "F - test-evaluate-symbol/1"
}
