//: push a variable recipe on the call stack

:(scenario call_literal_recipe)
recipe main [
  1:number <- call f:recipe, 34:literal
]
recipe f [
  2:number <- next-ingredient
  reply 2:number
]
+mem: storing 34 in location 1

:(scenario call_variable)
recipe main [
  1:number/recipe <- copy 1001:literal/f  # hack: assumes tests start recipes at 1000
  2:number <- call 1:number/recipe, 34:literal
]
recipe f [  # recipe 1001
  3:number <- next-ingredient
  reply 3:number
]
+mem: storing 34 in location 2
#? ?

:(before "End Primitive Recipe Declarations")
CALL,
:(before "End Primitive Recipe Numbers")
Recipe_number["call"] = CALL;
:(before "End Primitive Recipe Implementations")
case CALL: {
  recipe_number r = 0;
  if (current_instruction().ingredients.at(0).initialized) {
    assert(scalar(ingredients.at(0)));
    // 'call' received an integer recipe_number
    r = ingredients.at(0).at(0);
  }
  else {
    // 'call' received a literal recipe name
    r = Recipe_number[current_instruction().ingredients.at(0).name];
  }
  Current_routine->calls.push_front(call(r));
  ingredients.erase(ingredients.begin());  // drop the callee
  goto complete_call;
}
