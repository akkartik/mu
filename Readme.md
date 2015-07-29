**Mu: making programs easier to understand in the large**

Imagine a world where you can:

1. think of a tiny improvement to a program you use, clone its sources,
orient yourself on its organization and make your tiny improvement, all in a
single afternoon.

2. Record your program as it runs, and easily convert arbitrary logs of runs
into reproducible automatic tests.

3. Answer arbitrary what-if questions about a codebase by trying out changes
and seeing what tests fail, confident that *every* scenario previous authors
have considered has been encoded as a test.

4. Run first simple and successively more complex versions to stage your
learning.

I think all these abilities might be strongly correlated; not only are they
achievable with a few common concepts, but you can't easily attack one of them
without also chasing after the others. The core mechanism enabling them all is
recording manual tests right after the first time you perform them:

* keyboard input
* printing to screen
* website layout
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

([More details.](http://akkartik.name/about))

**Taking Mu for a spin**

Mu is currently implemented in C++ and requires a unix-like environment. It's
been tested on ubuntu 14.04 with recent versions of gcc and clang, but should
work with earlier versions going quite far back. It has no other dependencies
that aren't taken for granted in unix. In spite of needing C++ it uses no
advanced features and is designed to eventually bootstrap using an assembler
written directly in machine code. Currently you build it like so:

```shell
  $ cd mu
  $ ./mu
```

Running mu will always recompile it if necessary. In this case it has no other
work to do, so it'll show you a hopefully helpful message after it's done
compiling.

As a sneak peek, here's how you compute factorial in Mu:

![code example](html/factorial.png)

Mu functions or 'recipes' are lists of instructions, one to a line. Each
instruction operates on some *ingredients* and returns some *products*.

```
  [products] <- instruction [ingredients]
```

Result and ingredient *reagents* have to be variables. But you can have any
number of them. In particular you can have any number of products. For example,
you can perform integer division as follows:

```
  quotient:number, remainder:number <- divide-with-remainder 11, 3
```

Each reagent can provide a name as well as its type separated by a colon. You
only have to specify the type the first time you mention a name, but you can
be more explicit if you choose. Types can be multiple words, like:

```nim
  x:array:number:3  # x is an array of 3 numbers
  y:list:number  # y is a list of numbers
```

Recipes load their ingredients from their caller using the *next-ingredient*
instruction, and return products using *reply*.

Try out the factorial program now:

```shell
  $ ./mu factorial.mu
  result: 120  # factorial of 5
```

You can also run its unit tests:

```shell
  $ ./mu test factorial.mu
```

Here's what one of the tests inside `factorial.mu` looks like:

![test example](html/factorial-test.png)

Every test conceptually spins up a really lightweight virtual machine, so you
can do things like check the value of specific locations in memory. You can
also print to screen and check that the screen contains what you expect at the
end of a test. For example, `chessboard.mu` checks the initial position of a
game of chess (delimiting the edges of the screen with periods):

![screen test](html/chessboard-test.png)

Similarly you can fake the keyboard to pretend someone typed something:

```
  assume-keyboard [a2-a4]
```

As we add a file system, graphics, audio, network support and so on, we'll
augment scenarios with corresponding abilities to use them inside tests.

---

The name of a reagent is for humans, but what the computer needs to access it is
its address. Mu maps names to addresses for you like in other languages, but
in a more transparent, lightweight, hackable manner. This instruction:

```nim
  z:number <- add x:number, y:number
```

might turn into this:

```nim
  3:number <- add 1:number, 2:number
```

You shouldn't rely on the specific address Mu chooses for a variable, but it
will be unique (other variables won't clobber it) and consistent (all mentions
of the name will map to the same address inside a function).

Things get more complicated when your functions call other functions. Mu
doesn't preserve uniqueness of addresses across functions, so you need to
organize your names into spaces. At the start of each function (like
`factorial` above), set its *default space*:

  ```nim
    new-default-space
  ```

Without this line, all variables in the function will be *global*, something
you rarely want. (Luckily, this is also the sort of mistake that will be
easily caught by tests. Later we'll automatically generate this boilerplate.)
*With* this line, all addresses in your function will by default refer to one
of the 30 slots inside this local space. (If you need more, mu will complain.)

Spaces can do more than just implement local variables. You can string them
together, pass them around, return them from functions, share them between
parallel routines, and much else. However, any function receiving a space has
to know the names and types of variables in it, so any instruction should
always receive spaces created by the same function, no matter how many times
it's run. (If you're familiar with lexical scope, this constraint is
identical to it.)

To string two spaces together, write one into slot 0 of the other. This
instruction chains a space received from its caller:

```nim
  0:address:array:location <- next-ingredient
```

Once you've chained spaces together, you can access variables in them by
adding a 'space' property:

```nim
  3:number/space:1
```

This reagent is the integer in slot 3 of the space chained in slot 0 of the
default space. We usually call it slot 3 in the 'next space'. `/space:2` would
be the next space of the next space, and so on.

See `counters.mu` for an example of managing multiple accumulators at once
without allowing them to clobber each other. This is a classic example of the
sorts of things closures and objects are useful for in other languages. Spaces
in Mu provide the same functionality.

---

You can append arbitrary properties to reagents besides types and spaces. Just
separate them with slashes.

```nim
  x:array:number:3/uninitialized
  y:string/tainted:yes
  z:list:number/assign-once:true/assigned:false
```

Most properties are meaningless to Mu, and it'll silently skip them when
running, but they are fodder for *meta-programs* to check or modify your
programs, a task other languages typically hide from their programmers. For
example, where other programmers are restricted to the checks their type
system permits and forces them to use, you'll learn to create new checks that
make sense for your specific program. If it makes sense to perform different
checks in different parts of your program, you'll be able to do that.

To summarize: Mu instructions have multiple ingredient and product reagents.
Values can have multiple rows separated by slashes, and rows can have multiple
columns separated by colons. The address of a reagent is always in the very
first column of the first row of its 'table'. You can visualize the last
example above as:

```
  z           : list : integer  /
  assign-once : true            /
  assigned    : false
```

---

An alternative way to define factorial is by inserting *labels* and later
inserting code at them.

```nim
  recipe factorial [
    new-default-space
    n:number <- next-ingredient
    {
      +base-case:
    }
    +recursive-case:
  ]

  after +base-case [
    # if n=0 return 1
    zero?:boolean <- equal n:number, 0
    break-unless zero?:boolean
    reply 1
  ]

  after +recursive-case [
    # return n * factorial(n-1)
    x:number <- subtract n:number, 1
    subresult:number <- factorial x:number
    result:number <- multiply subresult:number, n:number
    reply result:number
  ]
```

(You'll find this version in `tangle.mu`.)

Any instruction without ingredients or products that starts with a
non-alphanumeric character is a label. By convention we use '+' to indicate
label names.

This is a good time to point out that `{` and `}` are also just labels in Mu
syntax, and that `break` and `loop` get rewritten as jumps to just after the
enclosing `}` and `{` respectively. This gives us a simple sort of structured
programming without adding complexity to the parser -- Mu functions remain
just flat lists of instructions.

---

Another example, this time with concurrency.

```
  recipe main [
    start-running thread2:recipe
    {
      $print 34
      loop
    }
  ]

  recipe thread2 [
    {
      $print 35
      loop
    }
  ]
```

```shell
  $ ./mu fork.mu
```

Notice that it repeatedly prints either '34' or '35' at random. Hit ctrl-c to
stop.

Yet another example forks two 'routines' that communicate over a channel:

```shell
  $ ./mu channel.mu
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

Channels are the unit of synchronization in Mu. Blocking on channels are the
only way tasks can sleep waiting for results. The plan is to do all I/O over
channels that wait for data to return.

Routines are expected to communicate purely by message passing, though nothing
stops them from sharing memory since all routines share a common address
space. However, idiomatic Mu will make it hard to accidentally read or clobber
random memory locations. Bounds checking is baked deeply into the semantics,
and pointer arithmetic will be mostly forbidden (except inside the memory
allocator and a few other places).

---

If you're still reading, here are some more things to check out:

a) Look at the [chessboard program](http://akkartik.github.io/mu/html/chessboard.mu.html)
for a more complex example where I write tests showing blocking reads from the
keyboard and what gets printed to the screen -- things we don't typically
associate with automated tests.

b) Try skimming the [colorized source code](http://akkartik.github.io/mu). I'd
like it to eventually be possible to get a pretty good sense for how things
work just by skimming the files in order, skimming the top of each file and
ignoring details lower down. I'd love to hear feedback about how successful my
efforts are.

c) Try running the tests:

```shell
  $ ./mu test
```

You might also want to peek in the `.traces` directory, which automatically
includes logs for each test showing you just how it ran on my machine. If Mu
eventually gets complex enough that you have trouble running examples, these
logs might help figure out if my system is somehow different from yours or if
I've just been insufficiently diligent and my documentation is out of date.

The immediate goal of Mu is to build up towards an environment for parsing and
visualizing these traces in a hierarchical manner, and to easily turn traces
into reproducible tests by flagging inputs entering the log and outputs
leaving it. The former will have to be faked in, and the latter will want to
be asserted on, to turn a trace into a test.

**Credits**

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
  structured documents.
