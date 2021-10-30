fn main screen: (addr screen), keyboard: (addr keyboard) {
  var in-storage: (stream byte 0x80)
  var in/esi: (addr stream byte) <- address in-storage
  read-line-from-keyboard keyboard, in, screen, 0xf/fg 0/bg
}
