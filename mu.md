# Mu reference

Mu programs are sequences of `fn` and `type` definitions.

## Functions

Define functions with the `fn` keyword. For example:

```
  fn foo arg1: int, arg2: int -> result/eax: boolean
```

Functions contain `{}` blocks, `var` declarations, primitive statements and
calls to other functions. Only `{}` blocks can nest. Primitive statements and
function calls look similar:

```
  out1, out2, out3, ... <- operation inout1, inout2, inout3, ...
```

They can take any number of inouts and outputs, including 0. Statements
with 0 outputs also drop the `<-`.

Inouts can be either variables in memory, variables in registers, or
constants. Outputs are always variables in registers.

Inouts in memory can be either inputs or outputs (if they're addresses being
written to). Hence the name.

Primitives can often write to arbitrary output registers. User-defined
functions, however, require rigidly specified output registers.

## Variables, registers and memory

Declare local variables in a function using the `var` keyword.

You can declare local variables in either registers or memory (the stack). So
a `var` statement has two forms:
  - Living in a register, e.g. `var x/eax: int <- copy 0` defines `x` which
    lives in `eax`.
  - Living in memory, e.g. `var x: int` defines `x` on the stack.

Variables in registers must be initialized. Variables on the stack are
implicitly zeroed out.

Variables exist only within the `{}` block they're defined in. Space allocated
to them on the stack is reclaimed after execution leaves the block. Registers
restore whatever variable was using them in the outer block.

It is perfectly ok to reuse a register for a new variable. Even in a single
block (though you permanently lose the old variable then).

Variables can be in six 32-bit _general-purpose_ registers of the x86 processor.
  - eax
  - ebx
  - ecx
  - edx
  - esi ('s' often a mnemonic for 'source')
  - edi ('d' often a mnemonic for 'destination')

Most functions return results in `eax` by convention. In practice, it ends up
churning through variables pretty quickly.

You can store several types in these registers:
  - int
  - boolean
  - (addr T) (address into memory)
  - byte (uses only 8 bits)
  - code-point (Unicode)
  - grapheme (code-point encoded in UTF-8)

There's one 32-bit type you _cannot_ store in these registers:
  - float

It instead uses eight separate 32-bit registers: xmm0, xmm1, ..., xmm7

Types that require more than 32 bits (4 bytes) cannot be stored in registers:
  - (array T)
  - (handle T)
  - (stream T)
  - slice
  - any compound types you define using the `type` keyword

`T` here can be any type, including combinations of types. For example:
  - (array int) -- an array of ints
  - (addr int) -- an address to an int
  - (handle int) -- a handle to an int
  - (addr handle int) -- an address to a handle to int
  - (addr array handle int) -- an address to an array of handles to ints
  - ...and so on.

Other miscellaneous restrictions:
  - `byte` variables must be either in registers or on the heap, never local
    variables on the stack.
  - `addr` variables can never "escape" a function either by being returned or
    by being written to a memory location. When you need that sort of thing,
    use a `handle` instead.

## Primitive statement types

These usually operate on variables with 32-bit types, with some restrictions
noted below. Most instructions with multiple args require types to match.

Some notation for describing statement forms:
  - `var/reg` indicates a variable in some register. Sometimes we require a
    variable in a specific register, e.g. `var/eax`.
  - `var/xreg` indicates a variable in some floating-point register.
  - `var` without a `reg` indicates either a variable on the stack or
    dereferencing a variable in a (non-floating-point) register: `*var/reg`.
  - `n` indicates a literal integer. There are no floating-point literals.

### Moving values around

These instructions work with variables of any 32-bit type except `addr` and
`float`.

```
  var/reg <- copy var2/reg2
  copy-to var1, var2/reg
  var/reg <- copy var2
  var/reg <- copy n
  copy-to var, n
```

Byte variables have their own instructions:

```
  var/reg <- copy-byte var2/reg2
  var/reg <- copy-byte *var2/reg2     # var2 must have type (addr byte)
  copy-byte-to *var1/reg1, var2/reg2  # var1 must have type (addr byte)
```

