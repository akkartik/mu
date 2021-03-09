## Reference documentation on available primitives

### Data Structures

- Handles: addresses to objects allocated on the heap. They're augmented with
  book-keeping to guarantee memory-safety, and so cannot be stored in registers.
  See [mu.md](mu.md) for details, but in brief:
    - You need `addr` values to access data they point to.
    - You can't store `addr` values in other types. They're temporary.
    - You can store `handle` values in other types.
    - To convert `handle` to `addr`, use `lookup`.
    - Reclaiming memory (currently unimplemented) invalidates all `addr`
      values.

- Kernel strings: null-terminated regions of memory. Unsafe and to be avoided,
  but needed for interacting with the kernel.

- Arrays: size-prefixed regions of memory containing multiple elements of a
  single type. Contents are preceded by 4 bytes (32 bits) containing the
  `size` of the array in bytes.

- Slices: a pair of 32-bit addresses denoting a [half-open](https://en.wikipedia.org/wiki/Interval_(mathematics))
  \[`start`, `end`) interval to live memory with a consistent lifetime.

  Invariant: `start` <= `end`

- Streams: strings prefixed by 32-bit `write` and `read` indexes that the next
  write or read goes to, respectively.

  - offset 0: write index
  - offset 4: read index
  - offset 8: size of array (in bytes)
  - offset 12: start of array data

  Invariant: 0 <= `read` <= `write` <= `size`

- File descriptors (fd): Low-level 32-bit integers that the kernel uses to
  track files opened by the program.

- File: 32-bit value containing either a fd or an address to a stream (fake
  file).

- Buffered files (buffered-file): Contain a file descriptor and a stream for
  buffering reads/writes. Each `buffered-file` must exclusively perform either
  reads or writes.

- Graphemes: 32-bit fragments of utf-8 that encode a single Unicode code-point.
- Code-points: 32-bit integers representing a Unicode character.

### 'system calls'

As I said at the top, a primary design goal of SubX (and Mu more broadly) is
to explore ways to turn arbitrary manual tests into reproducible automated
tests. SubX aims for this goal by baking testable interfaces deep into the
stack, at the OS syscall level. The idea is that every syscall that interacts
with hardware (and so the environment) should be *dependency injected* so that
it's possible to insert fake hardware in tests.

But those are big goals. Here are the syscalls I have so far:

- `write`: takes two arguments, a file `f` and an address to array `s`.

  Comparing this interface with the Unix `write()` syscall shows two benefits:

  1. SubX can handle 'fake' file descriptors in tests.

  1. `write()` accepts buffer and its size in separate arguments, which
     requires callers to manage the two separately and so can be error-prone.
     SubX's wrapper keeps the two together to increase the chances that we
     never accidentally go out of array bounds.

- `read`: takes two arguments, a file `f` and an address to stream `s`. Reads
  as much data from `f` as can fit in (the free space of) `s`.

  Like with `write()`, this wrapper around the Unix `read()` syscall adds the
  ability to handle 'fake' file descriptors in tests, and reduces the chances
  of clobbering outside array bounds.

  One bit of weirdness here: in tests we do a redundant copy from one stream
  to another. See [the comments before the implementation](http://akkartik.github.io/mu/html/060read.subx.html)
  for a discussion of alternative interfaces.

- `stop`: takes two arguments:
  - `ed` is an address to an _exit descriptor_. Exit descriptors allow us to
    `exit()` the program in production, but return to the test harness within
    tests. That allows tests to make assertions about when `exit()` is called.
  - `value` is the status code to `exit()` with.

  For more details on exit descriptors and how to create one, see [the
  comments before the implementation](http://akkartik.github.io/mu/html/059stop.subx.html).

- `new-segment`

  Allocates a whole new segment of memory for the program, discontiguous with
  both existing code and data (heap) segments. Just a more opinionated form of
  [`mmap`](http://man7.org/linux/man-pages/man2/mmap.2.html).

- `allocate`: takes two arguments, an address to allocation-descriptor `ad`
  and an integer `n`

  Allocates a contiguous range of memory that is guaranteed to be exclusively
  available to the caller. Returns the starting address to the range in `eax`.

  An allocation descriptor tracks allocated vs available addresses in some
  contiguous range of memory. The int specifies the number of bytes to allocate.

  Explicitly passing in an allocation descriptor allows for nested memory
  management, where a sub-system gets a chunk of memory and further parcels it
  out to individual allocations. Particularly helpful for (surprise) tests.

- `time`: returns the time in seconds since the epoch.

- `ntime`: returns the number of nanoseconds since some arbitrary point.
  Saturates at 32 bits. Useful for fine-grained measurements over relatively
  short durations.

- `sleep`: sleep for some number of whole seconds and some fraction of a
  second expressed in nanoseconds. Not having decimal literals can be awkward
  here.

- ... _(to be continued)_

I will continue to import syscalls over time from [the old Mu VM in the parent
directory](https://github.com/akkartik/mu), which has experimented with
interfaces for the screen, keyboard, mouse, disk and network.

### Functions

The most useful functions from 400.mu and later .mu files. Look for definitions
(using `ctags`) to see type signatures.

_(Compound arguments are usually passed in by reference. Where the results are
compound objects that don't fit in a register, the caller usually passes in
allocated memory for it.)_

#### assertions for tests

- `check`: fails current test if given boolean is false (`= 0`).
- `check-not`: fails current test if given boolean isn't false (`!= 0`).
- `check-ints-equal`: fails current test if given ints aren't equal
- `check-array-equal`: only arrays of ints, passes in a literal array in a
  whitespace-separated string.
- `check-stream-equal`: fails current test if stream doesn't match string
- `check-next-stream-line-equal`: fails current test if next line of stream
  until newline doesn't match string

Every Mu computer has a global trace that programs can write to, and that
tests can make assertions on.

- `clear-trace-stream`
- `check-trace-contains`
- `check-trace-scans-to`: like `check-trace-contains` but with an implicit,
  stateful start index

#### error handling

- `error`: takes three arguments, an exit-descriptor, a file and a string (message)

  Prints out the message to the file and then exits using the provided
  exit-descriptor.

- `error-byte`: like `error` but takes an extra byte value that it prints out
  at the end of the message.

#### numbers

- `abs`
- `repeated-shift-left`, since x86 only supports bit-shifts by constant values
- `repeated-shift-right`
- `shift-left-bytes`: shift left by `n*8` bits
- `integer-divide`

Floating point constructors, since x86 doesn't support immediate floats and Mu
doesn't yet parse floating-point literals:

- `rational`: int, int -> float
- `fill-in-rational`: int, int, (addr float)
- `fill-in-sqrt`: int, (addr float)

#### arrays and strings

- `populate`: allocates space for `n` objects of the appropriate type.
- `copy-array`: allocates enough space and writes out a copy of an array of
  some type.
- `slice-to-string`: allocates space for an array of bytes and copies the
  slice into it.

- `array-equal?`
- `substring`: string, start, length -> string
- `split-string`: string, delimiter -> array of strings

- `copy-array-object`

#### predicates

- `kernel-string-equal?`: compares a kernel string with a string
- `string-equal?`: compares two strings
- `stream-data-equal?`: compares a stream with a string
- `next-stream-line-equal?`: compares with string the next line in a stream, from
  `read` index to newline

- `slice-empty?`: checks if the `start` and `end` of a slice are equal
- `slice-equal?`: compares a slice with a string
- `slice-starts-with?`: compares the start of a slice with a string
- `slice-ends-with?`: compares the end of a slice with a string

#### writing to disk

- `write`: string -> file
  - Can also be used to cat a string into a stream.
- `write-stream`: stream -> file
  - Can also be used to cat one stream into another.
- `write-stream-data`: stream -> file
  - Like `write-stream` but ignores read index.
- `write-slice`: slice -> stream
- `append-byte`: int -> stream
- `append-byte-hex`: int -> stream
  - textual representation in hex, no '0x' prefix

- `write-int`: int -> stream
  - write number to stream
- `write-int32-hex`: int -> stream
  - textual representation in hex, including '0x' prefix
- `write-int32-hex-buffered`: int -> buffered-file
- `write-int32-decimal`
- `write-int32-decimal-buffered`
- `write-buffered`: string -> buffered-file
- `write-slice-buffered`: slice -> buffered-file
- `flush`: buffered-file
- `write-byte-buffered`: int -> buffered-file
- `write-byte-buffered`: int -> buffered-file
  - textual representation in hex, no '0x' prefix
- `print-int32-buffered`: int -> buffered-file
  - textual representation in hex, including '0x' prefix

- `write-grapheme`: grapheme -> stream
- `to-grapheme`: code-point -> grapheme

- `write-float-decimal-approximate`: float, precision: int -> stream

- `new-buffered-file`
- `populate-buffered-file-containing`: string -> buffered-file

Unless otherwise states, writes to a stream will abort the entire program if
there isn't enough room in the destination stream.

#### reading from disk

- `read`: file -> stream
  - Can also be used to cat one stream into another.
  - Will silently stop reading when destination runs out of space.
- `read-byte-buffered`: buffered-file -> byte
- `read-line-buffered`: buffered-file -> stream
  - Will abort the entire program if there isn't enough room.

- `read-grapheme`: stream -> grapheme
- `read-grapheme-buffered`: buffered-file -> grapheme

- `read-lines`: buffered-file -> array of strings

#### non-IO operations on streams

- `populate-stream`: allocates space in a stream for `n` objects of the
  appropriate type.
  - Will abort the entire program if `n*b` requires more than 32 bits.
- `clear-stream`: resets everything in the stream to `0` (except its `size`).
- `rewind-stream`: resets the read index of the stream to `0` without modifying
  its contents.

#### reading/writing hex representations of integers

- `is-hex-int?`: slice -> boolean
- `parse-hex-int`: string -> int
- `parse-hex-int-from-slice`: slice -> int
- `is-hex-digit?`: byte -> boolean

- `parse-array-of-ints`
- `parse-array-of-decimal-ints`

#### printing to screen

All screen primitives require a screen object, which can be either the real
screen on the computer or a fake screen for tests. Mu supports a subset of
Unix terminal properties supported by almost all modern terminal emulators.

- `enable-screen-type-mode` (default)
- `enable-screen-grid-mode`

- `clear-screen`
- `screen-size`

- `move-cursor`
- `hide-cursor`
- `show-cursor`

- `print-string`: string -> screen
- `print-stream`
- `print-grapheme`
- `print-code-point`
- `print-int32-hex`
- `print-int32-decimal`
- `print-int32-decimal-right-justified`
- `print-array-of-ints-in-decimal`

- `print-float-hex`
- `print-float-decimal-approximate`: up to some precision

Printing to screen is stateful, and preserves formatting unless explicitly
manipulated.

- `reset-formatting`
- `start-color`: adjusts foreground and background
- `start-bold`
- `start-underline`
- `start-reverse-video`
- `start-blinking`

Assertions for tests:

- `screen-grapheme-at`
- `screen-color-at`
- `screen-background-color-at`
- `screen-bold-at?`
- `screen-underline-at?`
- `screen-reverse-at?`
- `screen-blink-at?`

- `check-screen-row`
- `check-screen-row-from`
- `check-screen-row-in-color`
- `check-screen-row-in-color-from`
- `check-screen-row-in-background-color`
- `check-screen-row-in-background-color-from`
- `check-screen-row-in-bold`
- `check-screen-row-in-bold-from`
- `check-screen-row-in-underline`
- `check-screen-row-in-underline-from`
- `check-screen-row-in-reverse`
- `check-screen-row-in-reverse-from`
- `check-screen-row-in-blinking`
- `check-screen-row-in-blinking-from`

#### keyboard

- `enable-keyboard-type-mode`: process keystrokes on `enter` (default mode)
- `read-line-from-real-keyboard`

- `enable-keyboard-immediate-mode`: process keystrokes as they're typed
- `read-key-from-real-keyboard`

#### tokenization

from a stream:
- `next-token`: stream, delimiter byte -> slice
- `skip-chars-matching`: stream, delimiter byte
- `skip-chars-not-matching`: stream, delimiter byte

from a slice:
- `next-token-from-slice`: start, end, delimiter byte -> slice
  - Given a slice and a delimiter byte, returns a new slice inside the input
    that ends at the delimiter byte.

- `skip-chars-matching-in-slice`: curr, end, delimiter byte -> new-curr (in `eax`)
- `skip-chars-not-matching-in-slice`:  curr, end, delimiter byte -> new-curr (in `eax`)

#### file system

- `open`: filename, write? -> buffered-file
