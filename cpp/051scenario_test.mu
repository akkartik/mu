# tests for 'scenario' in previous layer

scenario first_scenario_in_mu [
  run [
    1:integer <- add 2:literal, 2:literal
  ]
  memory should contain [
    1 <- 4
  ]
]

scenario check_string_in_memory [
  run [
    1:integer <- copy 3:literal
    2:character <- copy 97:literal  # 'a'
    3:character <- copy 98:literal  # 'b'
    4:character <- copy 99:literal  # 'c'
  ]
  memory should contain [
    1:string <- [abc]
  ]
]
