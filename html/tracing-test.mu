


  run [
    result:boolean <- equal [abc], [abcd]  # lengths differ
  ]
  trace-should-contain [
    equal: comparing lengths
  ]
  trace-should-not-contain [
    equal: comparing characters
  ]






