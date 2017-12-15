//: So far we've been calling a fixed recipe in each instruction, but we'd
//: also like to make the recipe a variable, pass recipes to "higher-order"
//: recipes, return recipes from recipes and so on.
//:
//: todo: support storing shape-shifting recipes into recipe variables and calling them

:(scenario call_literal_recipe)
def main [
  1:num <- call f, 34
]
def f x:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1

:(before "End Mu Types Initialization")
put(Type_ordinal, "recipe-literal", 0);
// 'recipe' variables can store recipe-literal
type_ordinal recipe = put(Type_ordinal, "recipe", Next_type_ordinal++);
get_or_insert(Type, recipe).name = "recipe";

:(after "Deduce Missing Type(x, caller)")
if (!x.type)
  try_initialize_recipe_literal(x, caller);
:(before "Type Check in Type-ingredient-aware check_or_set_types_by_name")
if (!x.type)
  try_initialize_recipe_literal(x, variant);
:(code)
void try_initialize_recipe_literal(reagent& x, const recipe& caller) {
  if (x.type) return;
  if (!contains_key(Recipe_ordinal, x.name)) return;
  if (contains_reagent_with_non_recipe_literal_type(caller, x.name)) return;
  x.type = new type_tree("recipe-literal");
  x.set_value(get(Recipe_ordinal, x.name));
}
bool contains_reagent_with_non_recipe_literal_type(const recipe& caller, const string& name) {
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    const instruction& inst = caller.steps.at(i);
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i)
      if (is_matching_non_recipe_literal(inst.ingredients.at(i), name)) return true;
    for (int i = 0;  i < SIZE(inst.products);  ++i)
      if (is_matching_non_recipe_literal(inst.products.at(i), name)) return true;
  }
  return false;
}
bool is_matching_non_recipe_literal(const reagent& x, const string& name) {
  if (x.name != name) return false;
  if (!x.type) return false;
  return !x.type->atom || x.type->name != "recipe-literal";
}

//: It's confusing to use variable names that are also recipe names. Always
//: assume variable types override recipe literals.
:(scenario error_on_recipe_literal_used_as_a_variable)
% Hide_errors = true;
def main [
  local-scope
  a:bool <- equal break 0
  break:bool <- copy 0
]
+error: main: missing type for 'break' in 'a:bool <- equal break, 0'

:(before "End Primitive Recipe Declarations")
CALL,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "call", CALL);
:(before "End Primitive Recipe Checks")
case CALL: {
  if (inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'call' requires at least one ingredient (the recipe to call)\n" << end();
    break;
  }
  if (!is_mu_recipe(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'call' should be a recipe, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
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
  if (!ingredients.at(0).at(0)) {
    raise << maybe(current_recipe_name()) << "tried to call empty recipe in '" << to_string(current_instruction()) << "'" << end();
    break;
  }
  const call& caller_frame = current_call();
  instruction/*copy*/ call_instruction = to_instruction(caller_frame);
  call_instruction.operation = ingredients.at(0).at(0);
  call_instruction.ingredients.erase(call_instruction.ingredients.begin());
  Current_routine->calls.push_front(call(ingredients.at(0).at(0)));
  ingredients.erase(ingredients.begin());  // drop the callee
  finish_call_housekeeping(call_instruction, ingredients);
  Num_refcount_updates[caller_frame.running_recipe][caller_frame.running_step_index]
      += (Total_refcount_updates - initial_num_refcount_updates);
  initial_num_refcount_updates = Total_refcount_updates;
  // not done with caller
  write_products = false;
  fall_through_to_next_instruction = false;
  break;
}

:(scenario call_variable)
def main [
  {1: (recipe number -> number)} <- copy f
  2:num <- call {1: (recipe number -> number)}, 34
]
def f x:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 2

:(scenario call_literal_recipe_repeatedly)
def main [
  1:num <- call f, 34
  1:num <- call f, 35
]
def f x:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1
+mem: storing 35 in location 1

:(scenario call_shape_shifting_recipe)
def main [
  1:num <- call f, 34
]
def f x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1

:(scenario call_shape_shifting_recipe_inside_shape_shifting_recipe)
def main [
  1:num <- f 34
]
def f x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- call g x
]
def g x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1

:(scenario call_shape_shifting_recipe_repeatedly_inside_shape_shifting_recipe)
def main [
  1:num <- f 34
]
def f x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- call g x
  y <- call g x
]
def g x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 1

//:: check types for 'call' instructions

