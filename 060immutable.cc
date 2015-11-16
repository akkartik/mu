//: Addresses passed into of a recipe are meant to be immutable unless they're
//: also products. This layer will start enforcing this check.

:(scenario can_modify_value_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:point <- new point:type
  foo *p
]
recipe foo p:point [
  local-scope
  load-ingredients
  x:address:number <- get-address p, x:offset
  *x <- copy 34
]
$warn: 0

:(scenario can_modify_ingredients_that_are_also_products)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:point <- new point:type
  p <- foo p
]
recipe foo p:address:point -> p:address:point [
  local-scope
  load-ingredients
  x:address:number <- get-address *p, x:offset
  *x <- copy 34
]
$warn: 0

:(scenario cannot_take_address_inside_immutable_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:point <- new point:type
  foo p
]
recipe foo p:address:point [
  local-scope
  load-ingredients
  x:address:number <- get-address *p, x:offset
  *x <- copy 34
]
+warn: foo: cannot modify ingredient p after instruction 'x:address:number <- get-address *p, x:offset' because it's not also a product of foo

:(scenario cannot_call_mutating_recipes_on_immutable_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:point <- new point:type
  foo p
]
recipe foo p:address:point [
  local-scope
  load-ingredients
  bar p
]
recipe bar p:address:point -> p:address:point [
  local-scope
  load-ingredients
  x:address:number <- get-address *p, x:offset
  *x <- copy 34
]
+warn: foo: cannot modify ingredient p at instruction 'bar p' because it's not also a product of foo

:(scenario can_traverse_immutable_ingredients)
% Hide_warnings = true;
container test-list [
  next:address:test-list
]
recipe main [
  local-scope
  p:address:test-list <- new test-list:type
  foo p
]
recipe foo p:address:test-list [
  local-scope
  load-ingredients
  p2:address:test-list <- bar p
]
recipe bar x:address:test-list -> y:address:test-list [
  local-scope
  load-ingredients
  y <- get *x, next:offset
]
$warn: 0

:(before "End Transforms")
Transform.push_back(check_immutable_ingredients);  // idempotent

:(code)
void check_immutable_ingredients(recipe_ordinal r) {
  // to ensure a reagent isn't modified, it suffices to show that we never
  // call get-address or index-address with it, and that any non-primitive
  // recipe calls in the body aren't returning it as a product.
  const recipe& caller = get(Recipe, r);
  if (!caller.has_header) return;  // skip check for old-style recipes calling next-ingredient directly
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i) {
    const reagent& current_ingredient = caller.ingredients.at(i);
    if (!is_mu_address(current_ingredient)) continue;  // will be copied
    if (is_present_in_products(caller, current_ingredient.name)) continue;  // not expected to be immutable
    // End Immutable Ingredients Special-cases
    for (long long int i = 0; i < SIZE(caller.steps); ++i) {
      check_immutable_ingredient_in_instruction(caller.steps.at(i), current_ingredient.name, caller);
    }
  }
}

void check_immutable_ingredient_in_instruction(const instruction& inst, const string& current_ingredient_name, const recipe& caller) {
  long long int current_ingredient_index = find_ingredient_index(inst, current_ingredient_name);
  if (current_ingredient_index == -1) return;  // ingredient not found in call
  reagent current_ingredient = inst.ingredients.at(current_ingredient_index);
  canonize_type(current_ingredient);
  if (!contains_key(Recipe, inst.operation)) {
    // primitive recipe
    if (inst.operation == GET_ADDRESS || inst.operation == INDEX_ADDRESS)
      raise << maybe(caller.name) << "cannot modify ingredient " << current_ingredient_name << " after instruction '" << inst.to_string() << "' because it's not also a product of " << caller.name << '\n' << end();
  }
  else {
    // defined recipe
    if (!is_mu_address(current_ingredient)) return;  // making a copy is ok
    if (is_modified_in_recipe(inst.operation, current_ingredient_index, caller))
      raise << maybe(caller.name) << "cannot modify ingredient " << current_ingredient_name << " at instruction '" << inst.to_string() << "' because it's not also a product of " << caller.name << '\n' << end();
  }
}

bool is_modified_in_recipe(recipe_ordinal r, long long int ingredient_index, const recipe& caller) {
  const recipe& callee = get(Recipe, r);
  if (!callee.has_header) {
    raise << maybe(caller.name) << "can't check mutability of ingredients in " << callee.name << " because it uses 'next-ingredient' directly, rather than a recipe header.\n" << end();
    return true;
  }
  return is_present_in_products(callee, callee.ingredients.at(ingredient_index).name);
}

bool is_present_in_products(const recipe& callee, const string& ingredient_name) {
  for (long long int i = 0; i < SIZE(callee.products); ++i) {
    if (callee.products.at(i).name == ingredient_name)
      return true;
  }
  return false;
}

bool is_present_in_ingredients(const recipe& callee, const string& ingredient_name) {
  for (long long int i = 0; i < SIZE(callee.ingredients); ++i) {
    if (callee.ingredients.at(i).name == ingredient_name)
      return true;
  }
  return false;
}

long long int find_ingredient_index(const instruction& inst, const string& ingredient_name) {
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (inst.ingredients.at(i).name == ingredient_name)
      return i;
  }
  return -1;
}

//: Sometimes you want to pass in two addresses, one pointing inside the
//: other. For example, you want to delete a node from a linked list. You
//: can't pass both pointers back out, because if a caller tries to make both
//: identical then you can't tell which value will be written on the way out.
//:
//: Experimental solution: just tell mu that one points inside the other.
//: This way we can return just one pointer as high up as necessary to capture
//: all modifications performed by a recipe.
//:
//: We'll see if we end up wanting to abuse /contained-in for other reasons.

:(scenarios transform)
:(scenario can_modify_contained_in_addresses)
#% Hide_warnings = true;
container test-list [
  next:address:test-list
]
recipe main [
  local-scope
  p:address:test-list <- new test-list:type
  foo p
]
recipe foo p:address:test-list -> p:address:test-list [
  local-scope
  load-ingredients
  p2:address:test-list <- test-next p
  p <- test-remove p2, p
]
recipe test-next x:address:test-list -> y:address:test-list [
  local-scope
  load-ingredients
  y <- get *x, next:offset
]
recipe test-remove x:address:test-list/contained-in:from, from:address:test-list -> from:address:test-list [
  local-scope
  load-ingredients
  x2:address:address:test-list <- get-address *x, next:offset  # pretend modification
]
$warn: 0

:(before "End Immutable Ingredients Special-cases")
if (has_property(current_ingredient, "contained-in")) {
  const string_tree* tmp = property(current_ingredient, "contained-in");
  if (tmp->left || tmp->right
      || !is_present_in_ingredients(caller, tmp->value)
      || !is_present_in_products(caller, tmp->value))
    raise_error << maybe(caller.name) << "contained-in can only point to another ingredient+product, but got " << debug_string(property(current_ingredient, "contained-in")) << '\n' << end();
  continue;
}
