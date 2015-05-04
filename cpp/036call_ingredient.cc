//: Calls can take ingredients just like primitives. To access a recipe's
//: ingredients, use 'next-ingredient'.

:(scenario next_ingredient)
recipe main [
  f 2:literal
]
recipe f [
  12:integer <- next-ingredient
  13:integer <- add 1:literal, 12:integer
]
+run: instruction f/1
+mem: location 12 is 2
+mem: storing 3 in location 13

:(scenario next_ingredient_missing)
recipe main [
  f
]
recipe f [
  _, 12:integer <- next-ingredient
]
+mem: storing 0 in location 12

:(before "End call Fields")
vector<vector<int> > ingredient_atoms;
index_t next_ingredient_to_process;
:(replace{} "call(recipe_number r)")
call(recipe_number r) :running_recipe(r), running_step_index(0), next_ingredient_to_process(0) {}

:(replace "Current_routine->calls.push(call(current_instruction().operation))" following "End Primitive Recipe Implementations")
call callee(current_instruction().operation);
for (vector<reagent>::const_iterator p = current_instruction().ingredients.begin(); p != current_instruction().ingredients.end(); ++p) {
  callee.ingredient_atoms.push_back(read_memory(*p));
}
Current_routine->calls.push(callee);

:(before "End Primitive Recipe Declarations")
NEXT_INGREDIENT,
:(before "End Primitive Recipe Numbers")
Recipe_number["next-ingredient"] = NEXT_INGREDIENT;
:(before "End Primitive Recipe Implementations")
case NEXT_INGREDIENT: {
  if (Current_routine->calls.top().next_ingredient_to_process < Current_routine->calls.top().ingredient_atoms.size()) {
    trace("run") << "product 0 is "
        << Current_routine->calls.top().ingredient_atoms[Current_routine->calls.top().next_ingredient_to_process][0];
    write_memory(current_instruction().products[0],
        Current_routine->calls.top().ingredient_atoms[Current_routine->calls.top().next_ingredient_to_process]);
    if (current_instruction().products.size() > 1) {
      vector<int> ingredient_exists;
      ingredient_exists.push_back(1);
      write_memory(current_instruction().products[1], ingredient_exists);
    }
    ++Current_routine->calls.top().next_ingredient_to_process;
  }
  else {
    if (current_instruction().products.size() > 1) {
      vector<int> no_ingredient;
      no_ingredient.push_back(0);
      write_memory(current_instruction().products[1], no_ingredient);
    }
  }
  break;
}

:(scenario rewind_ingredients)
recipe main [
  f 2:literal
]
recipe f [
  12:integer <- next-ingredient  # consume ingredient
  _, 1:boolean <- next-ingredient  # will not find any ingredients
  rewind-ingredients
  13:integer, 2:boolean <- next-ingredient  # will find ingredient again
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
  Current_routine->calls.top().next_ingredient_to_process = 0;
  break;
}

:(scenario ingredient)
recipe main [
  f 1:literal, 2:literal
]
recipe f [
  12:integer <- ingredient 1:literal  # consume second ingredient first
  13:integer, 1:boolean <- next-ingredient  # next-ingredient tries to scan past that
]
+mem: storing 2 in location 12
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
INGREDIENT,
:(before "End Primitive Recipe Numbers")
Recipe_number["ingredient"] = INGREDIENT;
:(before "End Primitive Recipe Implementations")
case INGREDIENT: {
  if (static_cast<index_t>(current_instruction().ingredients[0].value) < Current_routine->calls.top().ingredient_atoms.size()) {
    Current_routine->calls.top().next_ingredient_to_process = current_instruction().ingredients[0].value;
    trace("run") << "product 0 is "
        << Current_routine->calls.top().ingredient_atoms[Current_routine->calls.top().next_ingredient_to_process][0];
    write_memory(current_instruction().products[0],
        Current_routine->calls.top().ingredient_atoms[Current_routine->calls.top().next_ingredient_to_process]);
    if (current_instruction().products.size() > 1) {
      vector<int> ingredient_exists;
      ingredient_exists.push_back(1);
      write_memory(current_instruction().products[1], ingredient_exists);
    }
    ++Current_routine->calls.top().next_ingredient_to_process;
  }
  else {
    if (current_instruction().products.size() > 1) {
      vector<int> no_ingredient;
      no_ingredient.push_back(0);
      write_memory(current_instruction().products[1], no_ingredient);
    }
  }
  break;
}
