# To provide commandline args to a Mu program, use '--'. In this case:
#   $ ./mu args.mu -- abc
#   abc
def main text:text [
  local-scope
  load-inputs
  $print text 10/newline
]
