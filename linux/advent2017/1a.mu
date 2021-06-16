# Advent of code 2017, problem 1a
#   https://adventofcode.com/2017/day/1
#
# Mu solution by Sumeet Agarwal and Kartik Agaram
#   https://archive.org/details/2021-06-02-akkartik-sumeet
#
# To build on Linux:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu/linux
#   $ ./translate advent2017/1a.mu            # emits a.elf
# To run on Linux:
#   Download https://adventofcode.com/2017/day/1/input
#   $ ./a.elf < input
# Type in the number returned at https://adventofcode.com/2017/day/1

fn main -> _/ebx: int {
  var input_stream: (stream byte 0x8000)
  var input_stream_addr/esi: (addr stream byte) <- address input_stream

  var sum/edi: int <- copy 0
  read-line-from-real-keyboard input_stream_addr

  var temp/eax: int <- read_digit input_stream_addr
  var first_digit/ebx: int <- copy temp
  var this_digit/edx: int <- copy temp

  {
    var done?/eax: boolean <- stream-empty? input_stream_addr
    compare done?, 1
    break-if-=

    var next_digit/eax: int <- read_digit input_stream_addr
    # hacky newline check
    compare next_digit, 0
    break-if-<

    {
      compare this_digit, next_digit
      break-if-!=
      sum <- add this_digit
    }

    this_digit <- copy next_digit
    
    loop
  }

  # the last iteration will need to compare the last number to the first
  {
    compare this_digit, first_digit
    break-if-!=
    sum <- add this_digit
  }

  print-int32-decimal 0, sum
  
  return 0/ok
}

fn read_digit input_stream_addr: (addr stream byte) -> _/eax: int {
  var next_digit/eax: byte <- read-byte input_stream_addr
  next_digit <- subtract 0x30
  var next_digit/eax: int <- copy next_digit
  return next_digit
}
