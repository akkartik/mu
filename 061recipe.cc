//: So far we've been calling a fixed recipe in each instruction, but we'd
//: also like to make the recipe a variable, pass recipes to "higher-order"
//: recipes, return recipes from recipes and so on.

:(scenario call_literal_recipe)
recipe main [
  1:number <- call f, 34
]
recipe f x:number -> y:number [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1

:(scenario call_variable)
recipe main [
  {1: (recipe number -> number)} <- copy f
  2:number <- call {1: (recipe number -> number)}, 34
]
recipe f x:number -> y:number [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 2

:(before "End Mu Types Initialization")
put(Type_ordinal, "recipe-literal", 0);
// 'recipe' variables can store recipe-literal
type_ordinal recipe = put(Type_ordinal, "recipe", Next_type_ordinal++);
get_or_insert(Type, recipe).name = "recipe";

:(before "End transform_names Exceptions")
if (!x.properties.at(0).second && contains_key(Recipe_ordinal, x.name)) {
  x.properties.at(0).second = new string_tree("recipe-literal");
  x.type = new type_tree(get(Type_ordinal, "recipe-literal"));
  x.set_value(get(Recipe_ordinal, x.name));
  return true;
}

:(before "End Primitive Recipe Declarations")
CALL,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "call", CALL);
:(before "End Primitive Recipe Checks")
case CALL: {
  if (inst.ingredients.empty()) {
    raise_error << maybe(get(Recipe, r).name) << "'call' requires at least one ingredient (the recipe to call)\n" << end();
    break;
  }
  if (!is_mu_recipe(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'call' should be a recipe, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CALL: {
  // Begin Call
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace("trace") << "indirect 'call': incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  const instruction& caller_instruction = current_instruction();
  Current_routine->calls.push_front(call(ingredients.at(0).at(0)));
  ingredients.erase(ingredients.begin());  // drop the callee
  finish_call_housekeeping(caller_instruction, ingredients);
  continue;
}

:(code)
bool is_mu_recipe(reagent r) {
  if (!r.type) return false;
  if (r.properties.at(0).second->value == "recipe") return true;
  if (r.properties.at(0).second->value == "recipe-literal") return true;
  // End is_mu_recipe Cases
  return false;
}
