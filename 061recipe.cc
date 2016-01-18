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

//:: check types for 'call' instructions

:(scenario call_check_literal_recipe)
% Hide_errors = true;
recipe main [
  1:number <- call f, 34
]
recipe f x:boolean -> y:boolean [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: ingredient 0 has the wrong type at '1:number <- call f, 34'
+error: main: product 0 has the wrong type at '1:number <- call f, 34'

:(scenario call_check_variable_recipe)
% Hide_errors = true;
recipe main [
  {1: (recipe boolean -> boolean)} <- copy f
  2:number <- call {1: (recipe boolean -> boolean)}, 34
]
recipe f x:boolean -> y:boolean [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: ingredient 0 has the wrong type at '2:number <- call {1: (recipe boolean -> boolean)}, 34'
+error: main: product 0 has the wrong type at '2:number <- call {1: (recipe boolean -> boolean)}, 34'

:(after "Transform.push_back(check_instruction)")
Transform.push_back(check_indirect_calls_against_header);  // idempotent
:(code)
void check_indirect_calls_against_header(const recipe_ordinal r) {
  trace(9991, "transform") << "--- type-check 'call' instructions inside recipe " << get(Recipe, r).name << end();
  const recipe& caller = get(Recipe, r);
  for (long long int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    if (inst.operation != CALL) continue;
    if (inst.ingredients.empty()) continue;  // error raised above
    const reagent& callee = inst.ingredients.at(0);
    if (!is_mu_recipe(callee)) continue;  // error raised above
    const recipe callee_header = is_literal(callee) ? get(Recipe, callee.value) : from_reagent(inst.ingredients.at(0));
    if (!callee_header.has_header) continue;
    for (long int i = /*skip callee*/1; i < min(SIZE(inst.ingredients), SIZE(callee_header.ingredients)+/*skip callee*/1); ++i) {
      if (!types_coercible(callee_header.ingredients.at(i-/*skip callee*/1), inst.ingredients.at(i)))
        raise_error << maybe(caller.name) << "ingredient " << i-/*skip callee*/1 << " has the wrong type at '" << inst.to_string() << "'\n" << end();
    }
    for (long int i = 0; i < min(SIZE(inst.products), SIZE(callee_header.products)); ++i) {
      if (is_dummy(inst.products.at(i))) continue;
      if (!types_coercible(callee_header.products.at(i), inst.products.at(i)))
        raise_error << maybe(caller.name) << "product " << i << " has the wrong type at '" << inst.to_string() << "'\n" << end();
    }
  }
}

recipe from_reagent(const reagent& r) {
  assert(r.properties.at(0).second->value == "recipe");
  recipe result_header;  // will contain only ingredients and products, nothing else
  result_header.has_header = true;
  const string_tree* curr = r.properties.at(0).second->right;
  for (; curr; curr=curr->right) {
    if (curr->value == "->") {
      curr = curr->right;  // skip delimiter
      break;
    }
    result_header.ingredients.push_back("recipe:"+curr->value);
  }
  for (; curr; curr=curr->right) {
    result_header.products.push_back("recipe:"+curr->value);
  }
  return result_header;
}

bool is_mu_recipe(reagent r) {
  if (!r.type) return false;
  if (r.properties.at(0).second->value == "recipe") return true;
  if (r.properties.at(0).second->value == "recipe-literal") return true;
  // End is_mu_recipe Cases
  return false;
}
