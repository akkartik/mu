//: Addresses passed into of a recipe are meant to be immutable unless they're
//: also products. This layer will start enforcing this check.

:(scenario can_modify_value_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:shared:point <- new point:type
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
  p:address:shared:point <- new point:type
  p <- foo p
]
recipe foo p:address:shared:point -> p:address:shared:point [
  local-scope
  load-ingredients
  x:address:number <- get-address *p, x:offset
  *x <- copy 34
]
$warn: 0

:(scenario ignore_literal_ingredients_for_immutability_checks)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:shared:d1 <- new d1:type
  q:number <- foo p
]
recipe foo p:address:shared:d1 -> q:number [
  local-scope
  load-ingredients
  x:address:shared:d1 <- new d1:type
  y:address:number <- get-address *x, p:offset  # ignore this 'p'
  q <- copy 34
]
container d1 [
  p:number
  q:number
]
$warn: 0

:(scenario cannot_take_address_inside_immutable_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:shared:point <- new point:type
  foo p
]
recipe foo p:address:shared:point [
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
  p:address:shared:point <- new point:type
  foo p
]
recipe foo p:address:shared:point [
  local-scope
  load-ingredients
  bar p
]
recipe bar p:address:shared:point -> p:address:shared:point [
  local-scope
  load-ingredients
  x:address:number <- get-address *p, x:offset
  *x <- copy 34
]
+warn: foo: cannot modify ingredient p at instruction 'bar p' because it's not also a product of foo

:(scenario cannot_modify_copies_of_immutable_ingredients)
% Hide_warnings = true;
recipe main [
  local-scope
  p:address:shared:point <- new point:type
  foo p
]
recipe foo p:address:shared:point [
  local-scope
  load-ingredients
  q:address:shared:point <- copy p
  x:address:number <- get-address *q, x:offset
]
+warn: foo: cannot modify q after instruction 'x:address:number <- get-address *q, x:offset' because that would modify ingredient p which is not also a product of foo

:(scenario can_traverse_immutable_ingredients)
% Hide_warnings = true;
container test-list [
  next:address:shared:test-list
]
recipe main [
  local-scope
  p:address:shared:test-list <- new test-list:type
  foo p
]
recipe foo p:address:shared:test-list [
  local-scope
  load-ingredients
  p2:address:shared:test-list <- bar p
]
recipe bar x:address:shared:test-list -> y:address:shared:test-list [
  local-scope
  load-ingredients
  y <- get *x, next:offset
]
$warn: 0

:(scenario handle_optional_ingredients_in_immutability_checks)
% Hide_warnings = true;
recipe main [
  k:address:shared:number <- new number:type
  test k
]
# recipe taking an immutable address ingredient
recipe test k:address:shared:number [
  local-scope
  load-ingredients
  foo k
]
# ..calling a recipe with an optional address ingredient
recipe foo -> [
  local-scope
  load-ingredients
  k:address:shared:number, found?:boolean <- next-ingredient
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
  trace(9991, "transform") << "--- check mutability of ingredients in recipe " << caller.name << end();
  if (!caller.has_header) return;  // skip check for old-style recipes calling next-ingredient directly
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i) {
    const reagent& current_ingredient = caller.ingredients.at(i);
    if (!is_mu_address(current_ingredient)) continue;  // will be copied
    if (is_present_in_products(caller, current_ingredient.name)) continue;  // not expected to be immutable
    // End Immutable Ingredients Special-cases
    set<string> immutable_vars;
    immutable_vars.insert(current_ingredient.name);
    for (long long int i = 0; i < SIZE(caller.steps); ++i) {
      const instruction& inst = caller.steps.at(i);
      check_immutable_ingredient_in_instruction(inst, immutable_vars, current_ingredient.name, caller);
      update_aliases(inst, immutable_vars);
    }
  }
}

void update_aliases(const instruction& inst, set<string>& current_ingredient_and_aliases) {
  set<long long int> current_ingredient_indices = ingredient_indices(inst, current_ingredient_and_aliases);
  if (!contains_key(Recipe, inst.operation)) {
    // primitive recipe
    if (inst.operation == COPY) {
      for (set<long long int>::iterator p = current_ingredient_indices.begin(); p != current_ingredient_indices.end(); ++p) {
        current_ingredient_and_aliases.insert(inst.products.at(*p).name);
      }
    }
  }
  else {
    // defined recipe
    set<long long int> contained_in_product_indices = scan_contained_in_product_indices(inst, current_ingredient_indices);
    for (set<long long int>::iterator p = contained_in_product_indices.begin(); p != contained_in_product_indices.end(); ++p) {
      if (*p < SIZE(inst.products))
        current_ingredient_and_aliases.insert(inst.products.at(*p).name);
    }
  }
}

set<long long int> scan_contained_in_product_indices(const instruction& inst, set<long long int>& ingredient_indices) {
  set<string> selected_ingredient_names;
  const recipe& callee = get(Recipe, inst.operation);
  for (set<long long int>::iterator p = ingredient_indices.begin(); p != ingredient_indices.end(); ++p) {
    if (*p >= SIZE(callee.ingredients)) continue;  // optional immutable ingredient
    selected_ingredient_names.insert(callee.ingredients.at(*p).name);
  }
  set<long long int> result;
  for (long long int i = 0; i < SIZE(callee.products); ++i) {
    const reagent& current_product = callee.products.at(i);
    const string_tree* contained_in_name = property(current_product, "contained-in");
    if (contained_in_name && selected_ingredient_names.find(contained_in_name->value) != selected_ingredient_names.end())
      result.insert(i);
  }
  return result;
}

