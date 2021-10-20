fn the-answer -> _/eax: int {
  var result/eax: int <- copy 0
  # insert your statement below {

  # }
  return result
}

fn test-the-answer {
  var result/eax: int <- the-answer
  check-ints-equal result, 0x2a, "F - the-answer should return 42, but didn't."
}

fn main {
}
