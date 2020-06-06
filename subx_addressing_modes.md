[The Readme](Readme.md) describes SubX notation with some details hidden
behind _syntax sugar_ -- local rewrite rules that make programming in SubX
less error-prone. However, much low-level SubX (before the syntax sugar is
implemented) is written without syntax sugar. This document describes some
details of the syntax sugar: how the reg/mem operand is translated into
arguments.

## How x86 instructions compute operands

The [Intel processor manual](http://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf)
is the final source of truth on the x86 instruction set, but it can be
forbidding to make sense of, so here's a quick orientation. You will need
familiarity with binary numbers, and maybe a few other things. Email [me](mailto:mu@akkartik.com)
any time if something isn't clear. I love explaining this stuff for as long as
it takes. The bad news is that it takes some getting used to. The good news is
that internalizing the next 500 words will give you a significantly deeper
understanding of your computer.

The reg/mem operand can be specified by 1-7 arguments, each ranging in size
from 2 bits to 4 bytes. The key argument that's always present for reg/mem
operands is `/mod`, the _addressing mode_. This is a 2-bit argument that can
take 4 possible values, and it determines what other arguments are required,
and how to interpret them.

- If `/mod` is `3`: the operand is in the register described by the 3-bit
  `/rm32` argument.

- If `/mod` is `0`: the operand is in the address provided in the register
  described by `/rm32`. That's `*rm32` in C syntax.

- If `/mod` is `1`: the operand is in the address provided by adding the
  register in `/rm32` with the (1-byte) displacement. That's `*(rm32 + /disp8)`
  in C syntax.

- If `/mod` is `2`: the operand is in the address provided by adding the
  register in `/rm32` with the (4-byte) displacement. That's `*(/rm32 +
  /disp32)` in C syntax.

In the last three cases, one exception occurs when the `/rm32` argument
contains `4`. Rather than encoding register `esp`, it means the address is
provided by three _whole new_ arguments (`/base`, `/index` and `/scale`) in a
_totally_ different way (where `<<` is the left-shift operator):

  ```
  reg/mem = *(base + (index << scale))
  ```

(There are a couple more exceptions ☹; see [Table 2-2](modrm.pdf) and [Table 2-3](sib.pdf)
of the Intel manual for the complete story.)

Phew, that was a lot to take in. Some examples to work through as you reread
and digest it:

1. To read directly from the `eax` register, `/mod` must be `3` (direct mode),
   and `/rm32` must be `0`. There must be no `/base`, `/index` or `/scale`
   arguments.

2. To read from `*eax` (in C syntax), `/mod` must be `0` (indirect mode), and
   the `/rm32` argument must be `0`. There must be no `/base`, `/index` or
   `/scale` arguments (Intel calls the trio the 'SIB byte'.).

3. To read from `*(eax+4)`, `/mod` must be `1` (indirect + disp8 mode),
   `/rm32` must be `0`, there must be no SIB byte, and there must be a single
   displacement byte containing `4`.

4. To read from `*(eax+ecx+4)`, one approach would be to set `/mod` to `1` as
   above, `/rm32` to `4` (SIB byte next), `/base` to `0`, `/index` to `1`
   (`ecx`) and a single displacement byte to `4`. (What should the `scale` bits
   be? Can you think of another approach?)

5. To read from `*(eax+ecx+1000)`, one approach would be:
   - `/mod`: `2` (indirect + disp32)
   - `/rm32`: `4` (`/base`, `/index` and `/scale` arguments required)
   - `/base`: `0` (eax)
   - `/index`: `1` (ecx)
   - `/disp32`: 4 bytes containing `1000`

## Putting it all together

Here's an example showing these arguments at work:

<img alt='apps/ex3.subx' src='html/ex3.png'>

This program sums the first 10 natural numbers. By convention I use horizontal
tabstops to help read instructions, dots to help follow the long lines,
comments before groups of instructions to describe their high-level purpose,
and comments at the end of complex instructions to state the low-level
operation they perform. Numbers are always in hexadecimal (base 16) and must
start with a digit ('0'..'9'); use the '0x' prefix when a number starts with a
letter ('a'..'f'). I tend to also include it as a reminder when numbers look
like decimal numbers.

---

I recommend you order arguments consistently in your programs. SubX allows
arguments in any order, but only because that's simplest to explain/implement.
Switching order from instruction to instruction is likely to add to the
reader's burden. Here's the order I've been using after opcodes:

```
        |<--------- reg/mem --------->|        |<- reg/mem? ->|
/subop  /mod /rm32  /base /index /scale  /r32   /displacement   /immediate
```

---

Try running this example now:

```sh
$ ./bootstrap translate init.linux apps/ex3.subx -o apps/ex3
$ ./bootstrap run apps/ex3
$ echo $?
55
```

If you're on Linux you can also run it natively:

```sh
$ ./apps/ex3
$ echo $?
55
```

These details should now be enough information for reading and modifying
low-level SubX programs.