:(scenarios transform)
:(scenario immutability_infects_contained_in_variables)
% Hide_warnings = true;
container test-list [
  next:address:shared:test-list
]
recipe main [
  local-scope
  p:address:shared:test-list <- new test-list:type
  foo p
]
recipe foo p:address:shared:test-list [  # p is immutable
  local-scope
  load-ingredients
  p2:address:shared:test-list <- test-next p  # p2 is immutable
  p3:address:address:shared:test-list <- get-address *p2, next:offset  # signal modification of p2
]
recipe test-next x:address:shared:test-list -> y:address:shared:test-list/contained-in:x [
  local-scope
  load-ingredients
  y <- get *x, next:offset
]
+warn: foo: cannot modify p2 after instruction 'p3:address:address:shared:test-list <- get-address *p2, next:offset' because that would modify ingredient p which is not also a product of foo

:(code)
void check_immutable_ingredient_in_instruction(const instruction& inst, const set<string>& current_ingredient_and_aliases, const string& original_ingredient_name, const recipe& caller) {
  set<long long int> current_ingredient_indices = ingredient_indices(inst, current_ingredient_and_aliases);
  if (current_ingredient_indices.empty()) return;  // ingredient not found in call
  for (set<long long int>::iterator p = current_ingredient_indices.begin(); p != current_ingredient_indices.end(); ++p) {
    const long long int current_ingredient_index = *p;
    reagent current_ingredient = inst.ingredients.at(current_ingredient_index);
    canonize_type(current_ingredient);
    const string& current_ingredient_name = current_ingredient.name;
    if (!contains_key(Recipe, inst.operation)) {
      // primitive recipe
      if (inst.operation == GET_ADDRESS || inst.operation == INDEX_ADDRESS) {
        if (current_ingredient_name == original_ingredient_name)
          raise << maybe(caller.name) << "cannot modify ingredient " << current_ingredient_name << " after instruction '" << to_string(inst) << "' because it's not also a product of " << caller.name << '\n' << end();
        else
          raise << maybe(caller.name) << "cannot modify " << current_ingredient_name << " after instruction '" << to_string(inst) << "' because that would modify ingredient " << original_ingredient_name << " which is not also a product of " << caller.name << '\n' << end();
      }
    }
    else {
      // defined recipe
      if (!is_mu_address(current_ingredient)) return;  // making a copy is ok
      if (is_modified_in_recipe(inst.operation, current_ingredient_index, caller)) {
        if (current_ingredient_name == original_ingredient_name)
          raise << maybe(caller.name) << "cannot modify ingredient " << current_ingredient_name << " at instruction '" << to_string(inst) << "' because it's not also a product of " << caller.name << '\n' << end();
        else
          raise << maybe(caller.name) << "cannot modify " << current_ingredient_name << " after instruction '" << to_string(inst) << "' because that would modify ingredient " << original_ingredient_name << " which is not also a product of " << caller.name << '\n' << end();
      }
    }
  }
}

bool is_modified_in_recipe(recipe_ordinal r, long long int ingredient_index, const recipe& caller) {
  const recipe& callee = get(Recipe, r);
  if (!callee.has_header) {
    raise << maybe(caller.name) << "can't check mutability of ingredients in " << callee.name << " because it uses 'next-ingredient' directly, rather than a recipe header.\n" << end();
    return true;
  }
  if (ingredient_index >= SIZE(callee.ingredients)) return false;  // optional immutable ingredient
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

set<long long int> ingredient_indices(const instruction& inst, const set<string>& ingredient_names) {
  set<long long int> result;
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (is_literal(inst.ingredients.at(i))) continue;
    if (ingredient_names.find(inst.ingredients.at(i).name) != ingredient_names.end())
      result.insert(i);
  }
  return result;
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
% Hide_warnings = true;
container test-list [
  next:address:shared:test-list
]
recipe main [
  local-scope
  p:address:shared:test-list <- new test-list:type
  foo p
]
recipe foo p:address:shared:test-list -> p:address:shared:test-list [
  local-scope
  load-ingredients
  p2:address:shared:test-list <- test-next p
  p <- test-remove p2, p
]
recipe test-next x:address:shared:test-list -> y:address:shared:test-list [
  local-scope
  load-ingredients
  y <- get *x, next:offset
]
recipe test-remove x:address:shared:test-list/contained-in:from, from:address:shared:test-list -> from:address:shared:test-list [
  local-scope
  load-ingredients
  x2:address:address:shared:test-list <- get-address *x, next:offset  # pretend modification
]
$warn: 0

:(before "End Immutable Ingredients Special-cases")
if (has_property(current_ingredient, "contained-in")) {
  const string_tree* tmp = property(current_ingredient, "contained-in");
  if (tmp->left || tmp->right
      || !is_present_in_ingredients(caller, tmp->value)
      || !is_present_in_products(caller, tmp->value))
    raise_error << maybe(caller.name) << "contained-in can only point to another ingredient+product, but got " << to_string(property(current_ingredient, "contained-in")) << '\n' << end();
  continue;
}
