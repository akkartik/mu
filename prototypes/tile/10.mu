# Moving around within a tree and creating children.
#
# To run (on Linux and x86):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu prototypes/tile/10.mu
#   $ ./a.elf
#
# Press 'c' to create new children for the root node, and keys to move:
#   'h': parent
#   'l': first child
#   'j': next sibling
#   'k': prev sibling

# To run unit tests:
#   $ ./a.elf test
fn main args-on-stack: (addr array addr array byte) -> exit-status/ebx: int {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
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

# - interactive loop

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
  var cursor-handle: (handle cell)
  var cursor/edi: (addr handle cell) <- address cursor-handle
  copy-handle root-handle, cursor
  enable-keyboard-immediate-mode
  var _root-addr/eax: (addr cell) <- lookup *root
  var root-addr/ecx: (addr cell) <- copy _root-addr
  var cursor-addr/eax: (addr cell) <- lookup *cursor
  render root-addr, cursor-addr
$main:loop: {
    # process key
    {
      var c/eax: byte <- read-key
      compare c, 4  # ctrl-d
      break-if-= $main:loop
      process c, root, cursor
    }
    # render tree
    var _root-addr/eax: (addr cell) <- lookup root-handle
    var root-addr/ecx: (addr cell) <- copy _root-addr
    var cursor-addr/eax: (addr cell) <- lookup *cursor
    render root-addr, cursor-addr
    loop
  }
  clear-screen 0
  enable-keyboard-type-mode
  exit-status <- copy 0
}

#######################################################
# Tree mutations
#######################################################

fn process c: byte, root: (addr handle cell), cursor: (addr handle cell) {
$process:body: {
  # if c == 'h' move cursor to its parent if possible
  {
    compare c, 0x68  # 'h'
    break-if-!=
    move-to-parent cursor
  }
  # if c == 'l' move cursor to its first child if possible
  {
    compare c, 0x6c  # 'l'
    break-if-!=
    move-to-child cursor
  }
  # if c == 'j' move cursor to its next sibling if possible
  {
    compare c, 0x6a  # 'j'
    break-if-!=
    move-to-next-sibling cursor
  }
  # if c == 'k' move cursor to its prev sibling if possible
  {
    compare c, 0x6b  # 'k'
    break-if-!=
    move-to-prev-sibling cursor
  }
  # if c == 'c' create a new child at the cursor
  {
    compare c, 0x63  # 'c'
    break-if-!=
    var cursor2/eax: (addr handle cell) <- copy cursor
    create-child *cursor2
  }
}
}

fn move-to-parent cursor: (addr handle cell) {
  var cursor2/eax: (addr handle cell) <- copy cursor
  var cursor3/eax: (addr cell) <- lookup *cursor2
  var parent/ecx: (addr handle cell) <- get cursor3, parent
  {
    var tmp/eax: (addr cell) <- lookup *parent
    compare tmp, 0
    break-if-=
    copy-handle *parent, cursor
  }
}

fn move-to-child cursor: (addr handle cell) {
  var cursor2/eax: (addr handle cell) <- copy cursor
  var cursor3/eax: (addr cell) <- lookup *cursor2
  var child/ecx: (addr handle cell) <- get cursor3, first-child
  {
    var tmp/eax: (addr cell) <- lookup *child
    compare tmp, 0
    break-if-=
    copy-handle *child, cursor
  }
}

fn move-to-next-sibling cursor: (addr handle cell) {
  var cursor2/eax: (addr handle cell) <- copy cursor
  var cursor3/eax: (addr cell) <- lookup *cursor2
  var sib/ecx: (addr handle cell) <- get cursor3, next-sibling
  {
    var tmp/eax: (addr cell) <- lookup *sib
    compare tmp, 0
    break-if-=
    copy-handle *sib, cursor
  }
}

fn move-to-prev-sibling cursor: (addr handle cell) {
  var cursor2/eax: (addr handle cell) <- copy cursor
  var cursor3/eax: (addr cell) <- lookup *cursor2
  var sib/ecx: (addr handle cell) <- get cursor3, prev-sibling
  {
    var tmp/eax: (addr cell) <- lookup *sib
    compare tmp, 0
    break-if-=
    copy-handle *sib, cursor
  }
}

