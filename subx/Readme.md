## SubX: a simplistic assembly language

SubX is a minimalist assembly language designed:
* to explore ways to turn arbitrary manual tests into reproducible automated
  tests,
* to be easy to implement in itself, and
* to help learn and teach the x86 instruction set.

```
$ git clone https://github.com/akkartik/mu
$ cd mu/subx
$ ./subx  # print out a help message
```

[![Build Status](https://api.travis-ci.org/akkartik/mu.svg)](https://travis-ci.org/akkartik/mu)

Expanding on the first bullet, it hopes to support more comprehensive tests
by:

0. Running generated binaries in _emulated mode_. Emulated mode is slower than
   native execution (which will also work), but there's more sanity checking,
   and more descriptive error messages for common low-level problems.

   ```sh
   $ ./subx translate examples/ex1.subx -o examples/ex1
   $ ./examples/ex1  # only on Linux
   $ echo $?
   42
   $ ./subx run examples/ex1  # on Linux or BSD or OS X
   $ echo $?
   42
   ```

   The assembly syntax is designed so the assembler (`subx translate`) has
   very little to do, making it feasible to reimplement in itself. Programmers
   have to explicitly specify all opcodes and operands.

   ```sh (just for syntax highlighting)
   # exit(42)
   bb/copy-to-EBX  0x2a/imm32  # 42 in hex
   b8/copy-to-EAX  1/imm32/exit
   cd/syscall  0x80/imm8
   ```

   To keep code readable you can add _metadata_ to any word after a `/`.
   Metadata can be just comments for readers, and they'll be ignored. They can
   also trigger checks. Here, tagging operands with the `imm32` type allows
   SubX to check that instructions have precisely the operand types they
   should. x86 instructions have 14 types of operands, and missing one causes
   all future instructions to go off the rails, interpreting operands as
   opcodes and vice versa. So this is a useful check.

1. Designing testable wrappers for operating system interfaces. For example,
   it can `read()` from or `write()` to fake in-memory files in tests. More
   details [below](#subx-library). We are continuing to port syscalls from
   [the old Mu VM in the parent directory](https://github.com/akkartik/mu).

2. Supporting a special _trace_ stream in addition to the default `stdin`,
   `stdout` and `stderr` streams. The trace stream is designed for programs to
   emit structured facts they deduce about their domain as they execute. Tests
   can then check the set of facts deduced in addition to the results of the
   function under test. This form of _automated whitebox testing_ permits
   writing tests for performance, fault tolerance, deadlock-freedom, memory
   usage, etc. For example, if a sort function traces each swap, a performance
   test could check that the number of swaps doesn't quadruple when the size
   of the input doubles.

The hypothesis is that designing the entire system to be testable from day 1
and from the ground up would radically impact the culture of an eco-system in
a way that no bolted-on tool or service at higher levels can replicate. It
would make it easier to write programs that can be [easily understood by newcomers](http://akkartik.name/about).
It would reassure authors that an app is free from regression if all automated
tests pass. It would make the stack easy to rewrite and simplify by dropping
features, without fear that a subset of targeted apps might break. As a result
people might fork projects more easily, and also exchange code between
disparate forks more easily (copy the tests over, then try copying code over
and making tests pass, rewriting and polishing where necessary). The community
would have in effect a diversified portfolio of forks, a “wavefront” of
possible combinations of features and alternative implementations of features
instead of the single trunk with monotonically growing complexity that we get
today. Application writers who wrote thorough tests for their apps (something
they just can’t do today) would be able to bounce around between forks more
easily without getting locked in to a single one as currently happens.

However, that vision is far away, and SubX is just a first, hesitant step.
SubX supports a small, regular subset of the 32-bit x86 instruction set.
(Think of the name as short for "sub-x86".)

  - Only instructions that operate on the 32-bit integer E\*X registers, and a
    couple of instructions for operating on 8-bit values. No floating-point
    yet. Most legacy registers will never be supported.

  - Only instructions that assume a flat address space; legacy instructions
    that use segment registers will never be supported.

  - No instructions that check the carry or parity flags; arithmetic operations
    always operate on signed integers (while bitwise operations always operate
    on unsigned integers).

  - Only relative jump instructions (with 8-bit or 32-bit offsets).

The (rudimentary, statically linked) ELF binaries SubX generates can be run
natively on Linux, and they require only the Linux kernel.

## Status

I'm currently implementing SubX in SubX in 3 phases:

  1. Converting ascii hex bytes to binary. (✓)
  2. Packing bitfields for x86 instructions into bytes. (80% complete)
  3. Replacing addresses with labels.

In parallel, I'm designing testable wrappers for syscalls, particularly for
scalably running blocking syscalls with a test harness concurrently monitoring
their progress.

## An example program

In the interest of minimalism, SubX requires more knowledge than traditional
assembly languages of the x86 instructions it supports. Here's an example
SubX program, using one line per instruction:

<img alt='examples/ex3.subx' src='../html/subx/ex3.png'>

This program sums the first 10 natural numbers. By convention I use horizontal
tabstops to help read instructions, dots to help follow the long lines,
comments before groups of instructions to describe their high-level purpose,
and comments at the end of complex instructions to state the low-level
operation they perform. Numbers are always in hexadecimal (base 16); the '0x'
prefix is optional, and I tend to include it as a reminder when numbers look
like decimal numbers or words.

As you can see, programming in SubX requires the programmer to know the (kinda
complex) structure of x86 instructions, all the different operands that an
instruction can have, their layout in bytes (for example, the `subop` and
`r32` fields use the same bits, so an instruction can't have both; more on
this below), the opcodes for supported instructions, and so on.

While SubX syntax is fairly dumb, the error-checking is relatively smart. I
try to provide clear error messages on instructions missing operands or having
unexpected operands. Either case would otherwise cause instruction boundaries
to diverge from what you expect, and potentially lead to errors far away. It's
useful to catch such errors early.

Try running this example now:

```sh
$ ./subx translate examples/ex3.subx -o examples/ex3
$ ./subx run examples/ex3
$ echo $?
55
```

If you're on Linux you can also run it natively:

```sh
$ ./examples/ex3
$ echo $?
55
```

The rest of this Readme elaborates on the syntax for SubX programs, starting
with a few prerequisites about the x86 instruction set.

## A quick tour of the x86 instruction set

The [Intel processor manual](http://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf)
is the final source of truth on the x86 instruction set, but it can be
forbidding to make sense of, so here's a quick orientation. You will need
familiarity with binary and hexadecimal encodings (starting with '0x') for
numbers, and maybe a few other things. Email [me](mailto:mu@akkartik.com)
any time if something isn't clear. I love explaining this stuff for as long as
it takes.

The x86 instructions SubX supports can take anywhere from 1 to 13 bytes. Early
bytes affect what later bytes mean and where an instruction ends. Here's the
big picture of a single x86 instruction from the Intel manual:

<img alt='x86 instruction structure' src='../html/subx/encoding.png'>

There's a lot here, so let's unpack it piece by piece:

* The prefix bytes are not used by SubX, so ignore them.

* The opcode bytes encode the instruction used. Ignore their internal structure;
  we'll just treat them as a sequence of whole bytes. The opcode sequences
  SubX recognizes are enumerated by running `subx help opcodes`. For more
  details on a specific opcode, consult html guides like https://c9x.me/x86 or
  the Intel manual.

* The addressing mode byte is used by all instructions that take an `rm32`
  operand according to `subx help opcodes`. (That's most instructions.) The
  `rm32` operand expresses how an instruction should load one 32-bit operand
  from either a register or memory. It is configured by the addressing mode
  byte and, optionally, the SIB (scale, index, base) byte as follows:

  - if the `mod` (mode) field is `11` (3): the `rm32` operand is the contents
    of the register described by the `r/m` bits.
    - `000` (0) means register `EAX`
    - `001` (1) means register `ECX`
    - `010` (2) means register `EDX`
    - `011` (3) means register `EBX`
    - `100` (4) means register `ESP`
    - `101` (5) means register `EBP`
    - `110` (6) means register `ESI`
    - `111` (7) means register `EDI`

  - if `mod` is `00` (0): `rm32` is the contents of the address provided in the
    register provided by `r/m`. That's `*r/m` in C syntax.

  - if `mod` is `01` (1): `rm32` is the contents of the address provided by
    adding the register in `r/m` with the (1-byte) displacement. That's
    `*(r/m + disp8)` in C syntax.

  - if `mod` is `10` (2): `rm32` is the contents of the address provided by
    adding the register in `r/m` with the (4-byte) displacement. That's
    `*(r/m + disp32)` in C syntax.

  In the last 3 cases, one exception occurs when the `r/m` field contains
  `010` (4). Rather than encoding register ESP, that means the address is
  provided by a SIB byte next:

  ```
  base + index * 2^scale + displacement
  ```

  (There are a couple more exceptions ☹; see [Table 2-2](modrm.pdf) and [Table 2-3](sib.pdf)
  of the Intel manual for the complete story.)

  Phew, that was a lot to take in. Some examples to work through as you reread
  and digest it:

  1. To read directly from the EAX register, `mod` must be `11` (direct mode),
     and the `r/m` bits must be `000` (EAX). There must be no SIB byte.

  1. To read from `*EAX` in C syntax, `mod` must be `00` (indirect mode), and
     the `r/m` bits must be `000`. There must be no SIB byte.

  1. To read from `*(EAX+4)`, `mod` must be `01` (indirect + disp8 mode),
     `r/m` must be `000`, there must be no SIB byte, and there must be a
     single displacement byte containing `00000010` (4).

  1. To read from `*(EAX+ECX+4)`, one approach would be to set `mod` to `01`,
     `r/m` to `100` (SIB byte next), `base` to `000`, `index` to `001` (ECX)
     and a single displacement byte to 4. What should the `scale` bits be? Can
     you think of another approach?

  1. To read from `*(EAX+ECX+0x00f00000)`, one approach would be:
     - `mod`: `10` (indirect + disp32)
     - `r/m`: `100` (SIB byte)
     - `base`: `000` (EAX)
     - `index`: `001` (ECX)
     - `displacement`: 4 bytes containing 0x00f00000

* Back to the instruction picture. We've already covered the SIB byte and most
  of the addressing mode byte. Instructions can also provide a second operand
  as either a displacement or immediate value (the two are distinct because
  some instructions use a displacement as part of `rm32` and an immediate for
  the other operand).

* Finally, the `reg` bits in the addressing mode byte can also encode the
  second operand. Sometimes they can also be part of the opcode bits. For
  example, an operand byte of `ff` and `reg` bits of `001` means "increment
  rm32". (Notice that instructions that use the `reg` bits as a "sub-opcode"
  cannot also use it as a second operand.)

That concludes our quick tour. By this point it's probably clear to you that
the x86 instruction set is overly complicated. Many simpler instruction sets
exist. However, your computer right now likely runs x86 instructions and not
them. Internalizing the last 750 words may allow you to program your computer
fairly directly, with only minimal-going-on-zero reliance on a C compiler.

## The syntax of SubX programs

SubX programs map to the same ELF binaries that a conventional Linux system
uses. Linux ELF binaries consist of a series of _segments_. In particular, they
distinguish between code and data. Correspondingly, SubX programs consist of a
series of segments, each starting with a header line: `==` followed by a name.
The first segment must be named `code`; the second must be named `data`.

Execution begins at the start of the `code` segment by default.

You can reuse segment names:

```
== code
...A...

== data
...B...

== code
...C...
```

The `code` segment now contains the instructions of `A` as well as `C`.

Within the `code` segment, each line contains a comment, label or instruction.
Comments start with a `#` and are ignored. Labels should always be the first
word on a line, and they end with a `:`.

Instructions consist of a sequence of words. As mentioned above, each word can
contain _metadata_ after a `/`. Metadata can be either required by SubX or act
as a comment for the reader; SubX silently ignores unrecognized metadata. A
single word can contain multiple pieces of metadata, each starting with a `/`.

The words in an instruction consist of 1-3 opcode bytes, and different kinds
of operands corresponding to the bitfields in an x86 instruction listed above.
For error checking, these operands must be tagged with one of the following
bits of metadata:
  - `mod`
  - `rm32` ("r/m" in the x86 instruction diagram above, but we can't use `/`
    in metadata tags)
  - `r32` ("reg" in the x86 diagram)
  - `subop` (for when "reg" in the x86 diagram encodes a sub-opcode rather
    than an operand)
  - displacement: `disp8`, `disp16` or `disp32`
  - immediate: `imm8` or `imm32`

Different instructions (opcodes) require different operands. SubX will
validate each instruction in your programs, and raise an error anytime you
miss or spuriously add an operand.

I recommend you order operands consistently in your programs. SubX allows
operands in any order, but only because that's simplest to explain/implement.
Switching order from instruction to instruction is likely to add to the
reader's burden. Here's the order I've been using:

```
/subop  /mod /rm32  /base /index /scale  /r32  /displacement  /immediate
```

Instructions can refer to labels in displacement or immediate operands, and
they'll obtain a value based on the address of the label: immediate operands
will contain the address directly, while displacement operands will contain
the difference between the address and the address of the current instruction.
The latter is mostly useful for `jump` and `call` instructions.

Functions are defined using labels. By convention, labels internal to functions
(that must only be jumped to) start with a `$`. Any other labels must only be
called, never jumped to. All labels must be unique.

A special label is `Entry`, which can be used to specify/override the entry
point of the program. It doesn't have to be unique, and the latest definition
will override earlier ones.

(The `Entry` label, along with duplicate segment headers, allows programs to
be built up incrementally out of multiple _layers_](http://akkartik.name/post/wart-layers).)

The data segment consists of labels as before and byte values. Referring to
data labels in either `code` segment instructions or `data` segment values
(using the `imm32` metadata either way) yields their address.

Automatic tests are an important part of SubX, and there's a simple mechanism
to provide a test harness: all functions that start with `test-` are called in
turn by a special, auto-generated function called `run-tests`. How you choose
to call it is up to you.

I try to keep things simple so that there's less work to do when I eventually
implement SubX in SubX. But there _is_ one convenience: instructions can
provide a string literal surrounded by quotes (`"`) in an `imm32` operand.
SubX will transparently copy it to the `data` segment and replace it with its
address. Strings are the only place where a SubX operand is allowed to contain
spaces.

That should be enough information for writing SubX programs. The `examples/`
directory provides some fodder for practice, giving a more gradual introduction
to SubX features. This repo includes the binary for all examples. At any
commit, an example's binary should be identical bit for bit with the result of
translating the corresponding `.subx` file. The binary should also be natively
runnable on a Linux system running on Intel x86 processors, either 32- or
64-bit. If either of these invariants is broken it's a bug on my part.

## Running

Running `subx` will transparently compile it as necessary.

`subx` currently has the following sub-commands:

* `subx help`: some helpful documentation to have at your fingertips.

* `subx test`: runs all automated tests.

* `subx translate <input files> -o <output ELF binary>`: translates `.subx`
  files into an executable ELF binary.

* `subx run <ELF binary>`: simulates running the ELF binaries emitted by `subx
  translate`. Useful for debugging, and also enables more thorough testing of
  `translate`.

  Remember, not all 32-bit Linux binaries are guaranteed to run. I'm not
  building general infrastructure here for all of the x86 instruction set.
  SubX is about programming with a small, regular subset of 32-bit x86.

## A few hints for debugging

Writing programs in SubX is surprisingly pleasant and addictive. Reading
programs is a work in progress, and hopefully the extensive unit tests help.
However, _debugging_ programs is where one really faces up to the low-level
nature of SubX. Even the smallest modifications need testing to make sure they
work. In my experience, there is no modification so small that I get it working
on the first attempt. And when it doesn't work, there are no clear error
messages. Machine code is too simple-minded for that. You can't use a debugger,
since SubX's simplistic ELF binaries contain no debugging information. So
debugging requires returning to basics and practicing with a new, more
rudimentary but hopefully still workable toolkit:

* Start by nailing down a concrete set of steps for reproducibly obtaining the
  error or erroneous behavior.

* If possible, turn the steps into a failing test. It's not always possible,
  but SubX's primary goal is to keep improving the variety of tests one can
  write.

* Start running the single failing test alone. This involves modifying the top
  of the program (or the final `.subx` file passed in to `subx translate`) by
  replacing the call to `run-tests` with a call to the appropriate `test-`
  function.

* Generate a trace for the failing test while running your program in emulated
  mode (`subx run`):
  ```
  $ ./subx translate input.subx -o binary
  $ ./subx --trace run binary arg1 arg2  2>trace
  ```
  The ability to generate a trace is the essential reason for the existence of
  `subx run` mode. It gives far better visibility into program internals than
  running natively.

* As a further refinement, it is possible to render label names in the trace
  by adding a second flag to both the `translate` and `run` commands:
  ```
  $ ./subx --map translate input.subx -o binary
  $ ./subx --map --trace run binary arg1 arg2  2>trace
  ```
  `subx --map translate` emits a mapping from label to address in a file
  called `map`. `subx --map --trace run` reads in the `map` file at the start
  and prints out any matching label name as it traces each instruction
  executed.

  Here's a sample of what a trace looks like, with a few boxes highlighted:

  <img alt='trace example' src='../html/subx/trace.png'>

  Each of the green boxes shows the trace emitted for a single instruction.
  It starts with a line of the form `run: inst: ___` followed by the opcode
  for the instruction, the state of registers before the instruction executes,
  and various other facts deduced during execution. Some instructions first
  print a matching label. In the above screenshot, the red boxes show that
  address `0x0900005e` maps to label `$loop` and presumably marks the start of
  some loop. Function names get similar `run: == label` lines.

* One trick when emitting traces with labels:
  ```
  $ grep label trace
  ```
  This is useful for quickly showing you the control flow for the run, and the
  function executing when the error occurred. I find it useful to start with
  this information, only looking at the complete trace after I've gotten
  oriented on the control flow. Did it get to the loop I just modified? How
  many times did it go through the loop?

* Once you have SubX displaying labels in traces, it's a short step to modify
  the program to insert more labels just to gain more insight. For example,
  consider the following function:

  <img alt='control example -- before' src='../html/subx/control0.png'>

  This function contains a series of jump instructions. If a trace shows
  `is-hex-lowercase-byte?` being encountered, and then `$is-hex-lowercase-byte?:end`
  being encountered, it's still ambiguous what happened. Did we hit an early
  exit, or did we execute all the way through? To clarify this, add temporary
  labels after each jump:

  <img alt='control example -- after' src='../html/subx/control1.png'>

  Now the trace should have a lot more detail on which of these labels was
  reached, and precisely when the exit was taken.

* If you find yourself wondering, "when did the contents of this memory
  address change?", `subx run` has some rudimentary support for _watch
  points_. Just insert a label starting with `$watch-` before an instruction
  that writes to the address, and its value will start getting dumped to the
  trace after every instruction thereafter.

* Once we have a sense for precisely which instructions we want to look at,
  it's time to look at the trace as a whole. Key is the state of registers
  before each instruction. If a function is receiving bad arguments it becomes
  natural to inspect what values were pushed on the stack before calling it,
  tracing back further from there, and so on.

  I occasionally want to see the precise state of the stack segment, in which
  case I uncomment a commented-out call to `dump_stack()` in the `vm.cc`
  layer. It makes the trace a lot more verbose and a lot less dense, necessitating
  a lot more scrolling around, so I keep it turned off most of the time.

Hopefully these hints are enough to get you started. The main thing to
remember is to not be afraid of modifying the sources. A good debugging
session gets into a nice rhythm of generating a trace, staring at it for a
while, modifying the sources, regenerating the trace, and so on. Email
[me](mailto:mu@akkartik.com) if you'd like another pair of eyes to stare at a
trace, or if you have questions or complaints.

## Reference documentation on available primitives

### Data Structures

* Kernel strings: null-terminated arrays of bytes. Unsafe and to be avoided,
  but needed for interacting with the kernel.

* Strings: length-prefixed arrays of bytes. String contents are preceded by
  4 bytes (32 bytes) containing the `length` of the array.

* Slices: a pair of 32-bit addresses denoting a [half-open](https://en.wikipedia.org/wiki/Interval_(mathematics))
  \[`start`, `end`) interval to live memory with a consistent lifetime.

  Invariant: `start` <= `end`

* Streams: strings prefixed by 32-bit `write` and `read` indexes that the next
  write or read goes to, respectively.

  * offset 0: write index
  * offset 4: read index
  * offset 8: length of array (in bytes)
  * offset 12: start of array data

  Invariant: 0 <= `read` <= `write` <= `length`

* File descriptors (fd): Low-level 32-bit integers that the kernel uses to
  track files opened by the program.

* File: 32-bit value containing either a fd or an address to a stream (fake
  file).

* Buffered files (buffered-file): Contain a file descriptor and a stream for
  buffering reads/writes. Each `buffered-file` must exclusively perform either
  reads or writes.

### 'system calls'

A major goal of SubX is testable wrappers for operating system syscalls.
Here's what I've built so far:

* `write`: takes two arguments, a file `f` and an address to array `s`.

  Comparing this interface with the Unix `write()` syscall shows two benefits:

  1. SubX can handle 'fake' file descriptors in tests.

  1. `write()` accepts buffer and its length in separate arguments, which
     requires callers to manage the two separately and so can be error-prone.
     SubX's wrapper keeps the two together to increase the chances that we
     never accidentally go out of array bounds.

* `read`: takes two arguments, a file `f` and an address to stream `s`. Reads
  as much data from `f` as can fit in (the free space of) `s`.

  Like with `write()`, this wrapper around the Unix `read()` syscall adds the
  ability to handle 'fake' file descriptors in tests, and reduces the chances
  of clobbering outside array bounds.

  One bit of weirdness here: in tests we do a redundant copy from one stream
  to another. See [the comments before the implementation](http://akkartik.github.io/mu/html/subx/058read.subx.html)
  for a discussion of alternative interfaces.

* `stop`: takes two arguments:
  - `ed` is an address to an _exit descriptor_. Exit descriptors allow us to
    `exit()` the program in production, but return to the test harness within
    tests. That allows tests to make assertions about when `exit()` is called.
  - `value` is the status code to `exit()` with.

  For more details on exit descriptors and how to create one, see [the
  comments before the implementation](http://akkartik.github.io/mu/html/subx/057stop.subx.html).

* `new-segment`

  Allocates a whole new segment of memory for the program, discontiguous with
  both existing code and data (heap) segments. Just a more opinionated form of
  [`mmap`](http://man7.org/linux/man-pages/man2/mmap.2.html).

* `allocate`: takes two arguments, an address to allocation-descriptor `ad`
  and an integer `n`

  Allocates a contiguous range of memory that is guaranteed to be exclusively
  available to the caller. Returns the starting address to the range in `EAX`.

  An allocation descriptor tracks allocated vs available addresses in some
  contiguous range of memory. The int specifies the number of bytes to allocate.

  Explicitly passing in an allocation descriptor allows for nested memory
  management, where a sub-system gets a chunk of memory and further parcels it
  out to individual allocations. Particularly helpful for (surprise) tests.

* ... _(to be continued)_

### primitives built atop system calls

_(Compound arguments are usually passed in by reference. Where the results are
compound objects that don't fit in a register, the caller usually passes in
allocated memory for it.)_

#### assertions for tests
* `check-ints-equal`: fails current test if given ints aren't equal
* `check-stream-equal`: fails current test if stream doesn't match string
* `check-next-stream-line-equal`: fails current test if next line of stream
  until newline doesn't match string

#### error handling
* `error`: takes three arguments, an exit-descriptor, a file and a string (message)

  Prints out the message to the file and then exits using the provided
  exit-descriptor.

* `error-byte`: like `error` but takes an extra byte value that it prints out
  at the end of the message.

#### predicates
* `kernel-string-equal?`: compares a kernel string with a string
* `string-equal?`: compares two strings
* `stream-data-equal?`: compares a stream with a string
* `next-stream-line-equal?`: compares with string the next line in a stream, from
  `read` index to newline

* `slice-empty?`: checks if the `start` and `end` of a slice are equal
* `slice-equal?`: compares a slice with a string
* `slice-starts-with?`: compares the start of a slice with a string
* `slice-ends-with?`: compares the end of a slice with a string

#### writing to disk
* `write-stream`: stream -> file
* `write-buffered`: string -> buffered-file
* `write-slice`: slice -> buffered-file
* `write-stream-buffered`: stream -> buffered-file
* `flush`: buffered-file
* `print-byte`:  buffered-file, int

#### reading from disk
* `read-byte`: buffered-file -> byte
* `read-line`: buffered-file -> stream

#### non-IO operations on streams
* `new-stream`: allocates space for a stream of size `n`.
* `clear-stream`: resets everything in the stream to `0` (except its `length`).
* `rewind-stream`: resets the read index of the stream to `0` without modifying
  its contents.

#### reading/writing hex representations of integers
* `is-hex-int?`: takes a slice argument, returns boolean result in `EAX`
* `parse-hex-int`: takes a slice argument, returns int result in `EAX`
* `is-hex-digit?`: takes a 32-bit word containing a single byte, returns
  boolean result in `EAX`.
* `from-hex-char`: takes a hexadecimal digit character in EAX, returns its
  numeric value in `EAX`
* `to-hex-char`: takes a single-digit numeric value in EAX, returns its
  corresponding hexadecimal character in `EAX`

#### tokenization

from a stream:
* `next-token`: stream, delimiter byte -> slice
* `skip-chars-matching`: stream, delimiter byte
* `skip-chars-not-matching`: stream, delimiter byte

from a slice:
* `next-token-from-slice`: start, end, delimiter byte -> slice
  Given a slice and a delimiter byte, returns a new slice inside the input
  that ends at the delimiter byte.

* `skip-chars-matching-in-slice`: curr, end, delimiter byte -> new-curr (in `EAX`)
* `skip-chars-not-matching-in-slice`:  curr, end, delimiter byte -> new-curr (in `EAX`)

## Known issues

* String literals support no escape sequences. In particular, no way to
  represent newlines.

## Resources

* [Single-page cheatsheet for the x86 ISA](https://net.cs.uni-bonn.de/fileadmin/user_upload/plohmann/x86_opcode_structure_and_instruction_overview.pdf)
  (pdf; [cached local copy](https://github.com/akkartik/mu/blob/master/subx/cheatsheet.pdf))
* [Concise reference for the x86 ISA](https://c9x.me/x86)
* [Intel processor manual](http://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf) (pdf)
* [Some details on the unconventional organization of this project.](http://akkartik.name/post/four-repos)

## Inspirations

* [&ldquo;Creating tiny ELF executables&rdquo;](https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html)
* [&ldquo;Bootstrapping a compiler from nothing&rdquo;](http://web.archive.org/web/20061108010907/http://www.rano.org/bcompiler.html)
* Forth implementations like [StoneKnifeForth](https://github.com/kragen/stoneknifeforth)
