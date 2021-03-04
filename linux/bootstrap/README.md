This tool is 2 things:

a) An emulator for SubX, the subset of the 32-bit x86 instruction set used by
Mu.

b) A second translator for SubX programs that emits identical binaries to the
self-hosting versions in the parent directory. Having two diverse compilers
(one in a familiar language, one with minimal syscall surface area) that emit
identical binaries should help gain confidence in Mu.
