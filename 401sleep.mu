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
