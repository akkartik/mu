## Reference documentation on available primitives

### Data Structures

For memory safety, the following data structures are opaque and only modified
using functions described further down. I still find it useful to understand
how they work under the hood.

- Handles: addresses to objects allocated on the heap. They're augmented with
  book-keeping to guarantee memory-safety, and so cannot be stored in registers.
  See [mu.md](mu.md) for details, but in brief:
    - You need `addr` values to access data they point to.
    - You can't store `addr` values in other types. They're temporary.
    - You can store `handle` values in other types.
    - To convert `handle` to `addr`, use `lookup`.
    - Reclaiming memory (currently unimplemented) invalidates all `addr`
      values.

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

  By default, writes to a stream abort if it's full. Reads to a stream abort
  if it's empty.

- Graphemes: 32-bit fragments of utf-8 that encode a single Unicode code-point.
- Code-points: 32-bit integers representing a Unicode character.

### Functions

The most useful functions from 400.mu and later .mu files. Look for definitions
(using `ctags`) to see type signatures.

- `abort`: print a message in red on the bottom left of the screen and halt

#### assertions for tests

- `check`: fails current test if given boolean is false (`= 0`).
- `check-not`: fails current test if given boolean isn't false (`!= 0`).
- `check-ints-equal`: fails current test if given ints aren't equal.
- `check-strings-equal`: fails current test if given strings have different bytes.
- `check-stream-equal`: fails current test if stream's data doesn't match
  string in its entirety. Ignores the stream's read index.
- `check-array-equal`: fails if an array's elements don't match what's written
  in a whitespace-separated string.
- `check-next-stream-line-equal`: fails current test if next line of stream
  until newline doesn't match string.

#### predicates

- `handle-equal?`: checks if two handles point at the identical address. Does
  not compare payloads at their respective addresses.

- `array-equal?`: checks if two arrays (of ints only for now) have identical
  elements.

- `string-equal?`: compares two strings.
- `stream-data-equal?`: compares a stream with a string.
- `next-stream-line-equal?`: compares with string the next line in a stream, from
  `read` index to newline.

- `slice-empty?`: checks if the `start` and `end` of a slice are equal.
- `slice-equal?`: compares a slice with a string.
- `slice-starts-with?`: compares the start of a slice with a string.

- `stream-full?`: checks if a write to a stream would abort.
- `stream-empty?`: checks if a read from a stream would abort.

#### arrays

- `populate`: allocates space for `n` objects of the appropriate type.
- `copy-array`: allocates enough space and writes out a copy of an array of
  some type.
- `slice-to-string`: allocates space for an array of bytes and copies the
  slice into it.

#### streams

- `populate-stream`: allocates space in a stream for `n` objects of the
  appropriate type.
- `write-to-stream`: writes arbitrary objects to a stream of the appropriate
  type.
- `read-from-stream`: reads arbitrary objects from a stream of the appropriate
  type.
- `stream-to-array`: allocates just enough space and writes out a stream's
  data between its read index (inclusive) and write index (exclusive).

- `clear-stream`: resets everything in the stream to `0` (except its `size`).
- `rewind-stream`: resets the read index of the stream to `0` without modifying
  its contents.

- `write`: writes a string into a stream of bytes. Doesn't support streams of
  other types.
- `try-write`: writes a string into a stream of bytes if possible. Doesn't
  support streams of other types.
- `write-stream`: concatenates one stream into another.
- `write-slice`: writes a slice into a stream of bytes.
- `append-byte`: writes a single byte into a stream of bytes.
- `append-byte-hex`: writes textual representation of lowest byte in hex to
  a stream of bytes. Does not write a '0x' prefix.
- `read-byte`: reads a single byte from a stream of bytes.
- `read-grapheme`: reads a single unicode grapheme (up to 4 bytes containing a
  single code-point encoded in utf-8) from a stream of bytes.

#### reading/writing hex representations of integers

- `write-int32-hex`
- `hex-int?`: checks if a slice contains an int in hex. Supports '0x' prefix.
- `parse-hex-int`: reads int in hex from string
- `parse-hex-int-from-slice`: reads int in hex from slice
- `parse-array-of-ints`: reads in multiple ints in hex, separated by whitespace.
- `hex-digit?`: checks if byte is in [0, 9] or [a, f] (lowercase only)

- `write-int32-decimal`
- `parse-decimal-int`
- `parse-decimal-int-from-slice`
- `parse-decimal-int-from-stream`
- `parse-array-of-decimal-ints`
- `decimal-digit?`: checks if byte is in [0, 9]

#### printing to screen

`pixel-on-real-screen` draws a single pixel in one of 256 colors.

All text-mode screen primitives require a screen object, which can be either
the real screen on the computer or a fake screen for tests.

