//: Calls can take ingredients just like primitives. To access a recipe's
//: ingredients, use 'next-ingredient'.

:(scenario next_ingredient)
recipe main [
  f 2:literal
]
recipe f [
  12:number <- next-ingredient
  13:number <- add 1:literal, 12:number
]
+run: instruction f/1
+mem: location 12 is 2
+mem: storing 3 in location 13

:(scenario next_ingredient_missing)
recipe main [
  f
]
recipe f [
  _, 12:number <- next-ingredient
]
+mem: storing 0 in location 12

:(before "End call Fields")
vector<vector<double> > ingredient_atoms;
index_t next_ingredient_to_process;
:(replace{} "call(recipe_number r)")
call(recipe_number r) :running_recipe(r), running_step_index(0), next_ingredient_to_process(0) {}

:(replace "Current_routine->calls.push_front(call(current_instruction().operation))" following "End Primitive Recipe Implementations")
call callee(current_instruction().operation);
for (size_t i = 0; i < ingredients.size(); ++i) {
  callee.ingredient_atoms.push_back(ingredients.at(i));
}
Current_routine->calls.push_front(callee);

:(before "End Primitive Recipe Declarations")
NEXT_INGREDIENT,
:(before "End Primitive Recipe Numbers")
Recipe_number["next-ingredient"] = NEXT_INGREDIENT;
:(before "End Primitive Recipe Implementations")
case NEXT_INGREDIENT: {
  assert(!Current_routine->calls.empty());
  if (Current_routine->calls.front().next_ingredient_to_process < Current_routine->calls.front().ingredient_atoms.size()) {
    products.push_back(
        Current_routine->calls.front().ingredient_atoms.at(Current_routine->calls.front().next_ingredient_to_process));
    assert(products.size() == 1);  products.resize(2);  // push a new vector
    products.at(1).push_back(1);
    ++Current_routine->calls.front().next_ingredient_to_process;
  }
  else {
    products.resize(2);
    products.at(0).push_back(0);  // todo: will fail noisily if we try to read a compound value
    products.at(1).push_back(0);
  }
  break;
}

:(scenario rewind_ingredients)
recipe main [
  f 2:literal
]
recipe f [
  12:number <- next-ingredient  # consume ingredient
  _, 1:boolean <- next-ingredient  # will not find any ingredients
  rewind-ingredients
  13:number, 2:boolean <- next-ingredient  # will find ingredient again
]
+mem: storing 2 in location 12
+mem: storing 0 in location 1
+mem: storing 2 in location 13
+mem: storing 1 in location 2

:(before "End Primitive Recipe Declarations")
REWIND_INGREDIENTS,
:(before "End Primitive Recipe Numbers")
Recipe_number["rewind-ingredients"] = REWIND_INGREDIENTS;
:(before "End Primitive Recipe Implementations")
case REWIND_INGREDIENTS: {
  Current_routine->calls.front().next_ingredient_to_process = 0;
  break;
}

:(scenario ingredient)
recipe main [
  f 1:literal, 2:literal
]
recipe f [
  12:number <- ingredient 1:literal  # consume second ingredient first
  13:number, 1:boolean <- next-ingredient  # next-ingredient tries to scan past that
]
+mem: storing 2 in location 12
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
INGREDIENT,
:(before "End Primitive Recipe Numbers")
Recipe_number["ingredient"] = INGREDIENT;
:(before "End Primitive Recipe Implementations")
case INGREDIENT: {
  assert(isa_literal(current_instruction().ingredients.at(0)));
  assert(ingredients.at(0).size() == 1);  // scalar
  if (static_cast<index_t>(ingredients.at(0).at(0)) < Current_routine->calls.front().ingredient_atoms.size()) {
    Current_routine->calls.front().next_ingredient_to_process = ingredients.at(0).at(0);
    products.push_back(
        Current_routine->calls.front().ingredient_atoms.at(Current_routine->calls.front().next_ingredient_to_process));
    assert(products.size() == 1);  products.resize(2);  // push a new vector
    products.at(1).push_back(1);
    ++Current_routine->calls.front().next_ingredient_to_process;
  }
  else {
    if (current_instruction().products.size() > 1) {
      products.resize(2);
      products.at(0).push_back(0);  // todo: will fail noisily if we try to read a compound value
      products.at(1).push_back(0);
    }
  }
  break;
}