Floating point instructions can be copied as well, but only to floating-point
registers `xmm_`.

```
  var/xreg <- copy var2/xreg2
  copy-to var1, var2/xreg
  var/xreg <- copy var2
  var/xreg <- copy *var2/reg2         # var2 must have type (addr byte) and live in a general-purpose register
```

There's no way to copy a literal to a floating-point register. However,
there's a few ways to convert non-float values in general-purpose registers.

```
  var/xreg <- convert var2/reg2
  var/xreg <- convert var2
  var/xreg <- convert *var2/reg2
```

Correspondingly, there are ways to convert floats into integers.

```
  var/reg <- convert var2/xreg2
  var/reg <- convert var2
  var/reg <- convert *var2/reg2

  var/reg <- truncate var2/xreg2
  var/reg <- truncate var2
  var/reg <- truncate *var2/reg2
```

### Comparing values

Work with variables of any 32-bit type. `addr` variables can only be compared
to 0.

```
  compare var1, var2/reg
  compare var1/reg, var2
  compare var/eax, n
  compare var, n
```

Floating-point numbers cannot be compared to literals, and the register must
come first.

```
  compare var1/xreg1, var2/xreg2
  compare var1/xreg1, var2
```

### Branches

Immediately after a `compare` instruction you can branch on its result. For
example:

```
  break-if-=
```

This instruction will jump to after the enclosing `{}` block if the previous
`compare` detected equality. Here's the list of conditional and unconditional
`break` instructions:

```
  break
  break-if-=
  break-if-!=
  break-if-<
  break-if->
  break-if-<=
  break-if->=
```

Similarly, you can jump back to the start of the enclosing `{}` block with
`loop`. Here's the list of `loop` instructions.

```
  loop
  loop-if-=
  loop-if-!=
  loop-if-<
  loop-if->
  loop-if-<=
  loop-if->=
```

Additionally, there are special variants for comparing `addr` and `float`
values, which results in the following comprehensive list of jumps:

```
  break
  break-if-=
  break-if-!=
  break-if-<    break-if-addr<    break-if-float<
  break-if->    break-if-addr>    break-if-float>
  break-if-<=   break-if-addr<=   break-if-float<=
  break-if->=   break-if-addr>=   break-if-float>=

  loop
  loop-if-=
  loop-if-!=
  loop-if-<     loop-if-addr<     loop-if-float<
  loop-if->     loop-if-addr>     loop-if-float>
  loop-if-<=    loop-if-addr<=    loop-if-float<=
  loop-if->=    loop-if-addr>=    loop-if-float>=
```

One final property all these jump instructions share: they can take an
optional block name to jump to. For example:

```
  a: {
    ...
    break a     #----------|
    ...               #    |
  }                   # <--|


  a: {                # <--|
    ...               #    |
    b: {              #    |
      ...             #    |
      loop a    #----------|
      ...
    }
    ...
  }
```

However, there's no way to jump to a block that doesn't contain the `loop` or
`break` instruction.

### Integer arithmetic

These instructions require variables of non-`addr`, non-`float` types.

Add:
```
  var1/reg1 <- add var2/reg2
  var/reg <- add var2
  add-to var1, var2/reg                 # var1 += var2
  var/reg <- add n
  add-to var, n
```

Subtract:
```
  var1/reg1 <- subtract var2/reg2
  var/reg <- subtract var2
  subtract-from var1, var2/reg          # var1 -= var2
  var/reg <- subtract n
  subtract-from var, n
```

Add one:
```
  var/reg <- increment
  increment var
```

Subtract one:
```
  var/reg <- decrement
  decrement var
```

Multiply:
```
  var/reg <- multiply var2
```

The result of a multiply must be a register.

Negate:
```
  var1/reg1 <- negate
  negate var
```

### Floating-point arithmetic

Operations on `float` variables include a few we've seen before and some new
ones. Notice here that we mostly use floating-point registers `xmm_`, but
still use the general-purpose registers when dereferencing variables of type
`(addr float)`.

