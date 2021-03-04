### A debugging helper that lets you zoom in/out on a trace.

To try it out, first create an example trace:

  ```shell
  $ cd linux
  $ bootstrap/bootstrap translate [01]*.subx factorial.subx -o factorial
  $ bootstrap/bootstrap --trace run factorial
  ```

This command will save a trace of its execution in a file called `last_run`.
The trace consists of a series of lines, each starting with an integer depth
and a single-word 'label', followed by a colon and whitespace.

Now browse this trace:

  ```shell
  $ cd ..
  $ tools/browse_trace linux/last_run
  ```

You should now find yourself in a UI showing a subsequence of lines from the
trace, each line starting with a numeric depth, and ending with a parenthetical
count of trace lines hidden after it with greater depths.

For example, this line:

  ```
  2 app: line1 (30)
  ```

indicates that it was logged with depth 2, and that 30 following lines have
been hidden at a depth greater than 2.

(As an experiment, hidden counts of 1000 or more are highlighted in red.)

The UI provides the following hotkeys:

* `q` or `ctrl-c`: Quit.

* `Enter`: 'Zoom into' this line. Expand lines hidden after it that were at
  the next higher level.

* `Backspace`: 'Zoom out' on a line after zooming in, collapsing lines below
  expanded by some series of `Enter` commands.

* `j` or `down-arrow`: Move cursor down one line.
* `k` or `up-arrow`: Move cursor up one line.
* `J` or `ctrl-f` or `page-down`: Scroll cursor down one page.
* `K` or `ctrl-b` or `page-up`: Scroll cursor up one page.
* `h` or `left-arrow`: Scroll cursor left one character.
* `l` or `right-arrow`: Scroll cursor right one character.
* `H`: Scroll cursor left one screen-width.
* `L`: Scroll cursor right one screen-width.

* `g` or `home`: Move cursor to start of trace.
* `G` or `end`: Move cursor to end of trace.

* `t`: Move cursor to top line on screen.
* `c`: Move cursor to center line on screen.
* `b`: Move cursor to bottom line on screen.
* `T`: Scroll line at cursor to top of screen.

* `/`: Search forward for a pattern.
* `?`: Search backward for a pattern.
* `n`: Repeat the previous `/` or `?`.
* `N`: Repeat the previous `/` or `?` in the opposite direction.

After hitting `/`, the mini-editor on the bottom-most line supports the
following hotkeys:
* ascii characters: add the key to the pattern.
* `Enter`: search for the pattern.
* `Esc` or `ctrl-c`: cancel the current search, setting the screen back
  to its state before the search.
* `left-arrow`: move cursor left.
* `right-arrow`: move cursor right.
* `ctrl-a` or `home`: move cursor to start of search pattern.
* `ctrl-e` or `end`: move cursor to end of search pattern.
* `ctrl-u`: clear search pattern before cursor
* `ctrl-k`: clear search pattern at and after cursor

## wish list

* Simple regular expression search: `.` and `*`.
* Expand into lower depths as necessary when searching.
* Zoom out everything.
* Zoom out lines around the cursor to the highest (or specified) depth.
  Maybe a number followed by `]`?
