Start fleshing out the previous prototype's plans into something working.

We're back to just plain text without bold formatting. Let's get something
like prototype 3 working with the new architecture. Since Mu still has no
checks we need to move slowly.

One issue with this architecture: I have separate checks for `next-char ==
EOF` and `done-reading? fs`. I'm gonna tolerate that duplication for now.
