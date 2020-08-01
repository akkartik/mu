# Prototypes

Each directory here is a series of prototypes for a single app.

To build prototype #n of app X under this directory:

```
$ ./translate_mu prototypes/__X__/__n__.mu
```

This will generate a binary called `a.elf`.

Sub-directories are prototypes with multiple files. Build them like this:

```
$ ./translate_mu prototypes/__X__/__n__/*.mu
```

For instructions on running the generated `a.elf` binary, see the prototype's
Readme.
