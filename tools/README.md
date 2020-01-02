Run all these from the top-level `mu/` directory.

### Some tools for Mu's build process

These are built automatically.

* `enumerate`: list numeric files in current directory, optionally `--until`
  some prefix.


### Miscellaneous odds and ends

These are built lazily.

* `browse_trace`: debugging tool. See `browse_trace.readme.md` for details.

* `linkify`: inserts hyperlinks from variables to definitions in Mu's html
  sources. Hacky; just see the number of tests. Invoked by `update_html`.

* `treeshake_all`: rebuild SubX binaries without tests and unused functions.
  Hacky; just helps estimate the code needed to perform various tasks.
  ```
  tools/treeshake_all
  ```

### Notes to self: constraints on the tools/ directory
* Don't overwhelm the initial view of the project with lots of crap in the
  root directory.
* Directories go up top in the github view, so too many sub-directories are
  also overwhelming.
* Don't increase increase build time too much; everything in `tools/` shouldn't
  be automatically built.
  * stuff needed all the time is built from root directory.
* `tools/` contains many independent things; don't make it hard to see
  boundaries. Ideally just one source file per tool. If not, give related
  files similar name prefixes.
