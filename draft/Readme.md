_(Draft of a new iteration of the project's documentation.)_

# Mu: a human-scale computer

Mu is a minimal-dependency hobbyist computing stack (everything above the
processor and OS kernel).

Mu is not designed to operate in large clusters providing services for
millions of people. Mu is designed for _you_, to run one computer. (Or a few.)
Running the code you want to run, and nothing else.

  ```sh
  $ git clone https://github.com/akkartik/mu
  $ cd mu
  $ ./subx  # requires C++ and Linux
  ```

[![Build Status](https://api.travis-ci.org/akkartik/mu.svg?branch=master)](https://travis-ci.org/akkartik/mu)

There's a minimal number of layers of abstraction, every layer depends
strictly on lower layers, and all levels have thorough automated tests, from
machine code up.

## Goals

In priority order:

* [Reward curiosity.](http://akkartik.name/about)
  * Easy to build, easy to run. [Minimal dependencies](https://news.ycombinator.com/item?id=16882140#16882555),
    so that installation is always painless.
  * All design decisions comprehensible to a single individual. (On demand.)
  * All design decisions comprehensible without needing to talk to anyone.
    (I always love talking to you, but I try hard to make myself redundant.)
  * [A globally comprehensible _codebase_ rather than locally clean code.](http://akkartik.name/post/readable-bad)
  * Clear error messages over expressive syntax.
* Safe.
  * Thorough test coverage. If you break something you should immediately see
    an error message. If you can manually test for something you should be
    able to write an automated test for it.
  * Memory leaks over memory corruption.
* Teach the computer bottom-up.

## Non-goals

* Efficiency. Clear programs over fast programs.
* Portability. Runs on any computer as long as it's x86.
* Compatibility. The goal is to get off mainstream stacks, not to perpetuate
  them. Sometimes the right long-term solution is to [bump the major version number](http://akkartik.name/post/versioning).
* Syntax. Mu code is meant to be comprehended by [running, not just reading](http://akkartik.name/post/comprehension).

## What works so far

Mu contains a type-safe, memory-safe and testable language where most statements
map directly to a single CPU instruction. This language is built entirely in a
notation called SubX for a subset of the x86 instruction set. The language is
designed to be easy to implement in glorified machine code.

(Some features will require multiple instructions for a statement: local
variable definitions, array indexing with bounds checking, dereferencing heap
allocations while protecting against freed memory.)

### SubX

Here's a quick rundown of SubX's capabilities from the outside. For more
details on the internal experience of the SubX notation itself, see [SubX.md](SubX.md).

You can generate tiny zero-dependency ELF binaries with it.

  ```sh
  $ ./ntranslate init.linux examples/ex1.subx -o examples/ex1
  $ ./examples/ex1
  $ echo $?
  42
  ```

You can run the generated binaries on an interpreter/VM for better error
messages.

  ```sh
  $ ./subx run examples/ex1  # on Linux or BSD or Mac
  $ echo $?
  42
  ```

Emulated runs can generate a trace that permits [time-travel debugging](https://github.com/akkartik/mu/blob/master/browse_trace/Readme.md).

  ```sh
  $ ./subx --debug translate init.linux examples/factorial.subx -o examples/factorial
  saving address->label information to 'labels'
  saving address->source information to 'source_lines'

  $ ./subx --debug --trace run examples/factorial
  saving trace to 'last_run'

  $ ./browse_trace/browse_trace last_run  # text-mode debugger UI
  ```

You can write tests for your programs. The entire stack is thoroughly covered
by automated tests. SubX's tagline: tests before syntax.

  ```sh
  $ ./subx test
  $ ./subx run apps/factorial test
  ```

You can package up SubX binaries with the minimal hobbyist OS [Soso](https://github.com/ozkl/soso)
and run them on Qemu. (Requires graphics and sudo access. Currently doesn't
work on a cloud server.)

  ```sh
  # dependencies
  $ sudo apt install util-linux nasm xorriso  # maybe also dosfstools and mtools
  # package up a "hello world" program with a third-party kernel into mu_soso.iso
  # requires sudo
  $ ./gen_soso_iso init.soso examples/ex6.subx
  # try it out
  $ qemu-system-i386 -cdrom mu_soso.iso
  ```

You can also package up SubX binaries with a Linux kernel and run them on
either Qemu or [a cloud server that supports custom images](http://akkartik.name/post/iso-on-linode).
(Takes 12 minutes with 8GB RAM. Requires 12 million LoC of C for the Linux
kernel; that number will gradually go down.)

  ```sh
  $ sudo apt install build-essential flex bison wget libelf-dev libssl-dev xorriso
  $ ./gen_linux_iso init.linux examples/ex6.subx
  $ qemu-system-x86_64 -m 256M -cdrom mu.iso -boot d
  ```

## Conclusion

The hypothesis of Mu and SubX is that designing the entire system to be
testable from day 1 and from the ground up would radically impact the culture
of the eco-system in a way that no bolted-on tool or service at higher levels
can replicate:

* Tests would make it easier to write programs that can be easily understood
  by newcomers.

* More broad-based understanding would lead to more forks.

* Tests would make it easy to share code across forks. Copy the tests over,
  and then copy code over and polish it until the tests pass. Manual work, but
  tractable and without major risks.

* The community would gain a diversified portfolio of forks for each program,
  a “wavefront” of possible combinations of features and alternative
  implementations of features. Application writers who wrote thorough tests
  for their apps (something they just can’t do today) would be able to bounce
  around between forks more easily without getting locked in to a single one
  as currently happens.

* There would be a stronger culture of reviewing the code for programs you use
  or libraries you depend on. [More eyeballs would make more bugs shallow.](https://en.wikipedia.org/wiki/Linus%27s_Law)

To falsify these hypotheses, here's a roadmap of the next few planned features:

* Testable, dependency-injected vocabulary of primitives
  - Streams: `read()`, `write()`. (✓)
  - `exit()` (✓)
  - Client-like non-blocking socket/file primitives: `load`, `save`
  - Concurrency, and a framework for testing blocking code
  - Server-like blocking socket/file primitives

* Higher-level notations. Like programming languages, but with thinner
  implementations that you can -- and are expected to! -- modify.
  - syntax for addressing modes: `%reg`, `*reg`, `*(reg+disp)`,
    `*(reg+reg+disp)`, `*(reg+reg<<n + disp)`
  - function calls in a single line, using addressing modes for arguments
  - syntax for controlling a type checker, like [the mu1 prototype](https://github.com/akkartik/mu1).
  - a register allocation _verifier_. Programmer provides registers for
    variables; verifier checks that register reads are for the same type that
    was last written -- across all control flow paths.

* Gradually streamline the bundled kernel, stripping away code we don't need.

---

If you're still reading, here are some more things to check out:

a) Try running the tests:

  ```shell
  $ ./test_apps
  ```

b) Check out the online help. Try typing just `./subx`, and then `./subx
help`.

c) Familiarize yourself with `./subx help opcodes`. You'll spend a lot of time
with it. (It's also [in this repo](https://github.com/akkartik/mu/blob/master/opcodes).)
[Here](https://lobste.rs/s/qglfdp/subx_minimalist_assembly_language_for#c_o9ddqk)
are some tips on my setup for quickly finding the right opcode for any
situation from within Vim.

d) Try working on [the starter exercises](https://github.com/akkartik/mu/pulls)
(labelled `hello`).

## Credits

Mu builds on many ideas that have come before, especially:

- [Peter Naur](http://akkartik.name/naur.pdf) for articulating the paramount
  problem of programming: communicating a codebase to others;
- [Christopher Alexander](http://www.amazon.com/Notes-Synthesis-Form-Harvard-Paperbacks/dp/0674627512)
  and [Richard Gabriel](http://dreamsongs.net/Files/PatternsOfSoftware.pdf) for
  the intellectual tools for reasoning about the higher order design of a
  codebase;
- Unix and C for showing us how to co-evolve language and OS, and for teaching
  the (much maligned, misunderstood and underestimated) value of concise
  *implementation* in addition to a clean interface;
- Donald Knuth's [literate programming](http://www.literateprogramming.com/knuthweb.pdf)
  for liberating "code for humans to read" from the tyranny of compiler order;
- [David Parnas](http://www.cs.umd.edu/class/spring2003/cmsc838p/Design/criteria.pdf)
  and others for highlighting the value of separating concerns and stepwise
  refinement;
- [Lisp](http://www.paulgraham.com/rootsoflisp.html) for showing the power of
  dynamic languages, late binding and providing the right primitives *a la
  carte*, especially lisp macros;
- The folklore of debugging by print and the trace facility in many lisp
  systems;
- Automated tests for showing the value of developing programs inside an
  elaborate harness;
- [Python doctest](http://docs.python.org/2/library/doctest.html) for
  exemplifying interactive documentation that doubles as tests;
- [ReStructuredText](https://en.wikipedia.org/wiki/ReStructuredText)
  and [its antecedents](https://en.wikipedia.org/wiki/Setext) for showing that
  markup can be clean;
- BDD for challenging us all to write tests at a higher level;
- JavaScript and CSS for demonstrating the power of a DOM for complex
  structured documents;
- Rust for demonstrating that a system-programming language can be safe;
- Forth for demonstrating that ergonomics don't require grammar; and
- [Minimal Linux Live](http://minimal.linux-bg.org) for teaching how to create
  a bootable disk image.
- [Soso](https://github.com/ozkl/soso), a tiny hackable OS.

## Coda

* [Some details on the unconventional organization of this project.](http://akkartik.name/post/four-repos)
* Previous prototypes: [mu0](https://github.com/akkartik/mu0), [mu1](https://github.com/akkartik/mu1).
