# Prototypes

Each directory here is a series of prototypes for a single app.

To build prototype #n of app X under this directory:

```
$ ./translate_mu prototypes/__X__/__n__.mu
```

Now try running it with some text file:

```
$ ./a.elf __text_file__
```

Sub-directories are prototypes with multiple files. Build them like this:

```
$ ./translate_mu prototypes/__X__/__n__/*.mu
```

Run them as before.
