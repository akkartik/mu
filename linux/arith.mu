# Integer arithmetic using conventional precedence.
#
# Follows part 2 of Jack Crenshaw's "Let's build a compiler!"
#   https://compilers.iecc.com/crenshaw
#
# Limitations:
#   No division yet.
#
# To build:
#   $ ./translate arith.mu
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

fn main -> _/ebx: int {
  enable-keyboard-immediate-mode
  var look/esi: grapheme <- copy 0  # lookahead
  var n/eax: int <- copy 0  # result of each expression
  print-string 0/screen, "press ctrl-c or ctrl-d to exit\n"
  # read-eval-print loop
  {
    # print prompt
    print-string 0/screen, "> "
    # read and eval
    n, look <- simplify  # we explicitly thread 'look' everywhere
    # if (look == 0) break
    compare look, 0
    break-if-=
    # print
    print-int32-decimal 0/screen, n
    print-string 0/screen, "\n"
    #
    loop
  }
  enable-keyboard-type-mode
  return 0
}

fn simplify -> _/eax: int, _/esi: grapheme {
  # prime the pump
  var look/esi: grapheme <- get-char
  # do it
  var result/eax: int <- copy 0
  result, look <- expression look
  return result, look
}

fn expression _look: grapheme -> _/eax: int, _/esi: grapheme {
  var look/esi: grapheme <- copy _look
  # read arg
  var result/eax: int <- copy 0
  result, look <- term look
  $expression:loop: {
    # while next non-space char in ['+', '-']
    look <- skip-spaces look
    {
      var continue?/eax: boolean <- add-or-sub? look
      compare continue?, 0/false
      break-if-= $expression:loop
    }
    # read operator
    var op/ecx: grapheme <- copy 0
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
        compare op, 0x2b/+
        break-if-!=
        result <- add second
        break $expression:perform-op
      }
      {
        compare op, 0x2d/minus
        break-if-!=
        result <- subtract second
        break $expression:perform-op
      }
    }
    loop
  }
  look <- skip-spaces look
  return result, look
}

fn term _look: grapheme -> _/eax: int, _/esi: grapheme {
  var look/esi: grapheme <- copy _look
  # read arg
  look <- skip-spaces look
  var result/eax: int <- copy 0
  result, look <- factor look
  $term:loop: {
    # while next non-space char in ['*', '/']
    look <- skip-spaces look
    {
      var continue?/eax: boolean <- mul-or-div? look
      compare continue?, 0/false
      break-if-= $term:loop
    }
    # read operator
    var op/ecx: grapheme <- copy 0
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
        compare op, 0x2a/*
        break-if-!=
        result <- multiply second
        break $term:perform-op
      }
#?       {
#?         compare op, 0x2f/slash
#?         break-if-!=
#?         result <- divide second  # not in Mu yet
#?         break $term:perform-op
#?       }
    }
    loop
  }
  return result, look
}

fn factor _look: grapheme -> _/eax: int, _/esi: grapheme {
  var look/esi: grapheme <- copy _look  # should be a no-op
  look <- skip-spaces look
  # if next char is not '(', parse a number
  compare look, 0x28/open-paren
  {
    break-if-=
    var result/eax: int <- copy 0
    result, look <- num look
    return result, look
  }
  # otherwise recurse
  look <- get-char  # '('
  var result/eax: int <- copy 0
  result, look <- expression look
  look <- skip-spaces look
  look <- get-char  # ')'
  return result, look
}

fn mul-or-div? c: grapheme -> _/eax: boolean {
  compare c, 0x2a/*
  {
    break-if-!=
    return 1/true
  }
  compare c, 0x2f/slash
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn add-or-sub? c: grapheme -> _/eax: boolean {
  compare c, 0x2b/+
  {
    break-if-!=
    return 1/true
  }
  compare c, 0x2d/minus
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn operator _look: grapheme -> _/ecx: grapheme, _/esi: grapheme {
  var op/ecx: grapheme <- copy _look
  var look/esi: grapheme <- get-char
  return op, look
}

fn num _look: grapheme -> _/eax: int, _/esi: grapheme {
  var look/esi: grapheme <- copy _look
  var result/edi: int <- copy 0
  {
    var first-digit/eax: int <- to-decimal-digit look
    result <- copy first-digit
  }
  {
    look <- get-char
    # done?
    var digit?/eax: boolean <- decimal-digit? look
    compare digit?, 0/false
    break-if-=
    # result *= 10
    {
      var ten/eax: int <- copy 0xa
      result <- multiply ten
    }
    # result += digit(look)
    var digit/eax: int <- to-decimal-digit look
    result <- add digit
    loop
  }
  return result, look
}

fn skip-spaces _look: grapheme -> _/esi: grapheme {
  var look/esi: grapheme <- copy _look  # should be a no-op
  {
    compare look, 0x20
    break-if-!=
    look <- get-char
    loop
  }
  return look
}

fn get-char -> _/esi: grapheme {
  var look/eax: grapheme <- read-key-from-real-keyboard
  print-grapheme-to-real-screen look
  compare look, 4
  {
    break-if-!=
    print-string 0/screen, "^D\n"
    syscall_exit
  }
  return look
}
