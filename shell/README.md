### A prototype shell for the Mu computer

Currently runs a tiny subset of Lisp. To build and run it from the top-level:

```
./translate shell/*.mu
qemu-system-i386 disk.img
```

You can type in expressions, hit `ctrl-s` to see their results, and hit `Tab`
to focus on the `...` below and browse how the results were computed. [Here's
a demo.](https://merveilles.town/@akkartik/105790894303047592) The bottom of
the screen shows context-dependent keyboard shortcuts (there's no mouse in the
Mu computer at the moment).

*Known issues*

* There's no way to save to disk.

* Don't press keys too quickly (such as by holding down a key). The Mu
  computer will crash (and often Qemu will segfault).
