type timespec {
  tv_sec: int
  tv_nsec: int
}

# TODO: y2038
fn time -> secs/eax: int {
  var t: timespec
  var clock/ebx: int <- copy 0  # CLOCK_MONOTONIC
  var t-addr/ecx: (addr timespec) <- address t
  syscall_clock_gettime
  var t-secs-addr/ecx: (addr int) <- get t-addr, tv_sec
  secs <- copy *t-secs-addr
}

fn ntime -> nsecs/eax: int {
  var t: timespec
  var clock/ebx: int <- copy 0  # CLOCK_MONOTONIC
  var t-addr/ecx: (addr timespec) <- address t
  syscall_clock_gettime
  var t-nsecs-addr/ecx: (addr int) <- get t-addr, tv_nsec
  nsecs <- copy *t-nsecs-addr
}

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
