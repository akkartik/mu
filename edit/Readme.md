Environment for learning programming using Mu: http://akkartik.name/post/mu

Run it from the `mu` directory:

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

---

Appendix: keyboard shortcuts

  _moving and scrolling_
  - `ctrl-a` or `home`: move cursor to start of line
  - `ctrl-e` or `end`: move cursor to end of line
  - `ctrl-f` or `page-down`: scroll down by one page
  - `ctrl-b` or `page-up`: scroll up by one page
  - `ctrl-x`: scroll down by one line
  - `ctrl-s`: scroll up by one line
  - `ctrl-t`: scroll until current line is at top of screen

  _modifying text_
  - `ctrl-k`: delete text from cursor to end of line
  - `ctrl-u`: delete text from start of line until just before cursor
  - `ctrl-/`: comment/uncomment current line (using a special leader to ignore real comments https://www.reddit.com/r/vim/comments/4ootmz/_/d4ehmql)
