Variant of [the Mu programming environment](../edit) that runs just the sandbox.

Suitable for people who want to run their favorite terminal-based editor with
Mu. Just run editor and sandbox inside split panes atop tmux. For example,
here's Mu running alongside vim:

<img alt='tmux+vim example' src='../html/tmux-vim-sandbox.png'>

To set this up:

  a) copy the lines in tmux.conf into `$HOME/.tmux.conf`.

  b) copy the file `mu_run` somewhere in your `$PATH`.

Now when you start tmux, split it into two vertical panes, run `./mu sandbox`
on the right pane and your editor on the left. You should be able to hit F4 in
either side to run the sandbox.

Known issues: you have to explicitly save inside your editor before hitting
F4, unlike with `./mu edit`.

---

Appendix: keyboard shortcuts

  _moving_
  - `ctrl-a` or `home`: move cursor to start of line
  - `ctrl-e` or `end`: move cursor to end of line

  _modifying text_
  - `ctrl-k`: delete text from cursor to end of line
  - `ctrl-u`: delete text from start of line until just before cursor
  - `ctrl-/`: comment/uncomment current line (using a special leader to ignore real comments https://www.reddit.com/r/vim/comments/4ootmz/_/d4ehmql)
