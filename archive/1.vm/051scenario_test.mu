# tests for 'scenario' in previous layer

scenario first_scenario_in_mu [
  run [
    10:num <- add 2, 2
  ]
  memory-should-contain [
    10 <- 4
  ]
]

scenario scenario_with_comment_in_mu [
  run [
    # comment
    10:num <- add 2, 2
  ]
  memory-should-contain [
    10 <- 4
  ]
]

scenario scenario_with_multiple_comments_in_mu [
  run [
    # comment1
    # comment2
    10:num <- add 2, 2
  ]
  memory-should-contain [
    10 <- 4
  ]
]

scenario check_text_in_memory [
  run [
    10:num <- copy 3
    11:char <- copy 97  # 'a'
    12:char <- copy 98  # 'b'
    13:char <- copy 99  # 'c'
  ]
  memory-should-contain [
    10:array:character <- [abc]
  ]
]

scenario check_trace [
  run [
    10:num <- add 2, 2
  ]
  trace-should-contain [
    mem: storing 4 in location 10
  ]
]

scenario check_trace_negative [
  run [
    10:num <- add 2, 2
  ]
  trace-should-not-contain [
    mem: storing 3 in location 10
  ]
]

scenario check_trace_instruction [
  run [
    trace 1, [foo], [aaa]
  ]
  trace-should-contain [
    foo: aaa
  ]
]
