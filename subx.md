## SubX

SubX is a notation for a subset of x86 machine code. [The Mu translator](http://akkartik.github.io/mu/html/linux/mu.subx.html)
is implemented in SubX and also emits SubX code.

Here's an example program in SubX that adds 1 and 1 and returns the result to
the parent shell process:

```sh
== code
Entry:
  # ebx = 1
  bb/copy-to-ebx  1/imm32
  # increment ebx
  43/increment-ebx
  # exit(ebx)
  e8/call  syscall_exit/disp32
```

## The syntax of SubX instructions

Just like in regular machine code, SubX programs consist mostly of instructions,
which are basically sequences of numbers (always in hex). Instructions consist
of words separated by whitespace. Words may be _opcodes_ (defining the
operation being performed) or _arguments_ (specifying the data the operation
acts on). Any word can have extra _metadata_ attached to it after `/`. Some
metadata is required (like the `/imm32` and `/imm8` above), but unrecognized
metadata is silently skipped so you can attach comments to words (like the
instruction name `/copy-to-ebx` above, or the `/exit` argument).

What do all these numbers mean? SubX supports a small subset of the 32-bit x86
instruction set that likely runs on your computer. (Think of the name as short
for "sub-x86".) The instruction set contains instructions like `89/copy`,
`01/add`, `3d/compare` and `51/push-ecx` which modify registers and a byte-addressable
memory. For a complete list of supported instructions, run `./help opcodes`.

The registers instructions operate on are as follows:

- Six 32-bit integer registers: `0/eax`, `1/ebx`, `2/ecx`, `3/edx`, `6/esi`
  and `7/edi`.
- Two additional 32-bit registers: `4/esp` and `5/ebp`. (I suggest you only
  use these to manage the call stack.)
- Eight 8-bit integer registers aliased with parts of the 32-bit registers:
  `0/al`, `1/cl`, `2/dl`, `3/bl`, `4/ah`, `5/ch`, `6/dh` and `7/bh`.
- Eight 32-bit floating-point registers: `xmm0` through `xmm7`.

(Intel processors support a 16-bit mode and 64-bit mode. SubX will never
support them. There are also _many_ more instructions that SubX will never
support.)

While SubX doesn't provide the usual mnemonics for opcodes, it _does_ provide
error-checking. If you miss an argument or accidentally add an extra argument,
you'll get a nice error. SubX won't arbitrarily interpret bytes of data as
instructions or vice versa.

It's worth distinguishing between an instruction's arguments and its _operands_.
Arguments are provided directly in instructions. Operands are pieces of data
in register or memory that are operated on by instructions.

Intel processors typically operate on no more than two operands, and at most
one of them (the 'reg/mem' operand) can access memory. The address of the
reg/mem operand is constructed by expressions of one of these forms:

  - `%reg`: operate on just a register, not memory
  - `*reg`: look up memory with the address in some register
  - `*(reg + disp)`: add a constant to the address in some register
  - `*(base + (index << scale) + disp)` where `base` and `index` are registers,
    and `scale` and `disp` are 2- and 32-bit constants respectively.

Under the hood, SubX turns expressions of these forms into multiple arguments
with metadata in some complex ways. See [the doc on bare SubX](subx_bare.md).

That covers the complexities of the reg/mem operand. The second operand is
simpler. It comes from exactly one of the following argument types:

  - `/r32`
  - displacement: `/disp8` or `/disp32`
  - immediate: `/imm8` or `/imm32`

Putting all this together, here's an example that adds the integer in `eax` to
the one at address `edx`:

```
01/add %edx 0/r32/eax
```

## The syntax of SubX programs

SubX programs consist of functions and global variables. It's very important
the two stay separate; executing data as code is the most common vector for
security issues. Consequently, SubX programs maintain separate code and data
_segments_. To add to a segment, specify it using a `==` header.

Details of segment header syntax depend on where you want the program to run:

* On Linux, segment headers consist of `==`, a name and an approximate
  starting address (which might perturb slightly during translation)

* For bootable disks that run without an OS, segment headers consist of `==`
  and a name. Boot disks really only have one segment of contiguous memory,
  and segment headers merely affect parsing and error-checking.

Segments can be added to.

```sh
== code 0x09000000  # first mention requires starting address on Linux
...A...

== data 0x0a000000
...B...

== code             # no address necessary when adding
...C...
```

The `code` segment now contains the instructions of `A` as well as `C`.

Within the `code` segment, each line contains a comment, label or instruction.
Comments start with a `#` and are ignored. Labels should always be the first
word on a line, and they end with a `:`.

Instructions can refer to labels in displacement or immediate arguments, and
they'll obtain a value based on the address of the label: immediate arguments
will contain the address directly, while displacement arguments will contain
the difference between the address and the address of the current instruction.
The latter is mostly useful for `jump` and `call` instructions.

Functions are defined using labels. By convention, labels internal to functions
(that must only be jumped to) start with a `$`. Any other labels must only be
called, never jumped to. All labels must be unique.

Functions are called using the following syntax:
```
(func arg1 arg2 ...)
```

Function arguments must be either literals (integers or strings) or a reg/mem
operand using the syntax in the previous section.

Another special pair of labels are the block delimiters `{` and `}`. They can
be nested, and jump instructions can take arguments `loop` or `break` that
jump to the enclosing `{` and `}` respectively.

The data segment consists of labels as before and byte values. Referring to
data labels in either `code` segment instructions or `data` segment values
yields their address.

Automatic tests are an important part of SubX, and there's a simple mechanism
to provide a test harness: all functions that start with `test-` are called in
turn by a special, auto-generated function called `run-tests`. How you choose
to call it is up to you.

I try to keep things simple so that there's less work to do when implementing
SubX in SubX. But there _is_ one convenience: instructions can provide a
string literal surrounded by quotes (`"`) in an `imm32` argument. SubX will
transparently copy it to the `data` segment and replace it with its address.
Strings are the only place where a SubX word is allowed to contain spaces.

That should be enough information for writing SubX programs. The `linux/`
directory provides some fodder for practice in the `linux/ex*.subx` files,
giving a more gradual introduction to SubX features. In particular, you should
work through `linux/factorial4.subx`, which demonstrates all the above ideas in
concert.
