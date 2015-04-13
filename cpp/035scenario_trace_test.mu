# tests for trace-checking scenario in previous layer
scenario first_scenario_checking_trace [
  run [
    1:integer <- add 2:literal, 2:literal
  ]
  trace should contain [
    mem: storing 4 in location 1
  ]
]

scenario first_scenario_checking_trace_negative [
  run [
    1:integer <- add 2:literal, 2:literal
  ]
  trace should not contain [
    mem: storing 5 in location 1
  ]
]

scenario trace_in_mu [
  run [
    trace [foo], [aaa]
  ]
  trace should contain [
    foo: aaa
  ]
]