The real screen on the Mu computer can currently display only ASCII characters,
though it's easy to import more of the font. There is only one font, and it's
mostly fixed-width, with graphemes being either 8 or 16 pixels wide.

- `draw-grapheme`: draws a single grapheme at a given coordinate, with given
  foreground and background colors.
- `render-grapheme`: like `draw-grapheme` and can also handle newlines
  assuming text is printed left-to-right, top-to-bottom.
- `draw-code-point`
- `clear-screen`

- `draw-text-rightward`: draws a single line of text, stopping when it reaches
  either the provided bound or the right screen margin.
- `draw-stream-rightward`
- `draw-text-rightward-over-full-screen`: does not provide a bound.
- `draw-text-wrapping-right-then-down`: draws multiple lines of text on screen
  with simplistic word-wrap (no hyphenation) within (x, y) bounds.
- `draw-stream-wrapping-right-then-down`
- `draw-text-wrapping-right-then-down-over-full-screen`
- `draw-int32-hex-wrapping-right-then-down`
- `draw-int32-hex-wrapping-right-then-down-over-full-screen`
- `draw-int32-decimal-wrapping-right-then-down`
- `draw-int32-decimal-wrapping-right-then-down-over-full-screen`

Similar primitives for writing text top-to-bottom, left-to-right.

- `draw-text-downward`
- `draw-stream-downward`
- `draw-text-wrapping-down-then-right`
- `draw-stream-wrapping-down-then-right`
- `draw-text-wrapping-down-then-right-over-full-screen`
- `draw-int32-hex-wrapping-down-then-right`
- `draw-int32-hex-wrapping-down-then-right-over-full-screen`
- `draw-int32-decimal-wrapping-down-then-right`
- `draw-int32-decimal-wrapping-down-then-right-over-full-screen`

Screens remember the current cursor position.

- `cursor-position`
- `set-cursor-position`
- `draw-grapheme-at-cursor`
- `draw-code-point-at-cursor`
- `draw-cursor`: highlights the current position of the cursor. Programs must
  pass in the grapheme to draw at the cursor position, and are responsible for
  clearing the highlight when the cursor moves.
- `move-cursor-left`, `move-cursor-right`, `move-cursor-up`, `move-cursor-down`.
  These primitives always silently fail if the desired movement would go out
  of screen bounds.
- `move-cursor-to-left-margin-of-next-line`
- `move-cursor-rightward-and-downward`: move cursor one grapheme to the right

- `draw-text-rightward-from-cursor`
- `draw-text-wrapping-right-then-down-from-cursor`
- `draw-text-wrapping-right-then-down-from-cursor-over-full-screen`
- `draw-int32-hex-wrapping-right-then-down-from-cursor`
- `draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen`
- `draw-int32-decimal-wrapping-right-then-down-from-cursor`
- `draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen`

- `draw-text-wrapping-down-then-right-from-cursor`
- `draw-text-wrapping-down-then-right-from-cursor-over-full-screen`

Assertions for tests:

- `check-screen-row`: compare a screen from the left margin of a given row
  index with a string. The row index counts downward from 0 at the top of the
  screen. String can be smaller or larger than a single row, and defines the
  region of interest. Strings longer than a row wrap around to the left margin
  of the next screen row. Currently assumes text is printed left-to-right on
  the screen.
- `check-screen-row-from`: compare a fragment of a screen (left to write, top
  to bottom) starting from a given (x, y) coordinate with an expected string.
  Currently assumes text is printed left-to-right and top-to-bottom on the
  screen.
- `check-screen-row-in-color`: like `check-screen-row` but:
  - also compares foreground color
  - ignores screen locations where the expected string contains spaces
- `check-screen-row-in-color-from`
- `check-screen-row-in-background-color`
- `check-screen-row-in-background-color-from`
- `check-background-color-in-screen-row`: unlike previous functions, this
  doesn't check screen contents, only background color. Ignores background
  color where expected string contains spaces, and compares background color
  where expected string does not contain spaces. Never compares the character
  at any screen location.
- `check-background-color-in-screen-row-from`

#### events

`read-key` reads a single key from the keyboard and returns it if it exists.
Returns 0 if no key has been pressed.

`read-mouse-event` returns a recent change in x and y coordinate.

Mu doesn't currently support interrupt-based mouse events.

#### persistent storage

`load-sector` synchronously reads a single _sector_ from a _disk_ of persistent
storage. The disk must follow the ATA specification with a 28-bit sector
address. Each sector is 512 bytes. Therefore, Mu currently supports ATA hard
disks of up to 128GB capacity.

Similarly, `store-sector` synchronously writes a single sector to disk.

Mu doesn't currently support asynchronous transfers to or from a disk.
