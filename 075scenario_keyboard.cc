//: Clean syntax to manipulate and check the keyboard in scenarios.
//: Instruction 'assume-keyboard' implicitly creates a variable called
//: 'keyboard' that is accessible inside other 'run' instructions in the
//: scenario.

:(scenarios run_mu_scenario)
:(scenario keyboard_in_scenario)
scenario keyboard-in-scenario [
  assume-keyboard [abc]
  run [
    1:character, 2:boolean, keyboard:address <- read-key keyboard:address
    3:character, 4:boolean, keyboard:address <- read-key keyboard:address
    5:character, 6:boolean, keyboard:address <- read-key keyboard:address
    7:character, 8:boolean, keyboard:address <- read-key keyboard:address
  ]
  memory-should-contain [
    1 <- 97  # 'a'
    2 <- 1
    3 <- 98  # 'b'
    4 <- 1
    5 <- 99  # 'c'
    6 <- 1
    7 <- 0  # eof
    8 <- 1
  ]
]

:(before "End Scenario Globals")
const long long int KEYBOARD = Next_predefined_global_for_scenarios++;
:(before "End Predefined Scenario Locals In Run")
Name[tmp_recipe.at(0)]["keyboard"] = KEYBOARD;

//: allow naming just for 'keyword'
:(before "End is_special_name Cases")
if (s == "keyboard") return true;

:(before "End Rewrite Instruction(curr)")
// rewrite `assume-keyboard string` to
//   ```
//   keyboard:address <- new string  # hacky reuse of location
//   keyboard:address <- init-fake-keyboard keyboard:address
//   ```
if (curr.name == "assume-keyboard") {
  // insert first instruction
  curr.operation = Recipe_number["new"];
  assert(curr.products.empty());
  curr.products.push_back(reagent("keyboard:address"));
  curr.products.at(0).set_value(KEYBOARD);
  result.steps.push_back(curr);  // hacky that "Rewrite Instruction" is converting to multiple instructions
  // leave second instruction in curr
  curr.clear();
  curr.operation = Recipe_number["init-fake-keyboard"];
  curr.name = "init-fake-keyboard";
  assert(curr.ingredients.empty());
  curr.ingredients.push_back(reagent("keyboard:address"));
  curr.ingredients.at(0).set_value(KEYBOARD);
  assert(curr.products.empty());
  curr.products.push_back(reagent("keyboard:address"));
  curr.products.at(0).set_value(KEYBOARD);
}
