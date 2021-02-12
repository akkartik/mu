# evaluator for the Mu shell language
# inputs:
#   a list of lines, each a list of words, each an editable gap-buffer
#   end: a word to stop at
# output:
#   a stack of values to render that summarizes the result of evaluation until 'end'

# Key features of the language:
#   { and } for grouping words
#   break and loop for control flow within groups
#   -> for conditionally skipping the next word or group

# Example: Pushing numbers from 1 to n on the stack (single-line body with
# conditionals and loops)
#
#   3 =n
#   { n 1 <     -> break n n 1- =n loop }
# stack:
#     3 1 false          3 3 2  3   1
#       3                  3 3      2
#                                   3

# Rules beyond simple postfix:
#   If the final word is `->`, clear stack
#   If the final word is `break`, pop top of stack
#
#   `{` and `}` don't affect evaluation
#   If the final word is `{` or `}`, clear stack
#
#   If `->` in middle and top of stack is falsy, skip next word or group
#
#   If `break` in middle executes, skip to next containing `}`
#     If no containing `}`, clear stack (incomplete)
#
#   If `loop` in middle executes, skip to previous containing `{`
#     If no containing `}`, clear stack (error)
