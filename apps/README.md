Some apps written in SubX and Mu, in 3 categories:

* `ex*`: small stand-alone examples that don't need any of the shared code at
  the top-level. They each have a simple pedagogical goal. Try these first.

* Code unique to phases of our build toolchain:
  * Core SubX: `hex`, `survey`, `pack`, `dquotes`, `assort`, `tests`
  * Syntax sugar for SubX: `sigils`, `calls`, `braces`
  * More ambitious translator for a memory-safe language (in progress): `mu`

* Miscellaneous test programs.

All SubX apps include binaries. At any commit, an example's binary should be
identical bit for bit with the result of translating the corresponding `.subx`
file. The binary should also be natively runnable on a Linux system running on
Intel x86 processors, either 32- or 64-bit. If either of these invariants is
broken, it's a bug.
