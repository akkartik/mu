# ./a.elf test => run tests
fn main args-on-stack: (addr array (addr array byte)) -> exit-status/ebx: int {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var tmp/ecx: int <- length args
  $main-body: {
    # if (len(args) > 1 && args[1] == "test") run-tests()
    compare tmp, 1
    {
      break-if-<=
      # if (args[1] == "test") run-tests()
      var tmp2/ecx: (addr addr array byte) <- index args, 1
      var tmp3/eax: boolean <- string-equal? *tmp2, "test"
      compare tmp3, 0
      {
        break-if-=
        run-tests
        exit-status <- copy 0  # TODO: get at Num-test-failures somehow
      }
      break $main-body
    }
    # otherwise operate interactively
    exit-status <- interactive
  }
}

# == interactive loop

type cell {
  val: int  # single chars only for now
  parent: (handle cell)
  first-child: (handle cell)
  next-sibling: (handle cell)
  prev-sibling: (handle cell)
}

fn interactive -> exit-status/ebx: int {
  var root-handle: (handle cell)
  var root/esi: (addr handle cell) <- address root-handle
  allocate root
  var cursor/edi: (addr handle cell) <- copy root
  enable-keyboard-immediate-mode
  var root-addr/eax: (addr cell) <- lookup *root
  render root-addr
$main:loop: {
    # process key
    {
      var c/eax: byte <- read-key
      compare c, 4  # ctrl-d
      break-if-= $main:loop
      process c, root, cursor
    }
    # render tree
    root-addr <- lookup root-handle
    render root-addr
    loop
  }
  clear-screen
  enable-keyboard-type-mode
  exit-status <- copy 0
}

#######################################################
# Tree mutations
#######################################################

fn process c: byte, root: (addr handle cell), cursor: (addr handle cell) {
  var c1/eax: (addr handle cell) <- copy cursor
  var c2/eax: (addr cell) <- lookup *c1
  create-child c2
}

fn create-child node: (addr cell) {
  var n/ecx: (addr cell) <- copy node
  var first-child/esi: (addr handle cell) <- get n, first-child
  allocate first-child
}

#######################################################
# Tree drawing
#######################################################

fn render root: (addr cell) {
  clear-screen
  var depth/eax: int <- tree-depth root
  var viewport-width/ecx: int <- copy 0x64  # col2
  viewport-width <- subtract 5  # col1
  var column-width/eax: int <- try-divide viewport-width, depth
  render-tree root, column-width, 5, 5, 0x20, 0x64
}

fn render-tree c: (addr cell), column-width: int, row-min: int, col-min: int, row-max: int, col-max: int {
  var root-max/ecx: int <- copy col-min
  root-max <- add column-width
  draw-box row-min, col-min, row-max, root-max
  var c2/eax: (addr cell) <- copy c
  var child/eax: (addr handle cell) <- get c2, first-child
  var child-addr/eax: (addr cell) <- lookup *child
  {
    compare child-addr, 0
    break-if-=
    increment row-min
    decrement row-max
    render-tree child-addr, column-width, row-min, root-max, row-max, col-max
  }
}

fn tree-depth node-on-stack: (addr cell) -> result/eax: int {
  var tmp-result/edi: int <- copy 0
  var node/eax: (addr cell) <- copy node-on-stack
  var child/ecx: (addr handle cell) <- get node, first-child
  var child-addr/eax: (addr cell) <- lookup *child
  {
    compare child-addr, 0
    break-if-=
    {
      var tmp/eax: int <- tree-depth child-addr
      compare tmp, tmp-result
      break-if-<=
      tmp-result <- copy tmp
    }
    child <- get child-addr, next-sibling
    child-addr <- lookup *child
    loop
  }
  result <- copy tmp-result
  result <- increment
}

fn draw-box row1: int, col1: int, row2: int, col2: int {
  draw-horizontal-line row1, col1, col2
  draw-vertical-line row1, row2, col1
  draw-horizontal-line row2, col1, col2
  draw-vertical-line row1, row2, col2
}

fn draw-horizontal-line row: int, col1: int, col2: int {
  var col/eax: int <- copy col1
  move-cursor-on-screen row, col
  {
    compare col, col2
    break-if->=
    print-string-to-screen "-"
    col <- increment
    loop
  }
}

fn draw-vertical-line row1: int, row2: int, col: int {
  var row/eax: int <- copy row1
  {
    compare row, row2
    break-if->=
    move-cursor-on-screen row, col
    print-string-to-screen "|"
    row <- increment
    loop
  }
}

# slow, iterative divide instruction
# preconditions: _nr >= 0, _dr > 0
fn try-divide _nr: int, _dr: int -> result/eax: int {
  # x = next power-of-2 multiple of _dr after _nr
  var x/ecx: int <- copy 1
  {
#?     print-int32-hex-to-screen x
#?     print-string-to-screen "\n"
    var tmp/edx: int <- copy _dr
    tmp <- multiply x
    compare tmp, _nr
    break-if->
    x <- shift-left 1
    loop
  }
#?   print-string-to-screen "--\n"
  # min, max = x/2, x
  var max/ecx: int <- copy x
  var min/edx: int <- copy max
  min <- shift-right 1
  # narrow down result between min and max
  var i/eax: int <- copy min
  {
#?     print-int32-hex-to-screen i
#?     print-string-to-screen "\n"
    var foo/ebx: int <- copy _dr
    foo <- multiply i
    compare foo, _nr
    break-if->
    i <- increment
    loop
  }
  result <- copy i
  result <- decrement
#?   print-string-to-screen "=> "
#?   print-int32-hex-to-screen result
#?   print-string-to-screen "\n"
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
