## Running

`bootstrap` currently has the following sub-commands:

- `bootstrap help`: some helpful documentation to have at your fingertips.

- `bootstrap test`: runs all automated tests.

- `bootstrap translate <input files> -o <output ELF binary>`: translates `.subx`
  files into an executable ELF binary.

- `bootstrap run <ELF binary> <args>`: simulates running the ELF binaries emitted
  by `bootstrap translate`. Useful for testing and debugging.

  Remember, not all 32-bit Linux binaries are guaranteed to run. I'm not
  building general infrastructure here for all of the x86 instruction set.
  SubX is about programming with a small, regular subset of 32-bit x86.
