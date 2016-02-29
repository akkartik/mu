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

To avoid building a compiler I'm going to do all my programming in (extremely
type-safe) assembly (for an idealized virtual machine that nonetheless will
translate easily to x86). To keep assembly from getting too painful I'm going
to pervasively use one trick: load-time directives to let me order code
however I want, and to write boilerplate once and insert it in multiple
places. If you're familiar with literate programming or aspect-oriented
programming, these directives may seem vaguely familiar. If you're not, think
of them as a richer interface for function inlining.

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
been tested on ubuntu 14.04 on x86, x86\_64 and ARMv7 with recent versions of
gcc and clang. Since it uses no recent language features and has no exotic
dependencies, it should work with most reasonable versions, compilers or
processors.

Running Mu will always recompile it if necessary:

  ```shell
  $ cd mu
  $ ./mu
  ```

As a sneak peek, here's how you perform some simple arithmetic:

  ```nim
  recipe example1 [
    a:number <- add 2, 2
    a <- multiply a, 3
  ]
  ```

But it's easier to read in color:

<img alt='code example' src='html/example1.png' width='188px'>

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
be more explicit if you choose. Types can be multiple words and even arbitrary
trees, like:

  ```nim
  x:array:number:3  # x is an array of 3 numbers
  y:list:number  # y is a list of numbers
  # without syntactic sugar
  {z: (map (address array character) (list number))}   # map from string to list of numbers
  ```

Try out the program now:

  ```shell
  $ ./mu example1.mu
  $
  ```

Not much to see yet, since it doesn't print anything. To print the result, try
adding the instruction `$print a` to the recipe.

---

Here's a second example, of a recipe that can take ingredients:

<img alt='fahrenheit to celsius' src='html/f2c-1.png' width='426px'>

Recipes can specify headers showing their expected ingredients and products,
separated by `->` (unlike the `<-` in *calls*).

Since mu is a low-level VM language, it provides extra control at the cost of
verbosity. Using `local-scope`, you have explicit control over stack frames to
isolate your recipes (in a type-safe manner; more on that below). One
consequence: you have to explicitly `load-ingredients` after you set up the
stack.

An alternative syntax is what the above example is converted to internally:

<img alt='fahrenheit to celsius desugared' src='html/f2c-2.png' width='426px'>

The header gets dropped after checking types at call-sites, and after
replacing `load-ingredients` with explicit instructions to load each
ingredient separately, and to explicitly return products to the caller. After
this translation recipes are once again just lists of instructions.

This alternative syntax isn't just an implementation detail. I've actually
found it easier to teach functions to non-programmers by starting with this
syntax, so that they can visualize a pipe from caller to callee, and see the
names of variables gradually get translated through the pipe.

---

A third example, this time illustrating conditionals:

<img alt='factorial example' src='html/factorial.png' width='330px'>

In spite of how it looks, this is still just a list of instructions.
Internally, the instructions `break` and `loop` get converted to `jump`
instructions to after the enclosing `}` or `{`, respectively.

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

<img alt='test example' src='html/factorial-test.png' width='250px'>

Every test conceptually spins up a really lightweight virtual machine, so you
can do things like check the value of specific locations in memory. You can
also print to screen and check that the screen contains what you expect at the
end of a test. For example, `chessboard.mu` checks the initial position of a
game of chess (delimiting the edges of the screen with periods):

<img alt='screen test' src='html/chessboard-test.png' width='320px'>

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
of the name will map to the same address inside a recipe).

Things get more complicated when your recipes call other recipes. Mu
doesn't preserve uniqueness of addresses across recipes, so you need to
organize your names into spaces. At the start of each recipe (like
`factorial` above), set its *default space*:

  ```nim
  local-scope
  ```

or

  ```nim
  new-default-space
  ```

or

  ```nim
  default-space:address:array:location <- new location:type, 30/capacity
  ```

Without one of these lines, all variables in the recipe will be *global*,
something you rarely want. (Luckily, this is also the sort of mistake that
will be easily caught by tests.) *With* this line, all addresses in your
recipe will by default refer to one of the (30, in the final case) slots
inside this local space. (If you choose the last, most explicit option and
need more than 30 slots, mu will complain asking you to increase capacity.)

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

This reagent is the number in slot 3 of the space chained in slot 0 of the
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

You can imagine each reagent as a table, rows separated by slashes, columns
within a row separated by colons. So the last example above would become
something like this:

  ```
  z           : list   : integer  /
  assign-once : true              /
  assigned    : false
  ```

---

An alternative way to define factorial is by inserting *labels* and later
inserting code at them.

  ```nim
  recipe factorial [
    local-scope
    n:number <- next-ingredient
    {
      <base-case>
    }
    <recursive-case>
  ]

  after <base-case> [
    # if n=0 return 1
    zero?:boolean <- equal n, 0
    break-unless zero?
    reply 1
  ]

  after <recursive-case> [
    # return n * factorial(n-1)
    x:number <- subtract n, 1
    subresult:number <- factorial x
    result:number <- multiply subresult, n
    reply result
  ]
  ```

(You'll find this version in `tangle.mu`.)

Any instruction without ingredients or products that starts with a
non-alphanumeric character is a label. By convention we use '+' to indicate
recipe-local label names you can jump to, and surround in '<>' global label
names for inserting code at.

---

Another example, this time with concurrency.

  ```
  recipe main [
    start-running thread2
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
ignoring details lower down. Tell me how successful my efforts are.

c) Try running the tests:

  ```shell
  $ ./mu test
  ```

You might also want to peek in the `.traces` directory, which automatically
includes logs for each test showing you just how it ran on my machine. If Mu
eventually gets complex enough that you have trouble running examples, these
logs might help figure out if my system is somehow different from yours or if
I've just been insufficiently diligent and my documentation is out of date.

d) Try out the programming environment:

  ```shell
  $ ./mu test edit  # takes about 30s; shouldn't show any failures
  $ ./mu edit
  ```

Screenshot:

<img alt='programming environment' src='html/edit.png' width='720px'>

You write recipes on the left and try them out in *sandboxes* on the right.
Hit F4 to rerun all sandboxes with the latest version of the code. More
details: http://akkartik.name/post/mu. Beware, it won't save your edits by
default. But if you create a sub-directory called `lesson/` under `mu/` it
will. If you turn that directory into a git repo with `git init`, it will also
back up each version you try out.

Once you have a sandbox you can click on its result to mark it as expected:

<img alt='expected result' src='html/expected-result.png' width='180px'>

Later if the result changes it'll be flagged in red to draw your attention to
it. Thus, manually tested sandboxes become reproducible automated tests.

<img alt='unexpected result' src='html/unexpected-result.png' width='180px'>

Another feature: Clicking on the code in a sandbox expands its trace for you
to browse. To add to the trace, use `stash`. For example:

  ```nim
  stash [first ingredient is ], x
  ```

Invaluable for understanding complex control flow without cluttering up the
screen.

The next major milestone on Mu's roadmap is dependency-injected interfaces for
the network and file system.

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
