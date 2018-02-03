Original prototype, last modified 2015-03-14

First install [Racket](http://racket-lang.org) (just for the initial
prototype). Then:

  ```shell
  $ cd mu/arc
  $ git clone http://github.com/arclanguage/anarki
  $ ./mu test mu.arc.t  # run tests
  ```

Example programs:

  ```shell
  $ ./mu factorial.mu  # computes factorial of 5
  $ ./mu fork.mu  # two threads print '33' and '34' forever
  $ ./mu channel.mu  # two threads in a producer/consumer relationship
  ```
