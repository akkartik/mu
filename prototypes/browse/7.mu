fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/esi: (addr buffered-file) <- load-file filename
  enable-screen-grid-mode
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  enable-keyboard-immediate-mode
  {
    render file, nrows, ncols
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

# decide how to lay out pages on screen
fn render in: (addr buffered-file), nrows: int, ncols: int {
  # hardcoded parameter: page-width
  var toprow/eax: int <- copy 2
  var botrow/ecx: int <- copy toprow
  botrow <- add 0x20
  var leftcol/edx: int <- copy 5
  var rightcol/ebx: int <- copy leftcol
  rightcol <- add 0x30
  render-page in, toprow, leftcol, botrow, rightcol
}

fn render-page in: (addr buffered-file), toprow: int, leftcol: int, botrow: int, rightcol: int {
  clear toprow, leftcol, botrow, rightcol
  var row/ecx: int <- copy toprow
$line-loop:  {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor row, col
    {
      compare col, rightcol
      break-if->=
      var c/eax: byte <- read-byte-buffered in
      compare c, 0xffffffff  # EOF marker
      break-if-= $line-loop
      compare c, 0xa  # newline
      break-if-=  # no need to print newlines
      # print c
      print-byte c
      col <- increment
      loop
    }  # $char-loop
    row <- increment
    loop
  }  # $line-loop
}

fn clear toprow: int, leftcol: int, botrow: int, rightcol: int {
  var row/ecx: int <- copy toprow
  {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor row, col
    {
      compare col, rightcol
      break-if->=
      print-string " "
      col <- increment
      loop
    }
    row <- increment
    loop
  }
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

fn load-file filename: (addr array byte) -> out/esi: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  var tmp2/eax: (addr buffered-file) <- lookup result
  out <- copy tmp2
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte c
  loop
}
