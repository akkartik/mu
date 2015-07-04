//: So far we've been calling a fixed recipe in each instruction, but we'd
//: also like to make the recipe a variable, pass recipes to "higher-order"
//: recipes, return recipes from recipes and so on.

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
  1:recipe-code <- copy f:recipe
  2:number <- call 1:recipe-code, 34:literal
]
recipe f [
  3:number <- next-ingredient
  reply 3:number
]
+mem: storing 34 in location 2
#? ?

:(before "End Mu Types Initialization")
Type_number["recipe"] = 0;
type_number recipe_code = Type_number["recipe-code"] = Next_type_number++;
Type[recipe_code].name = "recipe-code";

:(before "End Reagent-parsing Exceptions")
if (r.properties.at(0).second.at(0) == "recipe") {
  r.set_value(Recipe_number[r.name]);
  return;
}

:(before "End Primitive Recipe Declarations")
CALL,
:(before "End Primitive Recipe Numbers")
Recipe_number["call"] = CALL;
:(before "End Primitive Recipe Implementations")
case CALL: {
  assert(scalar(ingredients.at(0)));
  // todo: when we start doing type checking this will be a prime point of
  // attention, so we don't accidentally allow external data to a program to
  // run as code.
  Current_routine->calls.push_front(call(ingredients.at(0).at(0)));
  ingredients.erase(ingredients.begin());  // drop the callee
  goto complete_call;
}
