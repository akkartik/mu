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
