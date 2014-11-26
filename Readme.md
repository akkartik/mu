## Mu: making programs easier to understand in the large

Imagine a world where you can:

1. think of a tiny improvement to a program you use, clone its sources,
orient yourself on its organization and make your tiny improvement, all in a
single afternoon.

2. Record your program as it runs, and easily convert arbitrary logs of runs
into reproducible automatic tests.

3. Answer arbitrary what-if questions about a codebase by trying out changes
and seeing what tests fail, confident that *every* scenario previous authors
have considered has been encoded as a test.

4. Build first simple and successively more complex versions of a program so
you can stage your learning.

I think all these abilities might be strongly correlated; not only are they
achievable with a few common concepts, but you can't easily attack one of them
without also chasing after the others. The core mechanism enabling them all is
recording manual tests right after the first time you perform them:

* keyboard input
* printing to screen
* disk filling up
* performance metrics
* race conditions
* fault tolerance
* ...

I hope to attain this world by creating a comprehensive library of fakes and
hooks for the entire software stack, at all layers of abstraction (programming
language, OS, standard libraries, application libraries).

To reduce my workload and get to a proof-of-concept quickly, this is a very
*alien* software stack. I've stolen ideas from lots of previous systems, but
it's not like anything you're used to. The 'OS' will lack virtual memory, user
accounts, any unprivileged mode, address space isolation, and many other
features.

To avoid building a compiler I'm going to do all my programming in (virtual
machine) assembly. To keep assembly from getting too painful I'm going to
pervasively use one trick: load-time directives to let me order code however I
want, and to write boilerplate once and insert it in multiple places. If
you're familiar with literate programming or aspect-oriented programming,
these directives may seem vaguely familiar. If you're not, think of them as a
richer interface for function inlining.

Trading off notational convenience for tests may seem regressive, but I
suspect high-level languages aren't particularly helpful in understanding
large codebases. No matter how good a notation is, it can only let you see a
tiny fraction of a large program at a time. Logs, on the other hand, can let
you zoom out and take in an entire *run* at a glance, making them a superior
unit of comprehension. If I'm right, it makes sense to prioritize the right
*tactile* interface for working with and getting feedback on large programs
before we invest in the *visual* tools for making them concise.

## Taking mu for a spin

Prerequisites: Racket from http://racket-lang.org

```shell
  $ cd mu
  $ git clone http://github.com/arclanguage/anarki
```

As a sneak peek, here's how you compute factorial in mu:

```lisp
  def factorial [
    ; allocate some space for local variables
    default-scope/scope-address <- new scope/literal 30/literal
    ; receive args from caller in a queue
    n/integer <- arg
    {
      ; if n=0 return 1
      zero?/boolean <- eq n/integer, 0/literal
      break-unless zero?/boolean
      reply 1/literal
    }
    ; return n*factorial(n-1)
    tmp1/integer <- sub n/integer, 1/literal
    tmp2/integer <- factorial tmp1/integer
    result/integer <- mul tmp2/integer, n/integer
    reply result/integer
  ]
```

Programs are lists of instructions, each on a line, sometimes grouped with
brackets. Instructions take the form:

```
  oargs <- OP args
```

Input and output args have to be simple; no sub-expressions are permitted. But
you can have any number of them. In particular, instructions can return
multiple output arguments. For example, you can perform integer division as
follows:

```
  quotient/integer, remainder/integer <- idiv 11/literal, 3/literal
```

Each arg can have any number of bits of metadata like the types above,
separated by slashes. Anybody can write tools to statically analyze or verify
programs using new metadata. Or they can just be documentation; any metadata
the system doesn't recognize gets silently ignored.

Try this program out now:

```shell
  $ ./anarki/arc mu.arc factorial.mu
  result: 120  # factorial of 5
  ...  # ignore the memory dump for now
```

(The code in `factorial.mu` looks different from the idealized syntax above.
We'll get to an actual parser in time.)

---

An alternative way to define factorial is by including *labels*, and later
inserting code at them.

```lisp
  def factorial [
    default-scope/scope-address <- new scope/literal 30/literal
    n/integer <- arg
    {
      base-case
    }
    recursive-case
  ]

  after base-case [
    ; if n=0 return 1
    zero?/boolean <- eq n/integer, 0/literal
    break-unless zero?/boolean
    reply 1/literal
  ]

  after recursive-case [
    ; return n*factorial(n-1)
    tmp1/integer <- sub n/integer, 1/literal
    tmp2/integer <- factorial tmp1/integer
    result/integer <- mul tmp2/integer, n/integer
    reply result/integer
  ]
```

(You'll find this version in `tangle.mu`.)

---

Another example, this time with concurrency.

```shell
  $ ./anarki/arc mu.arc fork.mu
```

Notice that it repeatedly prints either '34' or '35' at random. Hit ctrl-c to
stop.

---

Another example forks two 'routines' that communicate over a channel:

```shell
  $ ./anarki/arc mu.arc channel.mu
  produce: 0
  produce: 1
  produce: 2
  produce: 3
  consume: 0
  consume: 1
  consume: 2
  produce: 4
  consume: 3
  consume: 4

  # The exact order above might shift over time, but you'll never see a number
  # consumed before it's produced.
```

Channels are the unit of synchronization in mu. Blocking on channels are the
only way tasks can sleep waiting for results. The plan is to do all I/O over
channels that wait for data to return.

Routines are expected to communicate purely by message passing, though nothing
stops them from sharing memory since all routines share a common address
space. However, idiomatic mu will make it hard to accidentally read or clobber
random memory locations. Bounds checking is baked deeply into the semantics,
and pointer arithmetic will be mostly forbidden (except inside the memory
allocator and a few other places).

---

Try running the tests:

```shell
  $ ./anark/arc mu.arc.t
  $  # all tests passed!
```

Now start reading `mu.arc.t` to see how it works. A colorized copy of it is at
`mu.arc.t.html` and http://akkartik.github.io/mu.

You might also want to peek in the `.traces` directory, which automatically
includes logs for each test showing you just how it ran on my machine. If mu
eventually gets complex enough that you have trouble running examples, these
logs might help figure out if my system is somehow different from yours or if
I've just been insufficiently diligent and my documentation is out of date.

The immediate goal of mu is to build up towards an environment for parsing and
visualizing these traces in a hierarchical manner, and to easily turn traces
into reproducible tests by flagging inputs entering the log and outputs
leaving it. The former will have to be faked in, and the latter will want to
be asserted on, to turn a trace into a test.

## Credits

Mu builds on many ideas that have come before, especially:

- [Peter Naur](http://alistair.cockburn.us/ASD+book+extract%3A+%22Naur,+Ehn,+Musashi%22)
  for articulating the paramount problem of programming: communicating a
  codebase to others;
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
  dynamic languages, late binding and providing the right primitives a la
  carte, especially lisp macros;
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
  structured documents.
