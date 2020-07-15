# Mu Syntax

Here are two valid statements in Mu:

```
increment x
y <- increment
```

Understanding when to use one vs the other is the critical idea in Mu. In
short, the former increments a value in memory, while the latter increments a
value in a register.

Most languages start from some syntax and do what it takes to implement it.
Mu, however, is designed as a safe way to program in [a regular subset of
32-bit x86 machine code](subx.md), _satisficing_ rather than optimizing for a
clean syntax. To keep the mapping to machine code lightweight, Mu exclusively
uses statements and most statements map to a single instruction of machine
code.

Since the x86 instruction set restricts how many memory locations an instruction
can use, Mu makes registers explicit as well. Variables must be explicitly
mapped to registers; otherwise they live in memory.

Statements consist of 3 parts: the operation, optional _inouts_ and optional
_outputs_. Outputs come before the operation name and `<-`.

Outputs are always registers; memory locations that need to be modified are
passed in by reference.

So Mu programmers need to make two new categories of decisions: whether to
define variables in registers or memory, and whether to put variables to the
left or right. There's always exactly one way to write any given operation. In
return for this overhead you get a lightweight and future-proof stack. And Mu
will provide good error message to support you.

Further down, this page enumerates all available primitives in Mu, and [a
separate page](http://akkartik.github.io/mu/html/mu_instructions.html)
describes how each primitive is translated to machine code.

## Functions and calls

Zooming out from single statements, here's a complete sample program in Mu:

<img alt='ex2.mu' src='html/ex2.mu.png'>

Mu programs are lists of functions. Each function has the following form:

```
fn _name_ _inout_ ... -> _output_ ... {
  _statement_
  _statement_
  ...
}
```

Each function has a header line, and some number of statements, each on a
separate line. Headers describe inouts and outputs. Inouts can't be registers,
and outputs _must_ be registers.

The above program also demonstrates a function call (to the function `do-add`).
Function calls look the same as primitive statements: they can return (multiple)
outputs in registers, and modify inouts passed in by reference. In addition,
there's one more constraint: output registers must match the function header.
For example:

```
fn f -> x/eax: int {
  ...
}
fn g {
  a/eax <- f  # ok
  a/ebx <- f  # wrong
}
```

The function `main` is special; it is where the program starts running. It
must always return a single int in register `ebx` (as the exit status of the
process). It can also optionally accept an array of strings as input (from the
shell command-line). To be precise, `main` must have one of the following
two signatures:

- `fn main -> x/ebx: int`
- `fn main args: (addr array (addr array byte)) -> x/ebx: int`

(The name of the output is flexible.)

## Blocks

Blocks are useful for grouping related statements. They're delimited by `{`
and `}`, both each alone on a line.

Blocks can nest:

```
{
  _statements_
  {
    _more statements_
  }
}
```

Blocks can be named (with the name ending in a `:` on the same line as the
`{`):

```
$name: {
  _statements_
}
```

Further down we'll see primitive statements for skipping or repeating blocks.
Besides control flow, the other use for blocks is...

## Local variables

Functions can define new variables at any time with the keyword `var`. There
are two variants of the `var` statement, for defining variables in registers
or memory.

```
var name: type
var name/reg: type <- ...
```

Variables on the stack are never initialized. (They're always implicitly
zeroed them out.) Variables in registers are always initialized.

Register variables can go in 6 registers: `eax`, `ebx`, `ecx`, `edx`, `esi`
and `edi`. Defining a variable in a register either clobbers the previous
variable (if it was defined in the same block) or shadows it temporarily (if
it was defined in an outer block).

Variables exist from their definition until the end of their containing block.
Register variables may also die earlier if their register is clobbered by a
new variable.

## Arithmetic primitives

Here is the list of arithmetic primitive operations supported by Mu. The name
`n` indicates a literal integer rather than a variable, and `var/reg` indicates
a variable in a register.

```
var/reg <- increment
increment var
var/reg <- decrement
decrement var
var1/reg1 <- add var2/reg2
var/reg <- add var2
add-to var1, var2/reg
var/reg <- add n
add-to var, n

var1/reg1 <- sub var2/reg2
var/reg <- sub var2
sub-from var1, var2/reg
var/reg <- sub n
sub-from var, n

var1/reg1 <- and var2/reg2
var/reg <- and var2
and-with var1, var2/reg
var/reg <- and n
and-with var, n

var1/reg1 <- or var2/reg2
var/reg <- or var2
or-with var1, var2/reg
var/reg <- or n
or-with var, n

var1/reg1 <- xor var2/reg2
var/reg <- xor var2
xor-with var1, var2/reg
var/reg <- xor n
xor-with var, n

var/reg <- copy var2/reg2
copy-to var1, var2/reg
var/reg <- copy var2
var/reg <- copy n
copy-to var, n

compare var1, var2/reg
compare var1/reg, var2
compare var/eax, n
compare var, n

var/reg <- shift-left n
var/reg <- shift-right n
var/reg <- shift-right-signed n
shift-left var, n
shift-right var, n
shift-right-signed var, n

var/reg <- multiply var2
```

Any statement above that takes a variable in memory can be replaced with a
dereference (`*`) of an address variable (of type `(addr ...)`) in a register.
(Types can have multiple words, and are wrapped in `()` when they do.) But you
can't dereference variables in memory. You have to load them into a register
first.

Excluding dereferences, the above statements must operate on non-address
primitive types: `int` or `boolean`. (Booleans are really just `int`s, and Mu
assumes any value but `0` is true.)

## Operating on individual bytes

A special-case is variables of type 'byte'. Mu is a 32-bit platform so for the
most part only supports types that are multiples of 32 bits. However, we do
want to support strings in ASCII and UTF-8, which will be arrays of bytes.

Since most x86 instructions implicitly load 32 bits at a time from memory,
variables of type 'byte' are only allowed in registers, not on the stack. Here
are the possible statements for reading bytes to/from memory:

```
var/reg <- copy-byte var2/reg2      # var: byte, var2: byte
var/reg <- copy-byte *var2/reg2     # var: byte, var2: (addr byte)
copy-byte-to *var1/reg1, var2/reg2  # var1: (addr byte), var2: byte
```

In addition, variables of type 'byte' are restricted to (the lowest bytes of)
just 4 registers: eax, ecx, edx and ebx.

## Primitive jumps

There are two kinds of jumps, both with many variations: `break` and `loop`.
`break` instructions jump to the end of the containing block. `loop` instructions
jump to the beginning of the containing block.

All jumps can take an optional label starting with '$':

```
loop $foo
```

This instruction jumps to the beginning of the block called $foo. The corresponding
`break` jumps to the end of the block. Either jump statement must lie somewhere
inside such a block. Jumps are only legal to containing blocks. (Use named
blocks with restraint; jumps to places far away can get confusing.)

There are two unconditional jumps:

```
loop
loop label
break
break label
```

The remaining jump instructions are all conditional. Conditional jumps rely on
the result of the most recently executed `compare` instruction. (To keep
programs easy to read, keep compare instructions close to the jump that uses
them.)

```
break-if-=
break-if-= label
break-if-!=
break-if-!= label
```

Inequalities are similar, but have unsigned and signed variants. For simplicity,
always use signed integers; use the unsigned variants only to compare addresses.

```
break-if-<
break-if-< label
break-if->
break-if-> label
break-if-<=
break-if-<= label
break-if->=
break-if->= label

break-if-addr<
break-if-addr< label
break-if-addr>
break-if-addr> label
break-if-addr<=
break-if-addr<= label
break-if-addr>=
break-if-addr>= label
```

Similarly, conditional loops:

```
loop-if-=
loop-if-= label
loop-if-!=
loop-if-!= label

loop-if-<
loop-if-< label
loop-if->
loop-if-> label
loop-if-<=
loop-if-<= label
loop-if->=
loop-if->= label

loop-if-addr<
loop-if-addr< label
loop-if-addr>
loop-if-addr> label
loop-if-addr<=
loop-if-addr<= label
loop-if-addr>=
loop-if-addr>= label
```

## Addresses

Passing objects by reference requires the `address` operation, which returns
an object of type `addr`.

```
var/reg: (addr T) <- address var2: T
```

Here `var2` can't live in a register.

## Array operations

Mu arrays are size-prefixed so that operations on them can check bounds as
necessary at run-time. The `length` statement returns the number of elements
in an array.

```
var/reg: int <- length arr/reg: (addr array T)
```

The `index` statement takes an `addr` to an `array` and returns an `addr` to
one of its elements, that can be read from or written to.

```
var/reg: (addr T) <- index arr/reg: (addr array T), n
var/reg: (addr T) <- index arr: (array T sz), n
```

The index can also be a variable in a register, with a caveat:

```
var/reg: (addr T) <- index arr/reg: (addr array T), idx/reg: int
var/reg: (addr T) <- index arr: (array T sz), idx/reg: int
```

The caveat: the size of T must be 1, 2, 4 or 8 bytes. The x86 instruction set
has complex addressing modes that can index into an array in a single instruction
in these situations.

For types in general you'll need to split up the work, performing a `compute-offset`
before the `index`.

```
var/reg: (offset T) <- compute-offset arr: (addr array T), idx/reg: int     # arr can be in reg or mem
var/reg: (offset T) <- compute-offset arr: (addr array T), idx: int         # arr can be in reg or mem
```

The `compute-offset` statement returns a value of type `(offset T)` after
performing any necessary bounds checking. Now the offset can be passed to
`index` as usual:

```
var/reg: (addr T) <- index arr/reg: (addr array T), idx/reg: (offset T)
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

To access within a compound type, use the `get` instruction. There are two
forms. You need either a variable of the type itself (say `T`) in memory, or a
variable of type `(addr T)` in a register.

```
var/reg: (addr T_f) <- get var/reg: (addr T), f
var/reg: (addr T_f) <- get var: T, f
```

The `f` here is the field name from the `type` definition, and `T_f` must
match the type of `f` in the `type` definition. For example, some legal
instructions for the definition of `point` above:

```
var a/eax: (addr int) <- get p, x
var a/eax: (addr int) <- get p, y
```

## Handles for safe access to the heap

We've seen the `addr` type, but it's intended to be short-lived. In particular,
you can't save `addr` values inside compound `type`s. To do that you need a
"fat pointer" called a `handle` that is safe to keep around for extended
periods and ensures it's used safely without corrupting the heap and causing
security issues or hard-to-debug misbehavior.

To actually _use_ a `handle`, we have to turn it into an `addr` first using
the `lookup` statement.

```
var y/reg: (addr T) <- lookup x
```

Now operate on the `addr` as usual, safe in the knowledge that you can later
recover any writes to its payload from `x`.

It's illegal to continue to use this `addr` after a function that reclaims
heap memory. You have to repeat the lookup from the `handle`. (Luckily Mu
doesn't implement reclamation yet.)

Having two kinds of addresses takes some getting used to. Do we pass in
variables by value, by `addr` or by `handle`? In inputs or outputs? Here are 3
rules:

  * Functions that need to look at the payload should accept an `(addr ...)`.
  * Functions that need to treat a handle as a value, without looking at its
  payload, should accept a `(handle ...)`. Helpers that save handles into data
  structures are a common example.
  * Functions that need to allocate memory should accept an `(addr handle
  ...)`.

Try to avoid mixing these use cases.

You can save handles inside compound types like this:

```
var y/reg: (addr handle T_f) <- get var: (addr T), f
copy-handle-to *y, x
```

Or this:

```
var y/reg: (addr handle T) <- index arr: (addr array handle T), n
copy-handle-to *y, x
```

To create handles to non-array types, use `allocate`:

```
var x: (addr handle T)
... initialize x ...
allocate x
```

To create handles to array types, use `populate`:

```
var x: (addr handle array T)
... initialize x ...
populate x, 3  # array of 3 T's
```

You can copy handles to another variable on the stack like this:

```
var x: (handle T)
# ..some code initializing x..
var y/eax: (addr handle T) <- address ...
copy-handle x, y
```

## Conclusion

Anything not allowed here is forbidden. At least until you modify mu.subx.
Please [contact me](mailto:ak@akkartik.com) or [report issues](https://github.com/akkartik/mu/issues)
when you encounter a missing or misleading error message.
