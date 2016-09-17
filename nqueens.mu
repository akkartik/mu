# http://rosettacode.org/wiki/N-queens_problem
# port of the Arc solution at http://arclanguage.org/item?id=19743

container square [
  rank:num
  file:num
]

def nqueens n:num, queens:address:list:square -> result:num [
  local-scope
  load-ingredients
  # if 'queens' is already long enough, print it and return
  added-so-far:num <- length queens
  {
    done?:boolean <- greater-or-equal added-so-far, n
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
    done?:boolean <- greater-or-equal next-file, n
    break-if done?
    curr:square <- merge next-rank, next-file
    {
      curr-conflicts?:boolean <- conflict? curr, queens
      break-if curr-conflicts?
      new-queens:address:list:square <- push curr, queens
      sub-result:num <- nqueens n, new-queens
      result <- add result, sub-result
    }
    next-file <- add next-file, 1
    loop
  }
]

def conflict? curr:square, queens:address:list:square -> result:boolean [
  local-scope
  load-ingredients
  result1:boolean <- conflicting-file? curr, queens
  reply-if result1, result1
  result2:boolean <- conflicting-diagonal? curr, queens
  reply result2
]

def conflicting-file? curr:square, queens:address:list:square -> result:boolean [
  local-scope
  load-ingredients
  curr-file:num <- get curr, file:offset
  {
    break-unless queens
    q:square <- first queens
    qfile:num <- get q, file:offset
    file-match?:boolean <- equal curr-file, qfile
    reply-if file-match?, 1/conflict-found
    queens <- rest queens
    loop
  }
  reply 0/no-conflict-found
]

def conflicting-diagonal? curr:square, queens:address:list:square -> result:boolean [
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
    diagonal-match?:boolean <- equal rank-delta, file-delta
    reply-if diagonal-match?, 1/conflict-found
    queens <- rest queens
    loop
  }
  reply 0/no-conflict-found
]
