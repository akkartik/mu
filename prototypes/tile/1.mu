# little example program: animate a line in text-mode
#
# To run (on Linux and x86):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu prototypes/tile/1.mu
#   $ ./a.elf
# You should see a line drawn on a blank screen. Press a key. You should see
# the line seem to fall down the screen. Press a second key to quit.
# https://archive.org/details/akkartik-2min-2020-07-01

fn main -> exit-status/ebx: int {
  clear-screen
  move-cursor-on-screen 5, 5
  print-string-to-screen "_________"
  enable-keyboard-immediate-mode
  var dummy/eax: byte <- read-key
  var row/eax: int <- copy 5
  {
    compare row, 0xe  # 15
    break-if-=
    animate row
    row <- increment
    sleep 0 0x5f5e100  # 100ms
    loop
  }
  var dummy/eax: byte <- read-key
  enable-keyboard-type-mode
  clear-screen
  exit-status <- copy 0
}

fn animate row: int {
  var col/eax: int <- copy 5
  {
    compare col, 0xe
    break-if-=
    move-cursor-on-screen row, col
    print-string-to-screen " "
    increment row
    move-cursor-on-screen row, col
    print-string-to-screen "_"
    decrement row
    col <- increment
    loop
  }
}

type timespec {
  tv_sec: int
  tv_nsec: int
}

# prototype wrapper around syscall_nanosleep
# nsecs must be less than 999999999 or 0x3b9ac9ff nanoseconds
fn sleep secs: int, nsecs: int {
  var t: timespec
  # initialize t
  var tmp/eax: (addr int) <- get t, tv_sec
  var tmp2/ecx: int <- copy secs
  copy-to *tmp, tmp2
  tmp <- get t, tv_nsec
  tmp2 <- copy nsecs
  copy-to *tmp, tmp2
  # perform the syscall
  var t-addr/ebx: (addr timespec) <- address t
  var rem-addr/ecx: (addr timespec) <- copy 0
  syscall_nanosleep
}
