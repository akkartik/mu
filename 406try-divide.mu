# slow, iterative divide instruction
# preconditions: _nr >= 0, _dr > 0
fn try-divide _nr: int, _dr: int -> result/eax: int {
  # x = next power-of-2 multiple of _dr after _nr
  var x/ecx: int <- copy 1
  {
#?     print-int32-hex 0, x
#?     print-string 0, "\n"
    var tmp/edx: int <- copy _dr
    tmp <- multiply x
    compare tmp, _nr
    break-if->
    x <- shift-left 1
    loop
  }
#?   print-string 0, "--\n"
  # min, max = x/2, x
  var max/ecx: int <- copy x
  var min/edx: int <- copy max
  min <- shift-right 1
  # narrow down result between min and max
  var i/eax: int <- copy min
  {
#?     print-int32-hex 0, i
#?     print-string 0, "\n"
    var foo/ebx: int <- copy _dr
    foo <- multiply i
    compare foo, _nr
    break-if->
    i <- increment
    loop
  }
  result <- copy i
  result <- decrement
#?   print-string 0, "=> "
#?   print-int32-hex 0, result
#?   print-string 0, "\n"
}

fn test-try-divide-1 {
  var result/eax: int <- try-divide 0, 2
  check-ints-equal result, 0, "F - try-divide-1\n"
}

fn test-try-divide-2 {
  var result/eax: int <- try-divide 1, 2
  check-ints-equal result, 0, "F - try-divide-2\n"
}

fn test-try-divide-3 {
  var result/eax: int <- try-divide 2, 2
  check-ints-equal result, 1, "F - try-divide-3\n"
}

fn test-try-divide-4 {
  var result/eax: int <- try-divide 4, 2
  check-ints-equal result, 2, "F - try-divide-4\n"
}

fn test-try-divide-5 {
  var result/eax: int <- try-divide 6, 2
  check-ints-equal result, 3, "F - try-divide-5\n"
}

fn test-try-divide-6 {
  var result/eax: int <- try-divide 9, 3
  check-ints-equal result, 3, "F - try-divide-6\n"
}

fn test-try-divide-7 {
  var result/eax: int <- try-divide 0xc, 4
  check-ints-equal result, 3, "F - try-divide-7\n"
}

fn test-try-divide-8 {
  var result/eax: int <- try-divide 0x1b, 3  # 27/3
  check-ints-equal result, 9, "F - try-divide-8\n"
}

fn test-try-divide-9 {
  var result/eax: int <- try-divide 0x1c, 3  # 28/3
  check-ints-equal result, 9, "F - try-divide-9\n"
}