```
  var/xreg <- add var2/xreg2
  var/xreg <- add var2
  var/xreg <- add *var2/reg2

  var/xreg <- subtract var2/xreg2
  var/xreg <- subtract var2
  var/xreg <- subtract *var2/reg2

  var/xreg <- multiply var2/xreg2
  var/xreg <- multiply var2
  var/xreg <- multiply *var2/reg2

  var/xreg <- divide var2/xreg2
  var/xreg <- divide var2
  var/xreg <- divide *var2/reg2

  var/xreg <- reciprocal var2/xreg2
  var/xreg <- reciprocal var2
  var/xreg <- reciprocal *var2/reg2

  var/xreg <- square-root var2/xreg2
  var/xreg <- square-root var2
  var/xreg <- square-root *var2/reg2

  var/xreg <- inverse-square-root var2/xreg2
  var/xreg <- inverse-square-root var2
  var/xreg <- inverse-square-root *var2/reg2

  var/xreg <- min var2/xreg2
  var/xreg <- min var2
  var/xreg <- min *var2/reg2

  var/xreg <- max var2/xreg2
  var/xreg <- max var2
  var/xreg <- max *var2/reg2
```

Two instructions in the above list are approximate. According to the Intel
manual, `reciprocal` and `inverse-square-root` [go off the rails around the
fourth decimal place](linux/x86_approx.md). If you need more precision, use
`divide` separately.

### Bitwise boolean operations

These require variables of non-`addr`, non-`float` types.

And:
```
  var1/reg1 <- and var2/reg2
  var/reg <- and var2
  and-with var1, var2/reg
  var/reg <- and n
  and-with var, n
```

Or:
```
  var1/reg1 <- or var2/reg2
  var/reg <- or var2
  or-with var1, var2/reg
  var/reg <- or n
  or-with var, n
```

Not:
```
  var1/reg1 <- not
  not var
```

Xor:
```
  var1/reg1 <- xor var2/reg2
  var/reg <- xor var2
  xor-with var1, var2/reg
  var/reg <- xor n
  xor-with var, n
```

### Bitwise shifts

Shifts require variables of non-`addr`, non-`float` types.

```
  var/reg <- shift-left n
  var/reg <- shift-right n
  var/reg <- shift-right-signed n
  shift-left var, n
  shift-right var, n
  shift-right-signed var, n
```

Shifting bits left always inserts zeros on the right.
Shifting bits right inserts zeros on the left by default.
A _signed_ shift right duplicates the leftmost bit, thereby preserving the
sign of an integer.

## More complex instructions on more complex types

These instructions work with any type `T`. As before we use `/reg` here to
indicate when a variable must live in a register. We also include type
constraints after a `:`.

### Addresses and handles

You can compute the address of any variable in memory (never in registers):

```
  var/reg: (addr T) <- address var2: T
```

As mentioned up top, `addr` variables can never escape the function where
they're computed. You can't store them on the heap, or in compound types.
Think of them as short-lived things.

To manage long-lived addresses, _allocate_ them on the heap.

```
  allocate var: (addr handle T)       # var can be in either register or memory
```

Handles can be copied and stored without restriction. However, they're too
large to fit in a register. You also can't access their payload directly, you
have to first convert them into a short-lived `addr` using _lookup_.

```
  var y/eax: (addr T) <- lookup x: (handle T)
```

Since handles are large compound types, there's a special helper for comparing
them:

```
  var/eax: boolean <- handle-equal? var1: (handle T), var2: (handle T)
```

### Arrays

Arrays are declared in two ways:
  1. On the stack with a literal size:
```
  var x: (array int 3)
```
  2. On the heap with a potentially variable size. For example:
```
  var x: (handle array int)
  var x-ah/eax: (addr handle array int) <- address x
  populate x-ah, 8
```
  The `8` here can also be an int in a register or memory.

You can compute the length of an array, though you'll need an `addr` to do so:

```
  var/reg: int <- length arr/reg: (addr array T)
```

To read from or write to an array, use `index` to first obtain an address to
read from or modify:

