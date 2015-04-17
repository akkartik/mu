# tests for 'scenario' in previous layer

scenario first_scenario_in_mu [
  run [
    1:integer <- add 2:literal, 2:literal
  ]
  memory should contain [
    1 <- 4
  ]
]
