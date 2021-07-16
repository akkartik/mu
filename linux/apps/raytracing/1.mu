# Listing 1 of https://raytracing.github.io/books/RayTracingInOneWeekend.html
# (simplified)
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu/linux
#   $ ./translate apps/raytracing/1.mu
#   $ ./a.elf > 1.ppm

fn main -> _/ebx: int {
  print-string 0, "P3\n256 256\n255\n"
  var j/ecx: int <- copy 0xff
  {
    compare j, 0
    break-if-<
    var i/eax: int <- copy 0
    {
      compare i, 0xff
      break-if->
      print-int32-decimal 0, i
      print-string 0, " "
      print-int32-decimal 0, j
      print-string 0, " 64\n"
      i <- increment
      loop
    }
    j <- decrement
    loop
  }
  return 0
}
