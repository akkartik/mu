Run all these from the top-level `mu/` directory.

### Some tools for Mu's build process

These are built automatically.

* `enumerate`: list numeric files in current directory, optionally `--until`
  some prefix.


### Miscellaneous odds and ends

These are built lazily.

* `treeshake_all`: rebuild SubX binaries without tests and unused functions.
  Pretty hacky; just helps estimate the code needed to perform various tasks.
  ```
  tools/treeshake_all
  ```