```
  var/reg: (addr T) <- index arr/reg: (addr array T), n
  var/reg: (addr T) <- index arr: (array T len), n
```

Like our notation of `n`, `len` here is required to be a literal.

The index requested can also be a variable in a register, with one caveat:

```
  var/reg: (addr T) <- index arr/reg: (addr array T), idx/reg: int
  var/reg: (addr T) <- index arr: (array T len), idx/reg: int
```

The caveat: the size of T must be 1, 2, 4 or 8 bytes. For other sizes of T
you'll need to split up the work, performing a `compute-offset` before the
`index`.

```
  var/reg: (offset T) <- compute-offset arr: (addr array T), idx/reg: int     # arr can be in reg or mem
  var/reg: (offset T) <- compute-offset arr: (addr array T), idx: int         # arr can be in reg or mem
```

The result of a `compute-offset` statement can be passed to `index`:

```
  var/reg: (addr T) <- index arr/reg: (addr array T), idx/reg: (offset T)
```

### Stream operations

A common use for arrays is as buffers. Save a few items to a scratch space and
then process them. This pattern is so common (we use it in files) that there's
special support for it with a built-in type: `stream`.

Streams are like arrays in many ways. You can initialize them with a length on
the stack:

```
  var x: (stream int 3)
```

You can also populate them on the heap:
```
  var x: (handle stream int)
  var x-ah/eax: (addr handle stream int) <- address x
  populate-stream x-ah, 8
```

However, streams don't provide random access with an `index` instruction.
Instead, you write to them sequentially, and read back what you wrote.

```
  read-from-stream s: (addr stream T), out: (addr T)
  write-to-stream s: (addr stream T), in: (addr T)
```

Streams of bytes are particularly common for managing Unicode text, and there
are a few functions to help with them:

```
  write s: (addr stream byte), u: (addr array byte)  # write u to s, abort if full
  overflow?/eax: boolean <- try-write s: (addr stream byte), u: (addr array byte)
  write-stream dest: (addr stream byte), src: (addr stream byte)
  # bytes
  append-byte s: (addr stream byte), var: int  # write lower byte of var
  var/eax: byte <- read-byte s: (addr stream byte)
  # 32-bit graphemes encoded in UTF-8
  write-grapheme out: (addr stream byte), g: grapheme
  g/eax: grapheme <- read-grapheme in: (addr stream byte)
```

You can check if a stream is empty or full:

```
  var/eax: boolean <- stream-empty? s: (addr stream)
  var/eax: boolean <- stream-full? s: (addr stream)
```

You can clear streams:

```
  clear-stream f: (addr stream T)
```

You can also rewind them to reread their contents:

```
  rewind-stream f: (addr stream T)
```

## Compound types

Primitive types can be combined together using the `type` keyword. For
example:

```
type point {
  x: int
  y: int
}
```

Mu programs are currently sequences of `fn` and `type` definitions.

Compound types can't include `addr` types for safety reasons (use `handle` instead,
which is described below). They also can't currently include `array`, `stream`
or `byte` types. Since arrays and streams carry their size with them, supporting
them in compound types complicates variable initialization. Instead of
defining them inline in a type definition, define a `handle` to them. Bytes
shouldn't be used for anything but UTF-8 strings.

To access within a compound type, use the `get` instruction. There are two
forms. You need either a variable of the type itself (say `T`) in memory, or a
variable of type `(addr T)` in a register.

```
var/reg: (addr T_f) <- get var/reg: (addr T), f
var/reg: (addr T_f) <- get var: T, f
```

The `f` here is the field name from the `type` definition, and its type `T_f`
must match the type of `f` in the `type` definition. For example, some legal
instructions for the definition of `point` above:

```
var a/eax: (addr int) <- get p, x
var a/eax: (addr int) <- get p, y
```

You can clear compound types using the `clear-object` function:

```
clear-object var: (addr T)
```

You can shallow-copy compound types using the `copy-object` function:

```
copy-object src: (addr T), dest: (addr T)
```

