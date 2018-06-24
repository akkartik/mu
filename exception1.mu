# Example program showing exceptions built out of delimited continuations.

# Since Mu is statically typed, we can't build an all-purpose higher-order
# function called 'try'; it wouldn't know how many arguments the function
# passed to it needs to take, what their types are, etc. Instead, until Mu
# gets macros we'll directly use the continuation primitives.

def main [
  local-scope
  foo false/no-exception
  foo true/raise-exception
]

# example showing exception handling
def foo raise-exception?:bool [
  local-scope
  load-inputs
  # To run an instruction of the form:
  #   try f ...
  # write this:
  #   call-with-continuation-mark 999/exception-tag, f, ...
  # By convention we reserve tag 999 for exceptions.
  #
  # 'f' above may terminate at either a regular 'return' or a 'return-with-continuation-mark'.
  # We never re-call the continuation returned in the latter case;
  # its existence merely signals that an exception was raised.
  # So just treat it as a boolean.
  # The other inputs and outputs to 'call-with-continuation-mark' depend on
  # the function it is called with.
  exception-raised?:bool, err:text, result:num <- call-with-continuation-mark 999/exception-tag, f, raise-exception?
  {
    break-if exception-raised?
    $print [normal exit; result ] result 10/newline
  }
  {
    break-unless exception-raised?
    $print [error caught: ] err 10/newline
  }
]

# A callee function that can raise an exception has some weird constraints at
# the moment.
#
# The caller's 'call-with-continuation-mark' instruction may return with
# either a regular 'return' or a 'return-continuation-until-mark'.
# To handle both cases, regular 'return' instructions in the callee must
# prepend an extra 0 result, in place of the continuation that may have been
# returned.
# This change to number of outputs violates our type system, so the call has
# to be dynamically typed. The callee can't have a header.
def f [
  local-scope
  raise-exception?:bool <- next-input
  {
    break-unless raise-exception?
    # throw/raise: 2 results + implicit continuation (ignoring the continuation tag)
    return-continuation-until-mark 999/exception-tag, [error will robinson!], 0/unused
  }
  # normal return: 3 results including 0 continuation placeholder at start
  return 0/continuation-placeholder, null/no-error, 34/regular-result
]
