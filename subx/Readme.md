## What is this? 

SubX is a thin layer of syntactic sugar over (32-bit x86) machine code. The
SubX translator (it's too simple to be called a compiler, or even an
assembler) generates ELF binaries that require just a Unix-like kernel to run.
(The translator isn't self-hosted yet; generating the binaries does require a
C++ compiler and runtime.)

## Thin layer of abstraction over machine code, isn't that just an assembler?

Assemblers try to hide the precise instructions emitted from the programmer.
Consider these instructions in Assembly language:

```
add EBX, ECX
copy EBX, 0
copy ECX, 1
```

Here are the same instructions in SubX, just a list of numbers (opcodes and
operands) with metadata 'comments' after a `/`:

```
01/add 3/mod/direct 3/rm32/ebx 1/r32/ecx
bb/copy 0/imm32
b9/copy 1/imm32
```

Notice that a single instruction, say 'copy', maps to multiple opcodes.
That's just the tip of the iceberg of complexity that Assembly languages deal
with.

SubX doesn't shield the programmer from these details. Words always contain
the actual bits or bytes for machine code. But they also can contain metadata
after slashes, and SubX will run cross-checks and give good error messages
when there's a discrepancy between code and metadata.

## But why not use an assembler?

The long-term goal is to make programming in machine language ergonomic enough
that I (or someone else) can build a compiler for a high-level language in it.
That is, building a compiler without needing a compiler, anywhere among its
prerequisites.

Assemblers today are complex enough that they're built in a high-level
language, and need a compiler to build. They also tend to be designed to fit
into a larger toolchain, to be a back-end for a compiler. Their output is in
turn often passed to other tools like a linker. The formats that all these
tools use to talk to each other have grown increasingly complex in the face of
decades of evolution, usage and backwards-compatibility constraints. All these
considerations add to the burden of the assembler developer. Building the
assembler in a high-level language helps face up to them.

Assemblers _do_ often accept a far simpler language, just a file format
really, variously called 'flat' or 'binary', which gives the programmer
complete control over the precise bytes in an executable. SubX is basically
trying to be a more ergonomic flat assembler that will one day be bootstrapped
from machine code.

## Why in the world?

1. It seems wrong-headed that our computers look polished but are plagued by
   foundational problems of security and reliability. I'd like to learn to
   walk before I try to run. The plan: start out using the computer only to
   check my program for errors rather than to hide low-level details. Force
   myself to think about security by living with raw machine code for a while.
   Reintroduce high level languages (HLLs) only after confidence is regained
   in the foundations (and when the foundations are ergonomic enough to
   support developing a compiler in them). Delegate only when I can verify
   with confidence.

2. The software in our computers has grown incomprehensible. Nobody
   understands it all, not even experts. Even simple programs written by a
   single author require lots of time for others to comprehend. Compilers are
   a prime example, growing so complex that programmers have to choose to
   either program them or use them. I think they may also contribute to the
   incomprehensibility of the stack above them. I'd like to explore how much
   of a HLL I can build without a monolithic optimizing compiler, and see if
   deconstructing the work of the compiler can make the stack as a whole more
   comprehensible to others.

3. I want to learn about the internals of the infrastructure we all rely on in
   our lives.

## Running

```
$ git clone https://github.com/akkartik/mu
$ cd mu/subx
$ ./subx
```

Running `subx` will transparently compile it as necessary.

## Usage

`subx` currently has the following sub-commands:

* `subx test`: runs all automated tests.

* `subx translate <input file> <output ELF binary>`: translates a text file
  containing hex bytes and macros into an executable ELF binary.

* `subx run <ELF binary>`: simulates running the ELF binaries emitted by `subx
  translate`. Useful for debugging, and also enables more thorough testing of
  `translate`.

Putting them together, build and run one of the example programs:

<img alt='ex1.1.subx' src='html/ex1.png'>

```
$ ./subx translate ex1.1.subx ex1
$ ./subx run ex1
```

If you're running on Linux, `ex1` will also be runnable directly:
```
$ chmod +x ex1
$ ./ex1
```

There are a few such example programs here. At any commit an example's binary
should be identical bit for bit with the output of translating the .subx file.
The binary should also be natively runnable on a 32-bit Linux system. If
either of these invariants is broken it's a bug on my part. The binary should
also be runnable on a 64-bit Linux system. I can't guarantee it, but I'd
appreciate hearing if it doesn't run.

However, not all 32-bit Linux binaries are guaranteed to be runnable by
`subx`. I'm not building general infrastructure here for all of the x86 ISA
and ELF format. SubX is about programming with a small, regular subset of
32-bit x86:

* Only instructions that operate on the 32-bit E\*X registers. (No
  floating-point yet.)
* Only instructions that assume a flat address space; no instructions that use
  segment registers.
* No instructions that check the carry or parity flags; arithmetic operations
  always operate on signed integers (while bitwise operations always operate
  on unsigned integers)
* Only relative jump instructions (with 8-bit or 16-bit offsets).

The ELF binaries generated are statically linked and missing a lot of advanced
ELF features as well. But they will run.

For more details on programming in this subset, consult the online help:
```
$ ./subx help
```

## Resources

* [Single-page cheatsheet for the x86 ISA](https://net.cs.uni-bonn.de/fileadmin/user_upload/plohmann/x86_opcode_structure_and_instruction_overview.pdf)
  (pdf; [cached local copy](https://github.com/akkartik/mu/blob/master/subx/cheatsheet.pdf))
* [Concise reference for the x86 ISA](https://c9x.me/x86)
* [Intel programming manual](http://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf) (pdf)

## Inspirations

* [&ldquo;Creating tiny ELF executables&rdquo;](https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html)
* [&ldquo;Bootstrapping a compiler from nothing&rdquo;](http://web.archive.org/web/20061108010907/http://www.rano.org/bcompiler.html)
* Forth implementations like [StoneKnifeForth](https://github.com/kragen/stoneknifeforth)
