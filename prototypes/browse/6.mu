fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/eax: (addr buffered-file) <- load-file filename
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  {
    render file, 0x20, 0x30  # nrows, ncols
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

fn render in: (addr buffered-file), nrows: int, ncols: int {
  # hardcoded parameter: page-width
  var toprow/eax: int <- copy 2
  var botrow/ecx: int <- copy toprow
  botrow <- add nrows
  var leftcol/edx: int <- copy 5
  var rightcol/ebx: int <- copy leftcol
  rightcol <- add ncols
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

fn load-file filename: (addr array byte) -> out/eax: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  out <- lookup result
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte c
  loop
}
