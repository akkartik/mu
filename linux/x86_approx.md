# How approximate is Intel's floating-point reciprocal instruction?

2020/10/03

Here's a test Mu program that prints out the bits for 0.5:

  ```
  fn main -> r/ebx: int {
    var two/eax: int <- copy 2
    var half/xmm0: float <- convert two
    half <- reciprocal half
    var mem: float
    copy-to mem, half
    var out/eax: int <- reinterpret mem
    print-int32-hex 0, out
    print-string 0, "\n"
    r <- copy 0
  }
  ```

It gives different results when emulated and run natively:

  ```
  $ cd linux
  $ ./translate_debug x.mu  # debug mode = error checking
  $ bootstrap/bootstrap run a.elf
  0x3f000000  # correct
  $ ./a.elf
  0x3efff000  # wrong
  ```

I spent some time digging into this before I realized it wasn't a bug in Mu,
just an artifact of the emulator not actually using the `reciprocal` instruction.
Here's a procedure you can follow along with to convince yourself.

Start with this program (good.c):

  ```c
  #include<stdio.h>
  int main(void) {
    int n = 2;
    float f = 1.0/n;
    printf("%f\n", f);
    return 0;
  }
  ```

It works as you'd expect (compiling unoptimized to actually compute the
division):

  ```
  $ gcc good.c
  $ ./a.out
  0.5
  ```

Let's look at its Assembly:

  ```
  $ gcc -S good.c
  ```

The generated `good.s` has a lot of stuff that doesn't interest us, surrounding
these lines:

  ```asm
                        ; destination
  movl      $2,         -8(%rbp)
  cvtsi2sd  -8(%rbp),   %xmm0
  movsd     .LC0(%rip), %xmm1
  divsd     %xmm0,      %xmm1
  movapd    %xmm1,      %xmm0
  ```

This fragment converts `2` into floating-point and then divides 1.0 (the
constant `.LC0`) by it, leaving the result in register `xmm0`.

There's a way to get gcc to emit the `rcpss` instruction using intrinsics, but
I don't know how to do it, so I'll modify the generated Assembly directly:

  ```diff
        movl      $2,         -8(%rbp)
  <     cvtsi2sd  -8(%rbp),   %xmm0
  <     movsd     .LC0(%rip), %xmm1
  <     divsd     %xmm0,      %xmm1
  <     movapd    %xmm1,      %xmm0
  ---
  >     cvtsi2ss  -8(%rbp),   %xmm0
  >     rcpss     %xmm0,      %xmm0
  >     movss     %xmm0,      -4(%rbp)
  ```

Let's compare the result of both versions:

  ```
  $ gcc good.s
  $ ./a.out
  0.5
  $ gcc good.modified.s
  $ ./a.out
  0.499878
  ```

Whoa!

Reading the Intel manual more closely, it guarantees that the relative error
of `rcpss` is less than `1.5*2^-12`, and indeed 12 bits puts us squarely in
the fourth decimal place.

Among the x86 instructions Mu supports, two are described in the Intel manual
as "approximate": `reciprocal` (`rcpss`) and `inverse-square-root` (`rsqrtss`).
Intel introduced these instructions as part of its SSE expansion in 1999. When
it upgraded SSE to SSE2 (in 2000), most of its scalar[1] single-precision
floating-point instructions got upgraded to double-precision &mdash; but not
these two. So they seem to be an evolutionary dead-end.

[1] Thanks boulos for feedback: https://news.ycombinator.com/item?id=28501429#28507118
