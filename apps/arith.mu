# Integer arithmetic using conventional precedence.
#
# Follows part 2 of Jack Crenshaw's "Let's build a compiler!"
#   https://compilers.iecc.com/crenshaw
#
# Limitations:
#   No division yet.
#
# To build:
#   $ ./translate_mu apps/arith.mu
#
# Example session:
#   $ ./a.elf
#   press ctrl-c or ctrl-d to exit
#   > 1
#   1
#   > 1+1
#   2
#   > 1 + 1
#   2
#   > 1+2 +3
#   6
#   > 1+2 *3
#   7
#   > (1+2) *3
#   9
#   > 1 + 3*4
#   13
#   > ^D
#   $
#
# Error handling is non-existent. This is just a prototype.

fn main -> exit-status/ebx: int {
  var look/esi: byte <- copy 0  # lookahead
  var n/eax: int <- copy 0  # result of each expression
  print-string 0, "press ctrl-c or ctrl-d to exit\n"
  # read-eval-print loop
  {
    # print prompt
    print-string 0, "> "
    # read and eval
    n, look <- simplify  # we explicitly thread 'look' everywhere
    # if (look == 0) break
    compare look, 0
    break-if-=
    # print
    print-int32-decimal 0, n
    print-string 0, "\n"
    #
    loop
  }
  exit-status <- copy 0
}

fn simplify -> result/eax: int, look/esi: byte {
  # prime the pump
  look <- get-char
  # do it
  result, look <- expression look
}

fn expression _look: byte -> result/eax: int, look/esi: byte {
  look <- copy _look  # should be a no-op
  # read arg
  result, look <- term look
  $expression:loop: {
    # while next non-space char in ['+', '-']
    look <- skip-spaces look
    {
      var continue?/eax: boolean <- is-add-or-sub? look
      compare continue?, 0  # false
      break-if-= $expression:loop
    }
    # read operator
    var op/ecx: byte <- copy 0
    op, look <- operator look
    # read next arg
    var second/edx: int <- copy 0
    look <- skip-spaces look
    {
      var tmp/eax: int <- copy 0
      tmp, look <- term look
      second <- copy tmp
    }
    # reduce
    $expression:perform-op: {
      {
        compare op, 0x2b  # '+'
        break-if-!=
        result <- add second
        break $expression:perform-op
      }
      {
        compare op, 0x2d  # '-'
        break-if-!=
        result <- subtract second
        break $expression:perform-op
      }
    }
    loop
  }
  look <- skip-spaces look
}

fn term _look: byte -> result/eax: int, look/esi: byte {
  look <- copy _look  # should be a no-op
  # read arg
  look <- skip-spaces look
  result, look <- factor look
  $term:loop: {
    # while next non-space char in ['*', '/']
    look <- skip-spaces look
    {
      var continue?/eax: boolean <- is-mul-or-div? look
      compare continue?, 0  # false
      break-if-= $term:loop
    }
    # read operator
    var op/ecx: byte <- copy 0
    op, look <- operator look
    # read next arg
    var second/edx: int <- copy 0
    look <- skip-spaces look
    {
      var tmp/eax: int <- copy 0
      tmp, look <- factor look
      second <- copy tmp
    }
    # reduce
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

fn factor _look: byte -> result/eax: int, look/esi: byte {
$factor:body: {
  look <- copy _look  # should be a no-op
  look <- skip-spaces look
  # if next char is not '(', parse a number
  compare look, 0x28  # '('
  {
    break-if-=
    result, look <- num look
    break $factor:body
  }
  # otherwise recurse
  look <- get-char  # '('
  result, look <- expression look
  look <- skip-spaces look
  look <- get-char  # ')'
}  # $factor:body
}

fn is-mul-or-div? c: byte -> result/eax: boolean {
$is-mul-or-div?:body: {
  compare c, 0x2a  # '*'
  {
    break-if-!=
    result <- copy 1  # true
    break $is-mul-or-div?:body
  }
  compare c, 0x2f  # '/'
  {
    break-if-!=
    result <- copy 1  # true
    break $is-mul-or-div?:body
  }
  result <- copy 0  # false
}  # $is-mul-or-div?:body
}

fn is-add-or-sub? c: byte -> result/eax: boolean {
$is-add-or-sub?:body: {
  compare c, 0x2b  # '+'
  {
    break-if-!=
    result <- copy 1  # true
    break $is-add-or-sub?:body
  }
  compare c, 0x2d  # '-'
  {
    break-if-!=
    result <- copy 1  # true
    break $is-add-or-sub?:body
  }
  result <- copy 0  # false
}  # $is-add-or-sub?:body
}

fn operator _look: byte -> op/ecx: byte, look/esi: byte {
  op <- copy _look
  look <- get-char
}

fn num _look: byte -> result/eax: int, look/esi: byte {
  look <- copy _look  # should be a no-op
  var out/edi: int <- copy 0
  {
    var first-digit/eax: int <- to-decimal-digit look
    out <- copy first-digit
  }
  {
    look <- get-char
    # done?
    var digit?/eax: boolean <- is-decimal-digit? look
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
  var tmp/eax: byte <- read-key-from-real-keyboard
  look <- copy tmp
  compare look, 0
  {
    break-if-!=
    print-string 0, "^D\n"
    syscall_exit
  }
}