:(scenario call_check_literal_recipe)
% Hide_errors = true;
def main [
  1:num <- call f, 34
]
def f x:point -> y:point [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: ingredient 0 has the wrong type at '1:num <- call f, 34'
+error: main: product 0 has the wrong type at '1:num <- call f, 34'

:(scenario call_check_variable_recipe)
% Hide_errors = true;
def main [
  {1: (recipe point -> point)} <- copy f
  2:num <- call {1: (recipe point -> point)}, 34
]
def f x:point -> y:point [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: ingredient 0 has the wrong type at '2:num <- call {1: (recipe point -> point)}, 34'
+error: main: product 0 has the wrong type at '2:num <- call {1: (recipe point -> point)}, 34'

:(before "End resolve_ambiguous_call(r, index, inst, caller_recipe) Special-cases")
if (inst.name == "call" && !inst.ingredients.empty() && is_recipe_literal(inst.ingredients.at(0))) {
  resolve_indirect_ambiguous_call(r, index, inst, caller_recipe);
  return;
}
:(code)
bool is_recipe_literal(const reagent& x) {
  return x.type && x.type->atom && x.type->name == "recipe-literal";
}
void resolve_indirect_ambiguous_call(const recipe_ordinal r, int index, instruction& inst, const recipe& caller_recipe) {
  instruction inst2;
  inst2.name = inst.ingredients.at(0).name;
  for (int i = /*skip recipe*/1;  i < SIZE(inst.ingredients);  ++i)
    inst2.ingredients.push_back(inst.ingredients.at(i));
  for (int i = 0;  i < SIZE(inst.products);  ++i)
    inst2.products.push_back(inst.products.at(i));
  resolve_ambiguous_call(r, index, inst2, caller_recipe);
  inst.ingredients.at(0).name = inst2.name;
  inst.ingredients.at(0).set_value(get(Recipe_ordinal, inst2.name));
}

:(after "Transform.push_back(check_instruction)")
Transform.push_back(check_indirect_calls_against_header);  // idempotent
:(code)
void check_indirect_calls_against_header(const recipe_ordinal r) {
  trace(9991, "transform") << "--- type-check 'call' instructions inside recipe " << get(Recipe, r).name << end();
  const recipe& caller = get(Recipe, r);
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    const instruction& inst = caller.steps.at(i);
    if (!is_indirect_call(inst.operation)) continue;
    if (inst.ingredients.empty()) continue;  // error raised above
    const reagent& callee = inst.ingredients.at(0);
    if (!is_mu_recipe(callee)) continue;  // error raised above
    const recipe callee_header = is_literal(callee) ? get(Recipe, callee.value) : from_reagent(inst.ingredients.at(0));
    if (!callee_header.has_header) continue;
    if (is_indirect_call_with_ingredients(inst.operation)) {
      for (long int i = /*skip callee*/1;  i < min(SIZE(inst.ingredients), SIZE(callee_header.ingredients)+/*skip callee*/1);  ++i) {
        if (!types_coercible(callee_header.ingredients.at(i-/*skip callee*/1), inst.ingredients.at(i)))
          raise << maybe(caller.name) << "ingredient " << i-/*skip callee*/1 << " has the wrong type at '" << to_original_string(inst) << "'\n" << end();
      }
    }
    if (is_indirect_call_with_products(inst.operation)) {
      for (long int i = 0;  i < min(SIZE(inst.products), SIZE(callee_header.products));  ++i) {
        if (is_dummy(inst.products.at(i))) continue;
        if (!types_coercible(callee_header.products.at(i), inst.products.at(i)))
          raise << maybe(caller.name) << "product " << i << " has the wrong type at '" << to_original_string(inst) << "'\n" << end();
      }
    }
  }
}

bool is_indirect_call(const recipe_ordinal r) {
  return is_indirect_call_with_ingredients(r) || is_indirect_call_with_products(r);
}

bool is_indirect_call_with_ingredients(const recipe_ordinal r) {
  if (r == CALL) return true;
  // End is_indirect_call_with_ingredients Special-cases
  return false;
}
bool is_indirect_call_with_products(const recipe_ordinal r) {
  if (r == CALL) return true;
  // End is_indirect_call_with_products Special-cases
  return false;
}

recipe from_reagent(const reagent& r) {
  assert(r.type);
  recipe result_header;  // will contain only ingredients and products, nothing else
  result_header.has_header = true;
  // Begin Reagent->Recipe(r, recipe_header)
  if (r.type->atom) {
    assert(r.type->name == "recipe");
    return result_header;
  }
  const type_tree* root_type = r.type->atom ? r.type : r.type->left;
  assert(root_type->atom);
  assert(root_type->name == "recipe");
  const type_tree* curr = r.type->right;
  for (/*nada*/;  curr && !curr->atom;  curr = curr->right) {
    if (curr->left->atom && curr->left->name == "->") {
      curr = curr->right;  // skip delimiter
      goto read_products;
    }
    result_header.ingredients.push_back(next_recipe_reagent(curr->left));
  }
  if (curr) {
    assert(curr->atom);
    result_header.ingredients.push_back(next_recipe_reagent(curr));
    return result_header;  // no products
  }
  read_products:
  for (/*nada*/;  curr && !curr->atom;  curr = curr->right)
    result_header.products.push_back(next_recipe_reagent(curr->left));
  if (curr) {
    assert(curr->atom);
    result_header.products.push_back(next_recipe_reagent(curr));
  }
  return result_header;
}

:(before "End Unit Tests")
void test_from_reagent_atomic() {
  reagent a("{f: recipe}");
  recipe r_header = from_reagent(a);
  CHECK(r_header.ingredients.empty());
  CHECK(r_header.products.empty());
}
void test_from_reagent_non_atomic() {
  reagent a("{f: (recipe number -> number)}");
  recipe r_header = from_reagent(a);
  CHECK_EQ(SIZE(r_header.ingredients), 1);
  CHECK_EQ(SIZE(r_header.products), 1);
}
void test_from_reagent_reads_ingredient_at_end() {
  reagent a("{f: (recipe number number)}");
  recipe r_header = from_reagent(a);
  CHECK_EQ(SIZE(r_header.ingredients), 2);
  CHECK(r_header.products.empty());
}
void test_from_reagent_reads_sole_ingredient_at_end() {
  reagent a("{f: (recipe number)}");
  recipe r_header = from_reagent(a);
  CHECK_EQ(SIZE(r_header.ingredients), 1);
  CHECK(r_header.products.empty());
}

:(code)
reagent next_recipe_reagent(const type_tree* curr) {
  if (!curr->left) return reagent("recipe:"+curr->name);
  reagent result;
  result.name = "recipe";
  result.type = new type_tree(*curr);
  return result;
}

bool is_mu_recipe(const reagent& r) {
  if (!r.type) return false;
  if (r.type->atom) {
    // End is_mu_recipe Atom Cases(r)
    return r.type->name == "recipe-literal";
  }
  return r.type->left->atom && r.type->left->name == "recipe";
}

:(scenario copy_typecheck_recipe_variable)
% Hide_errors = true;
def main [
  3:num <- copy 34  # abc def
  {1: (recipe number -> number)} <- copy f  # store literal in a matching variable
  {2: (recipe boolean -> boolean)} <- copy {1: (recipe number -> number)}  # mismatch between recipe variables
]
def f x:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: can't copy '{1: (recipe number -> number)}' to '{2: (recipe boolean -> boolean)}'; types don't match

:(scenario copy_typecheck_recipe_variable_2)
% Hide_errors = true;
def main [
  {1: (recipe number -> number)} <- copy f  # mismatch with a recipe literal
]
def f x:bool -> y:bool [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: can't copy 'f' to '{1: (recipe number -> number)}'; types don't match

:(before "End Matching Types For Literal(to)")
if (is_mu_recipe(to)) {
  if (!contains_key(Recipe, from.value)) {
    raise << "trying to store recipe " << from.name << " into " << to_string(to) << " but there's no such recipe\n" << end();
    return false;
  }
  const recipe& rrhs = get(Recipe, from.value);
  const recipe& rlhs = from_reagent(to);
  for (long int i = 0;  i < min(SIZE(rlhs.ingredients), SIZE(rrhs.ingredients));  ++i) {
    if (!types_match(rlhs.ingredients.at(i), rrhs.ingredients.at(i)))
      return false;
  }
  for (long int i = 0;  i < min(SIZE(rlhs.products), SIZE(rrhs.products));  ++i) {
    if (!types_match(rlhs.products.at(i), rrhs.products.at(i)))
      return false;
  }
  return true;
}

:(scenario call_variable_compound_ingredient)
def main [
  {1: (recipe (address number) -> number)} <- copy f
  2:&:num <- copy 0
  3:num <- call {1: (recipe (address number) -> number)}, 2:&:num
]
def f x:&:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
$error: 0

//: make sure we don't accidentally break on a recipe literal
:(scenario jump_forbidden_on_recipe_literals)
% Hide_errors = true;
def foo [
  local-scope
]
def main [
  local-scope
  {
    break-if foo
  }
]
# error should be as if foo is not a recipe
+error: main: missing type for 'foo' in 'break-if foo'

:(before "End JUMP_IF Checks")
check_for_recipe_literals(inst, get(Recipe, r));
:(before "End JUMP_UNLESS Checks")
check_for_recipe_literals(inst, get(Recipe, r));
:(code)
void check_for_recipe_literals(const instruction& inst, const recipe& caller) {
  for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
    if (is_mu_recipe(inst.ingredients.at(i))) {
      raise << maybe(caller.name) << "missing type for '" << inst.ingredients.at(i).original_string << "' in '" << to_original_string(inst) << "'\n" << end();
      if (is_present_in_ingredients(caller, inst.ingredients.at(i).name))
        raise << "  did you forget 'load-ingredients'?\n" << end();
    }
  }
}

:(scenario load_ingredients_missing_error_3)
% Hide_errors = true;
def foo {f: (recipe num -> num)} [
  local-scope
  b:num <- call f, 1
]
+error: foo: missing type for 'f' in 'b:num <- call f, 1'
+error:   did you forget 'load-ingredients'?

:(before "End Mu Types Initialization")
put(Type_abbreviations, "function", new_type_tree("recipe"));

:(scenario call_function)
def main [
  {1: (function number -> number)} <- copy f
  2:num <- call {1: (function number -> number)}, 34
]
def f x:num -> y:num [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 34 in location 2
