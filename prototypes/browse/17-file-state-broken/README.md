More OO. Create a similar set of helpers for reading characters from disk.

It's surprising that state for supporting headings needs to go into the state
maintained while reading the file from disk.

Since we now have two 'classes', it seems worth splitting up into multiple
files.
