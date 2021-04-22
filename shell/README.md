### A prototype shell for the Mu computer

Currently runs a tiny subset of Lisp. Steps to run it from the top-level:

1. Build it:
```sh
$ ./translate shell/*.mu      # generates code.img
```

2. Run it:
```sh
$ qemu-system-i386 -enable-kvm code.img
```
or:
```
$ bochs -f bochsrc
```

To save typing in a large s-expression, create a secondary disk for data:
```sh
$ dd if=/dev/zero of=data.img count=20160
```

Load an s-expression into it:
```sh
$ echo '(+ 1 1)' |dd of=data.img conv=notrunc
```

Now run with both code and data disks:
```sh
$ qemu-system-i386 -enable-kvm -hda code.img -hdb data.img
```
or:
```
$ bochs -f bochsrc.2disks
```

You can type in expressions, hit `ctrl-s` to see their results, and hit `Tab`
to focus on the `...` below and browse how the results were computed. [Here's
a demo.](https://archive.org/details/akkartik-2min-2021-02-24) The bottom of
the screen shows context-dependent keyboard shortcuts (there's no mouse in the
Mu computer at the moment).

*Known issues*

* There's no way to save to disk.

* Don't press keys too quickly (such as by holding down a key). The Mu
  computer will crash (and often Qemu will segfault).
