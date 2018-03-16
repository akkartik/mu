# Example program showing exceptions built out of delimited continuations.
# Slightly less klunky than exception1.mu.

# Since Mu is statically typed, we can't build an all-purpose higher-order
# function called 'try'; it wouldn't know how many arguments the function
# passed to it needs to take, what their types are, etc. Instead, until Mu
# gets macros we'll directly use the continuation primitives.

exclusive-container error-or:_elem [
  error:text
  value:_elem
]

def main [
  local-scope
  no-exception:bool <- copy 0/false
  foo 0/no-exception
  raise-exception:bool <- copy 1/true
  foo 1/raise-exception
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
  # The other inputs and outputs to 'call-with-continuation-mark' depend on
  # the function it is called with.
  _, result:error-or:num <- call-with-continuation-mark 999/exception-tag, f, raise-exception?
  {
    val:num, normal-exit?:bool <- maybe-convert result, value:variant
    break-unless normal-exit?
    $print [normal exit; result ] val 10/newline
  }
  {
    err:text, error-exit?:bool <- maybe-convert result, error:variant
    break-unless error-exit?
    $print [error caught: ] err 10/newline
  }
]

# Callee function that we catch exceptions in must always return using a
# continuation.
def f raise-exception?:bool -> result:error-or:num [
  local-scope
  load-inputs
  {
    break-unless raise-exception?
    # throw/raise
    result <- merge 0/error, [error will robinson!]
    return-continuation-until-mark 999/exception-tag, result
  }
  # 'normal' return; still uses the continuation mark
  result <- merge 1/value, 34
  return-continuation-until-mark 999/exception-tag, result
  # dead code just to avoid errors
  result <- merge 1/value, 0
  return result
]
