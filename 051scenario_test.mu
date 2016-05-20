# tests for 'scenario' in previous layer

scenario first_scenario_in_mu [
  run [
    1:number <- add 2, 2
  ]
  memory-should-contain [
    1 <- 4
  ]
]

scenario scenario_with_comment_in_mu [
  run [
    # comment
    1:number <- add 2, 2
  ]
  memory-should-contain [
    1 <- 4
  ]
]

scenario scenario_with_multiple_comments_in_mu [
  run [
    # comment1
    # comment2
    1:number <- add 2, 2
  ]
  memory-should-contain [
    1 <- 4
  ]
]

scenario check_text_in_memory [
  run [
    1:number <- copy 3
    2:character <- copy 97  # 'a'
    3:character <- copy 98  # 'b'
    4:character <- copy 99  # 'c'
  ]
  memory-should-contain [
    1:array:character <- [abc]
  ]
]

scenario check_trace [
  run [
    1:number <- add 2, 2
  ]
  trace-should-contain [
    mem: storing 4 in location 1
  ]
]

scenario check_trace_negative [
  run [
    1:number <- add 2, 2
  ]
  trace-should-not-contain [
    mem: storing 5 in location 1
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
