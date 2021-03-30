A programming environment that tries to [&ldquo;stop drawing dead fish&rdquo;](http://worrydream.com/#!/StopDrawingDeadFish).

<img alt='screenshot' src='../../html/rpn5.png' width='500px'>

To run:

```
$ cd linux
$ ./translate tile/*.mu
$ ./a.elf screen
```

To run tests:

```
$ ./a.elf test
```

To run a conventional REPL (for debugging):

```
$ ./a.elf type
```

## hacking

This is just a prototype. There are no tests.

To add a new primitive you'll need to hard-code it into the `evaluate`
function (linux/tile/rpn.mu).

There's also a second place you'll want to teach about predefined primitives:
`bound-function?` (linux/tile/environment.mu)
