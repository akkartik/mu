# Inserting and deleting in arrays.
#
# The primitives here just do the work of making space and compacting.

fn slide-up _a: (addr array int), start: int, end: int, target: int {
  var a/esi: (addr array int) <- copy _a
  var src-idx/ecx: int <- copy start
  var dest-idx/edx: int <- copy target
  # if start == target, nothing to do
  {
    compare src-idx, dest-idx
    break-if-!=
    return
  }
  # if start < target, abort
  {
    compare src-idx, dest-idx
    break-if->
    abort "slide-up: target > start; use slide-down instead"
  }
  # perform the copy
  {
    compare src-idx, end
    break-if->=
    var dest/ebx: (addr int) <- index a, dest-idx
    var src/eax: (addr int) <- index a, src-idx
    var val/eax: int <- copy *src
    copy-to *dest, val
    src-idx <- increment
    dest-idx <- increment
    loop
  }
}

fn slide-down _a: (addr array int), start: int, end: int, target: int {
  var a/esi: (addr array int) <- copy _a
  var src-idx/ecx: int <- copy end
  src-idx <- decrement
  var dest-idx/edx: int <- copy target
  dest-idx <- add end
  dest-idx <- subtract start
  dest-idx <- decrement
  # if start == target, nothing to do
  {
    compare src-idx, dest-idx
    break-if-!=
    return
  }
  # if start > target, abort
  {
    compare src-idx, dest-idx
    break-if-<
    abort "slide-down: target < start; use slide-down instead"
  }
  # perform the copy
  {
    compare src-idx, start
    break-if-<
    var dest/ebx: (addr int) <- index a, dest-idx
    var src/eax: (addr int) <- index a, src-idx
    var val/eax: int <- copy *src
    copy-to *dest, val
    src-idx <- decrement
    dest-idx <- decrement
    loop
  }
}

fn test-slide-up {
  check-slide-up "0 1 2 3 0", 1/start 1/end, 0/target, "0 1 2 3 0", "F - test-slide-up/empty-interval"
  check-slide-up "0 1 2 3 0", 1/start 2/end, 0/target, "1 1 2 3 0", "F - test-slide-up/single-non-overlapping"
  check-slide-up "0 0 0 1 2 3 0", 3/start 6/end, 0/target, "1 2 3 1 2 3 0", "F - test-slide-up/multiple-non-overlapping"
  check-slide-up "0 1 2 3 0", 1/start 4/end, 0/target, "1 2 3 3 0", "F - test-slide-up/overlapping"
}

fn test-slide-down {
  check-slide-down "0 1 2 3 0", 1/start 1/end, 4/target, "0 1 2 3 0", "F - test-slide-down/empty-interval"
  check-slide-down "0 1 2 3 0", 1/start 2/end, 4/target, "0 1 2 3 1", "F - test-slide-down/single-non-overlapping"
  check-slide-down "0 1 2 3 0 0 0", 1/start 4/end, 4/target, "0 1 2 3 1 2 3", "F - test-slide-down/multiple-non-overlapping"
  check-slide-down "0 1 2 3 0", 1/start 4/end, 2/target, "0 1 1 2 3", "F - test-slide-down/overlapping"
}

# helpers for tests
fn check-slide-up before: (addr array byte), start: int, end: int, target: int, after: (addr array byte), msg: (addr array byte) {
  var arr-h: (handle array int)
  var arr-ah/eax: (addr handle array int) <- address arr-h
  parse-array-of-decimal-ints before, arr-ah
  var arr/eax: (addr array int) <- lookup *arr-ah
  slide-up arr, start, end, target
  check-array-equal arr, after, msg
}

fn check-slide-down before: (addr array byte), start: int, end: int, target: int, after: (addr array byte), msg: (addr array byte) {
  var arr-h: (handle array int)
  var arr-ah/eax: (addr handle array int) <- address arr-h
  parse-array-of-decimal-ints before, arr-ah
  var arr/eax: (addr array int) <- lookup *arr-ah
  slide-down arr, start, end, target
  check-array-equal arr, after, msg
}
