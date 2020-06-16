fn main -> exit-status/ebx: int {
  var look/esi: byte <- copy 0  # lookahead
  var n/eax: int <- copy 0  # result of each expression
  # read-eval-print loop
  {
    # print prompt
    print-string "> "
    # read and eval
    n, look <- simplify
    # if (look == 0) break
    compare look, 0
    break-if-=
    # print
    print-int32-to-screen n
    print-string "\n"
    #
    loop
  }
  exit-status <- copy 0
}

fn simplify -> result/eax: int, look/esi: byte {
  # prime the pump
  look <- get-char  # prime the pump
  look <- skip-spaces look
  result, look <- term look
  $simplify:loop: {
    # operator
    var op/ecx: byte <- copy 0
    look <- skip-spaces look
    compare look, 0
    break-if-=
    compare look, 0xa
    break-if-=
    op, look <- operator look
    # second arg
    var second/edx: int <- copy 0
    look <- skip-spaces look
    {
      var tmp/eax: int <- copy 0
      tmp, look <- term look
      second <- copy tmp
    }
    # perform op
    $simplify:perform-op: {
      {
        compare op, 0x2b  # '+'
        break-if-!=
        result <- add second
        break $simplify:perform-op
      }
      {
        compare op, 0x2d  # '-'
        break-if-!=
        result <- subtract second
        break $simplify:perform-op
      }
    }
    loop
  }
  look <- skip-spaces look
}

fn term _look: byte -> result/eax: int, look/esi: byte {
  look <- copy _look  # should be a no-op
  look <- skip-spaces look
  result, look <- num look
  $term:loop: {
    # operator
    var op/ecx: byte <- copy 0
    look <- skip-spaces look
    compare look, 0
    break-if-=
    compare look, 0xa
    break-if-=
    {
      var continue?/eax: boolean <- is-mul-or-div? look
      compare continue?, 0  # false
      break-if-= $term:loop
    }
    op, look <- operator look
    # second arg
    var second/edx: int <- copy 0
    look <- skip-spaces look
    {
      var tmp/eax: int <- copy 0
      tmp, look <- num look
      second <- copy tmp
    }
    # perform op
    $term:perform-op: {
      {
        compare op, 0x2a  # '*'
        break-if-!=
        result <- multiply second
        break $term:perform-op
      }
#?       {
#?         compare op, 0x2f  # '/'
#?         break-if-!=
#?         result <- divide second  # not in Mu yet
#?         break $term:perform-op
#?       }
    }
    loop
  }
}

fn is-mul-or-div? c: byte -> result/eax: bool {
$is-mul-or-div?:body: {
  compare c, 0x2a
  {
    break-if-!=
    result <- copy 1  # true
    break $is-mul-or-div?:body
  }
  result <- copy 0  # false
}  # $is-mul-or-div?:body
}

fn operator _look: byte -> op/ecx: byte, look/esi: byte {
  op <- copy _look
  look <- get-char
}

fn num _look: byte -> result/eax: int, look/esi: byte {
  look <- copy _look  # should be a no-op; guaranteed to be a digit
  var out/edi: int <- copy 0
  {
    var first-digit/eax: int <- to-decimal-digit look
    out <- copy first-digit
  }
  {
    look <- get-char
    # done?
    var digit?/eax: bool <- is-decimal-digit? look
    compare digit?, 0  # false
    break-if-=
    # out *= 10
    {
      var ten/eax: int <- copy 0xa
      out <- multiply ten
    }
    # out += digit(look)
    var digit/eax: int <- to-decimal-digit look
    out <- add digit
    loop
  }
  result <- copy out
}

fn skip-spaces _look: byte -> look/esi: byte {
  look <- copy _look  # should be a no-op
  {
    compare look, 0x20
    break-if-!=
    look <- get-char
    loop
  }
}

fn get-char -> look/esi: byte {
  var tmp/eax: byte <- read-key
  look <- copy tmp
  compare look, 0
  {
    break-if-!=
    print-string "^D\n"
    syscall_exit
  }
}
