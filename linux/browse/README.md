Render a subset of Markdown.

To run:

  ```
  $ cd linux
  $ ./translate browse.mu
  $ ./a.elf __text_file__
  ```

Press 'q' to quit. All other keys scroll down.

## Format restrictions

This is a fairly tiny subset of GitHub-Flavored Markdown. Things supported so
far:

* Newlines are mostly ignored. Double newlines are rendered (paragraphs).
  Newlines followed by indentation are rendered.
* Paragraphs starting with runs of `#` represent headings.
* Within a line, characters between `*`s or `_`s represent bolded text. No
  italics.
