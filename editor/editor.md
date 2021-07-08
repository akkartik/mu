## Getting your editor set up

If you've read this far, it's time to set up your editor. Mu is really
intended to be read interactively rather than on a browser.

There is rudimentary syntax highlighting support for Mu and SubX files for
various editors. Look for your editor in `mu.*` and `subx.*`, and follow the
instructions within.

The Vim files are most developed. In particular, I recommend some optional
setup in subx.vim to use multiple colors for comments.

If you use [`ctags`](http://ctags.sourceforge.net) for jumping easily
from names to their definitions in your editor, set it up to load `mu.ctags`.
For classic Exuberant Ctags, copy it into `~/.ctags`. For the newer Universal
Ctags, copy it into `~/.ctags.d/mu.ctags`.

[Here](https://lobste.rs/s/qglfdp/subx_minimalist_assembly_language_for#c_o9ddqk)
are some tips on my setup for quickly finding the right opcode for any
situation from within Vim.
