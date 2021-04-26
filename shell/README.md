### A prototype shell for the Mu computer

Currently runs a tiny subset of Lisp. Steps to run it from the top-level:

1. Build it:
```sh
$ ./translate shell/*.mu      # generates code.img
```

2. Run it:
```sh
$ qemu-system-i386 -m 2G code.img
```
or:
```
$ bochs -f bochsrc            # _much_ slower
```

To save typing in a large s-expression, create a secondary disk for data:
```sh
$ dd if=/dev/zero of=data.img count=20160
```

Load an s-expression into it:
```sh
$ echo '(+ 1 1)' |dd of=data.img conv=notrunc
```

You can also try one of the files of definitions in this directory (`*.limg`).

```sh
$ cat data.limg |dd of=data.img conv=notrunc
```

Now run with both code and data disks:
```sh
$ qemu-system-i386 -m 2G -hda code.img -hdb data.img
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

*Improvements*

If your Qemu installation supports them, one of these commandline arguments
may speed up emulation:

- `-enable-kvm`
- `-accel ___` (run with `-accel help` for a list of available options)

As a complete example, here's the command I typically use on Linux:

```
$ qemu-system-i386 -m 2G -enable-kvm -hda code.img -hdb data.img
```

*Known issues*

* Don't press keys too quickly (such as by holding down a key). The Mu
  computer will crash (and often Qemu will segfault).

* Mu currently assumes access to 2GB of RAM. To change that, modify the
  definition of `Heap` in 120allocate.subx, and then modify the `-m 2G`
  argument in the Qemu commands above. Mu currently has no virtual
  memory. If your Heap is too large for RAM, allocating past the end of RAM
  will succeed. However, accessing addresses not backed by RAM will fail with
  this error:

  ```
  lookup: failed
  ```
