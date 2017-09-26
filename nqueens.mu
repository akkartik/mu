# http://rosettacode.org/wiki/N-queens_problem
# port of the Arc solution at http://arclanguage.org/item?id=19743
# run with tracing turned on:
#   ./mu --trace nqueens.mu

container square [
  rank:num
  file:num
]

def nqueens n:num, queens:&:list:square -> result:num, queens:&:list:square [
  local-scope
  load-ingredients
  # if 'queens' is already long enough, print it and return
  added-so-far:num <- length queens
  {
    done?:bool <- greater-or-equal added-so-far, n
    break-unless done?
    stash queens
    return 1
  }
  # still work to do
  next-rank:num <- copy 0
  {
    break-unless queens
    first:square <- first queens
    existing-rank:num <- get first, rank:offset
    next-rank <- add existing-rank, 1
  }
  result <- copy 0
  next-file:num <- copy 0
  {
    done?:bool <- greater-or-equal next-file, n
    break-if done?
    curr:square <- merge next-rank, next-file
    {
      curr-conflicts?:bool <- conflict? curr, queens
      break-if curr-conflicts?
      new-queens:&:list:square <- push curr, queens
      sub-result:num <- nqueens n, new-queens
      result <- add result, sub-result
    }
    next-file <- add next-file, 1
    loop
  }
]

# check if putting a queen on 'curr' conflicts with any of the existing
# queens
# assumes that 'curr' is on a non-conflicting rank, and checks for conflict
# only in files and diagonals
def conflict? curr:square, queens:&:list:square -> result:bool [
  local-scope
  load-ingredients
  result <- conflicting-file? curr, queens
  return-if result
  result <- conflicting-diagonal? curr, queens
]

def conflicting-file? curr:square, queens:&:list:square -> result:bool [
  local-scope
  load-ingredients
  curr-file:num <- get curr, file:offset
  {
    break-unless queens
    q:square <- first queens
    qfile:num <- get q, file:offset
    file-match?:bool <- equal curr-file, qfile
    return-if file-match?, 1/conflict-found
    queens <- rest queens
    loop
  }
  return 0/no-conflict-found
]

def conflicting-diagonal? curr:square, queens:&:list:square -> result:bool [
  local-scope
  load-ingredients
  curr-rank:num <- get curr, rank:offset
  curr-file:num <- get curr, file:offset
  {
    break-unless queens
    q:square <- first queens
    qrank:num <- get q, rank:offset
    qfile:num <- get q, file:offset
    rank-delta:num <- subtract qrank, curr-rank
    file-delta:num <- subtract qfile, curr-file
    rank-delta <- abs rank-delta
    file-delta <- abs file-delta
    diagonal-match?:bool <- equal rank-delta, file-delta
    return-if diagonal-match?, 1/conflict-found
    queens <- rest queens
    loop
  }
  return 0/no-conflict-found
]

def main [
  nqueens 4
  $dump-trace [app]
]