fn create-child node: (handle cell) {
  var n/eax: (addr cell) <- lookup node
  var child/esi: (addr handle cell) <- get n, first-child
  var prev/edx: (addr handle cell) <- copy 0
  {
    var tmp/eax: (addr cell) <- lookup *child
    compare tmp, 0
    break-if-=
    prev <- copy child
    child <- get tmp, next-sibling
    loop
  }
  allocate child
  var child2/eax: (addr cell) <- lookup *child
  var dest/ecx: (addr handle cell) <- get child2, prev-sibling
  # child->prev-sibling = prev
  {
    compare prev, 0
    break-if-=
    copy-handle *prev, dest
  }
  # child->parent = node
  dest <- get child2, parent
  copy-handle node, dest
}

#######################################################
# Tree drawing
#######################################################

fn render root: (addr cell), cursor: (addr cell) {
  clear-screen 0
  var depth/eax: int <- tree-depth root
  var viewport-width/ecx: int <- copy 0x65  # col2
  viewport-width <- subtract 5  # col1
  var column-width/eax: int <- try-divide viewport-width, depth
  render-tree root, column-width, 5, 5, 0x20, 0x65, cursor
}

fn render-tree c: (addr cell), column-width: int, row-min: int, col-min: int, row-max: int, col-max: int, cursor: (addr cell) {
$render-tree:body: {
  var root-max/ecx: int <- copy col-min
  root-max <- add column-width
  draw-box row-min, col-min, row-max, root-max
  var c2/edx: (addr cell) <- copy c
  {
    compare c2, cursor
    break-if-!=
    draw-hatching row-min, col-min, row-max, root-max
  }
  # if single child, render it (slightly shorter than the parent)
  var nchild/eax: int <- num-children c
  {
    compare nchild, 1
    break-if->
    var child/edx: (addr handle cell) <- get c2, first-child
    var child-addr/eax: (addr cell) <- lookup *child
    {
      compare child-addr, 0
      break-if-=
      increment row-min
      decrement row-max
      render-tree child-addr, column-width, row-min, root-max, row-max, col-max, cursor
    }
    break $render-tree:body
  }
  # otherwise divide vertical space up equally among children
  var column-height/ebx: int <- copy row-max
  column-height <- subtract row-min
  var child-height/eax: int <- try-divide column-height, nchild
  var child-height2/ebx: int <- copy child-height
  var curr/edx: (addr handle cell) <- get c2, first-child
  var curr-addr/eax: (addr cell) <- lookup *curr
  var rmin/esi: int <- copy row-min
  var rmax/edi: int <- copy row-min
  rmax <- add child-height2
  {
    compare curr-addr, 0
    break-if-=
    render-tree curr-addr, column-width, rmin, root-max, rmax, col-max, cursor
    curr <- get curr-addr, next-sibling
    curr-addr <- lookup *curr
    rmin <- add child-height2
    rmax <- add child-height2
    loop
  }
}
}

fn num-children node-on-stack: (addr cell) -> result/eax: int {
  var tmp-result/edi: int <- copy 0
  var node/eax: (addr cell) <- copy node-on-stack
  var child/ecx: (addr handle cell) <- get node, first-child
  var child-addr/eax: (addr cell) <- lookup *child
  {
    compare child-addr, 0
    break-if-=
    tmp-result <- increment
    child <- get child-addr, next-sibling
    child-addr <- lookup *child
    loop
  }
  result <- copy tmp-result
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

fn draw-hatching row1: int, col1: int, row2: int, col2: int {
  var c/eax: int <- copy col1
  var r1/ecx: int <- copy row1
  r1 <- increment
  c <- add 2
  {
    compare c, col2
    break-if->=
    draw-vertical-line r1, row2, c
    c <- add 2
    loop
  }
}

fn draw-horizontal-line row: int, col1: int, col2: int {
  var col/eax: int <- copy col1
  move-cursor 0, row, col
  {
    compare col, col2
    break-if->=
    print-string 0, "-"
    col <- increment
    loop
  }
}

fn draw-vertical-line row1: int, row2: int, col: int {
  var row/eax: int <- copy row1
  {
    compare row, row2
    break-if->=
    move-cursor 0, row, col
    print-string 0, "|"
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
