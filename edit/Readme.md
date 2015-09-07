Environment for learning programming using mu: http://akkartik.name/post/mu

Run it from the mu directory:

  ```shell
  $ ./mu edit
  ```

This will load all the `.mu` files in this directory and then run the editor.
Press ctrl-c to quit. Press F4 to save your work (if a lesson/ directory
exists) and to run the contents of the sandbox editor on the right.

You can also run the tests for the environment:

  ```shell
  $ ./mu test edit
  ```

You can also load the files more explicitly by enumerating them all:

  ```shell
  $  ./mu edit/*.mu
  ```

This is handy if you want to run simpler versions of the editor so you can
stage your learning.

  ```shell
  $ ./mu edit/00[12]*.mu  # run a simple editor rather than the full environment
  ```

To see how the various 'layers' are organized, peek inside the individual
`.mu` files.
