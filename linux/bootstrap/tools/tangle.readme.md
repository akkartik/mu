[Literate Programming](https://en.wikipedia.org/wiki/Literate_programming)
tool to convert Mu's layers into compilable form.

Mu's tangling directives differ from Knuth's classic implementation. The
classical approach starts out with labeled subsystems that are initially
empty, and adds code to them using two major directives:

```
<name> ≡
<code>
```

```
<name> +≡
<code>
```

_(`<code>` can span multiple lines.)_

This approach is best suited for top-down exposition.

On the other hand, Mu's tangling directives are better suited for a cleaned-up
history of a codebase. Subsystems start out with a simple skeleton of the core
of the program. Later versions then tell a story of the evolution of the
program, with each version colocating all the code related to new features.

Read more:
* http://akkartik.name/post/wart-layers
* http://akkartik.name/post/literate-programming
* https://github.com/akkartik/mu/blob/master/000organization.cc

## directives

Add code to a project:

```
:(code)
<code>
```

Insert code before a specific line:

```
:(before <waypoint>)
<code>
```

Here `<waypoint>` is a substring matching a single line in the codebase. (We
never use regular expressions.) Surround the substring in `"` quotes if it
spans multiple words.

Insert code _after_ a specific line:

```
:(after <waypoint>)
<code>
```

Delete a specific previously-added line (because it's not needed in a newer
version).

```
:(delete <line>)
```

Delete a block of code starting with a given header and surrounded by `{` and
`}`:

```
:(delete{} <header>)
```

_(Caveat: doesn't directly support C's `do`..`while` loops.)_

Replace a specific line with new code:

```
:(replace <line>)
<code>
```

This is identical to:
```
:(before <line>)
<code>
:(delete <line>)
```
_(Assuming `<code>` did not insert a new line matching the substring `<line>`.)_

Replace a block of code with another:

```
:(replace{} <header>)
<code>
```

Insert code before or after a substring pattern that isn't quite a unique
waypoint in the whole codebase:

```
:(before <line> following <waypoint>)
<code>
:(after <line> following <waypoint>)
<code>
```

```
:(before <waypoint> then <line>)
<code>
:(after <waypoint> then <line>)
<code>
```
