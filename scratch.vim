" random commands used interactively to build mu.arc.t.html

TOhtml
%s,<.*&lt;-.*,<span class="Mu">&</span>,gc
%s,&lt;-,<span class="Op">&</span>,g
%s/Constant[^>]*>[^>]*> literal/Mu&/gc
%s/Constant[^>]*>[^>]*> offset/Mu&/gc
%s,\<nil literal,<span class="MuConstant">t</span> literal,gc
%s,\<t literal,<span class="MuConstant">t</span> literal,gc

map ` :s,[{}<].*,<span class="Mu">&</span>,<CR>

  " supercedes
  %s,<.*break.*,<span class="Mu">&</span>,gc
  %s,<.*continue.*,<span class="Mu">&</span>,gc
  %s,<.*reply.*,<span class="Mu">&</span>,gc
  %s,<.*jump.*,<span class="Mu">&</span>,gc
  %s,<.*main.*,<span class="Mu">&</span>,gc
  %s,<.*test1.*,<span class="Mu">&</span>,gc
  %s,<.*test2.*,<span class="Mu">&</span>,gc
  %s,<.*f1.*,<span class="Mu">&</span>,gc
  %s,<.*f2.*,<span class="Mu">&</span>,gc

pre { white-space: pre-wrap; font-family: monospace; color: #aaaaaa; background-color: #000000; }
body { font-family: monospace; color: #aaaaaa; background-color: #000000; }
a { color:#4444ff; }
* { font-size: 1em; }
.Constant, .MuConstant { color: #008080; }
.Comment { color: #8080ff; }
.Delimiter { color: #600060; }
.Normal { color: #aaaaaa; }
.Mu, .Mu .Normal, .Mu .Constant { color: #ffffff; }
.Op { color: #ff8888; }
.CommentedCode { color: #666666; }
