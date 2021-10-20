# A slow tour through Mu software on x86 computers

[Mu](https://github.com/akkartik/mu) shrinks all the software in a computer
until it can (in principle) fit in a single head. Sensible error messages with
as little code as possible, starting all the way from your (x86) processor's
instruction set. Everything easy to change to your needs
([habitable](http://akkartik.name/post/habitability)), everything easy to
check up on ([auditable](http://akkartik.name/post/neighborhood)).

This page is a guided tour through Mu's Readme and reference documentation.
We'll start out really slow and gradually accelerate as we build up skills. By
the end of it all, I hope you'll be able to program your processor to run some
small graphical programs. The programs will only use a small subset of your
computer's capabilities; there's still a lot I don't know and therefore cannot
teach. However, the programs will run on a _real_ processor without needing
any other intermediary software.

_Prerequisites_

You will need:

* A computer with an x86 processor running Linux. We're going to slowly escape
  Linux, but we'll need it at the start. Mu works on other platforms, but be
  warned that things will be _much_ (~20x) slower.
* Some fluency in typing commands at the terminal and interpreting their
  output.
* Fluency with some text editor. Things like undo, copying and pasting text,
  and saving work in files. A little experience programming in _some_ language
  is also handy.
* [Git](https://git-scm.com) for version control.
* [QEMU](https://www.qemu.org) for emulating a processor without Linux.
* Basic knowledge of number bases, and the difference between decimal and
  hexadecimal numbers.

If you have trouble with any of this, [I'm always nearby and available to
answer questions](http://akkartik.name/contact). The prerequisites are just
things I haven't figured out how to explain yet. In particular, I want this
page to be accessible to people who are in the process of learning
programming, but I'm sure it isn't good enough yet for that. Ask me questions
and help me improve it.

# Task 1: getting started

Open a terminal and run the following commands to prepare Mu on your computer:

```
git clone https://github.com/akkartik/mu
cd mu
```

Run a small program to start:

```
./translate apps/ex5.mu
qemu-system-i386 code.img
```

If you aren't on Linux, the command for creating `code.img` will be slightly
different:

```
./translate_emulated apps/ex5.mu
qemu-system-i386 code.img
```

Either way, you should see this:

<img alt='screenshot of hello world on the Mu computer' src='task1.png'>

If you have any trouble at this point, don't waste _any_ time thinking about
it. Just [get in touch](http://akkartik.name/contact).

(You can look at `apps/ex5.mu` at this point if you like. It's just a few
lines long. But don't worry if it doesn't make much sense.)

# Task 2: running tests

Here's a new program to run:

```
./translate tutorial/task2.mu
qemu-system-i386 code.img
```

(As before, I'll leave you to substitute `translate` with `translate_emulated`
if you're not on Linux.)

This time the screen will look like this:

<img alt='screenshot of failing test on the Mu computer' src='task2.png'>

Each of the dots is a _test_, a little self-contained and automated program
run with an expected result. Mu comes with a lot of tests, and it always runs
all tests before it runs any program. You may have missed the dots when you
ran Task 1 because there were no failures. They were printed on the screen and
then immediately erased. In Task 2, however, we've deliberately included a
failing test. When any tests fail, Mu will immediately stop, showing you
messages from failing tests and implicitly asking you to first fix them.

(Don't worry just yet about what the message in the middle of all the dots means.)

# Task 3: configure your text editor

So far we haven't used a text editor yet, but we will now be starting to do
so. Before we do, it's worth spending a little bit of time setting your
preferred editor up to be a little more ergonomic. Mu comes with _syntax
highlighting_ settings for a few common text editors in the `editor/`
sub-directory. If you don't see your text editor there, or if you don't know
what to do with those files, [get in touch!](http://akkartik.name/contact)
Here's what my editor (Vim) looks like with these settings on the program of
Task 1:

<img alt='Vim text editor rendering some colors in a Mu program' src='task3.png'>

It's particularly useful to highlight _comments_ which the computer ignores
(everything on a line after a `#` character) and _strings_ within `""` double
quotes.

# Task 4: your first Mu statement

Mu is a statement-oriented language. Read the first section of the [Mu syntax
description](https://github.com/akkartik/mu/blob/main/mu.md) to learn a little
bit about it.

Here's a skeleton of a Mu function that's missing a single statement.

```
fn the-answer -> _/eax: int {
  var result/eax: int <- copy 0
  # insert your statement below {

  # }
  return result
}
```

Try running it now:
```
./translate tutorial/task4.mu
qemu-system-i386 code.img
```

(As before, I'll leave you to substitute `translate` with `translate_emulated`
if you're not on Linux.)

You should see a failing test that looks something like this:

<img alt='screenshot of the initial (failing) state of task 4' src='task4-initial.png'>

Open `tutorial/task4.mu` in your text editor. Think about how to add a line
between the `{}` lines to make `the-answer` return 42. Rerun the above
commands. You'll know you got it right all the tests pass, i.e. when the rows
of dots and text above are replaced by an empty screen.

Don't be afraid to run the above commands over and over again as you try out
different solutions. Here's a way to run them together so they're easy to
repeat.

```
./translate tutorial/task4.mu  &&  qemu-system-i386 code.img
```

In programming there is no penalty for making mistakes, and once you arrive at
the correct solution you have it forever. As always, [feel free to ping me and
ask questions or share your experience](http://akkartik.name/contact).

One gotcha to keep in mind is that numbers in Mu must always be in hexadecimal
notation, starting with `0x`. Use a calculator on your computer or phone to
convert 42 to hexadecimal, or [this page on your web browser](http://akkartik.github.io/mu/tutorial/converter.html).
