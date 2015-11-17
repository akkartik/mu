//:: Like container definitions, recipes too can contain type parameters.

:(scenario shape_shifting_recipe)
recipe main [
  10:point <- merge 14, 15
  11:point <- foo 10:point
]
# non-matching variant
recipe foo a:number -> result:number [
  local-scope
  load-ingredients
  result <- copy 34
]
# matching shape-shifting variant
recipe foo a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 14 in location 11
+mem: storing 15 in location 12

//: Before anything else, disable transforms for shape-shifting recipes and
//: make sure we never try to actually run a shape-shifting recipe. We should
//: be rewriting such instructions to *specializations* with the type
//: ingredients filled in.

:(before "End Transform Checks")
if (any_type_ingredient_in_header(/*recipe_ordinal*/p->first)) continue;

:(after "Running One Instruction")
if (Current_routine->calls.front().running_step_index == 0
    && any_type_ingredient_in_header(Current_routine->calls.front().running_recipe)) {
//?   DUMP("");
  raise_error << "ran into unspecialized shape-shifting recipe " << current_recipe_name() << '\n' << end();
}

//: Make sure we don't match up literals with type ingredients without
//: specialization.
:(before "End valid_type_for_literal Special-cases")
if (contains_type_ingredient_name(lhs)) return false;

//: We'll be creating recipes without loading them from anywhere by
//: *specializing* existing recipes, so make sure we don't clear any of those
//: when we start running tests.
:(before "End Loading .mu Files")
recently_added_recipes.clear();
recently_added_types.clear();

:(before "End Instruction Dispatch(inst, best_score)")
if (best_score == -1) {
//?   if (inst.name == "push-duplex") Trace_stream = new trace_stream;
  trace(9992, "transform") << "no variant found; searching for variant with suitable type ingredients" << end();
  recipe_ordinal exemplar = pick_matching_shape_shifting_variant(variants, inst, best_score);
  if (exemplar) {
    trace(9992, "transform") << "found variant to specialize: " << exemplar << ' ' << get(Recipe, exemplar).name << end();
    variants.push_back(new_variant(exemplar, inst, caller_recipe));
//?     cerr << "-- replacing " << inst.name << " with " << get(Recipe, variants.back()).name << '\n' << debug_string(get(Recipe, variants.back()));
    inst.name = get(Recipe, variants.back()).name;
    trace(9992, "transform") << "new specialization: " << inst.name << end();
  }
//?   if (inst.name == "push-duplex") {
//?     cerr << "======== {\n";
//?     cerr << inst.to_string() << '\n';
//?     DUMP("");
//?     cerr << "======== }\n";
//?   }
}

:(code)
recipe_ordinal pick_matching_shape_shifting_variant(vector<recipe_ordinal>& variants, const instruction& inst, long long int& best_score) {
//?   cerr << "---- " << inst.name << ": " << non_ghost_size(variants) << '\n';
  recipe_ordinal result = 0;
  for (long long int i = 0; i < SIZE(variants); ++i) {
    if (variants.at(i) == -1) continue;  // ghost from a previous test
//?     cerr << "-- variant " << i << "\n" << debug_string(get(Recipe, variants.at(i)));
    trace(9992, "transform") << "checking shape-shifting variant " << i << end();
    long long int current_score = shape_shifting_variant_score(inst, variants.at(i));
    trace(9992, "transform") << "final score: " << current_score << end();
//?     cerr << get(Recipe, variants.at(i)).name << ": " << current_score << '\n';
    if (current_score > best_score) {
      trace(9992, "transform") << "matches" << end();
      result = variants.at(i);
      best_score = current_score;
    }
  }
  return result;
}

long long int shape_shifting_variant_score(const instruction& inst, recipe_ordinal variant) {
//?   cerr << "======== " << inst.to_string() << '\n';
  if (!any_type_ingredient_in_header(variant)) {
    trace(9993, "transform") << "no type ingredients" << end();
    return -1;
  }
  const vector<reagent>& header_ingredients = get(Recipe, variant).ingredients;
  if (SIZE(inst.ingredients) < SIZE(header_ingredients)) {
    trace(9993, "transform") << "too few ingredients" << end();
    return -1;
  }
  for (long long int i = 0; i < SIZE(header_ingredients); ++i) {
    if (!deeply_equal_concrete_types(header_ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "mismatch: ingredient " << i << end();
      return -1;
    }
  }
  if (SIZE(inst.products) > SIZE(get(Recipe, variant).products)) {
    trace(9993, "transform") << "too few products" << end();
    return -1;
  }
  const vector<reagent>& header_products = get(Recipe, variant).products;
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (!deeply_equal_concrete_types(header_products.at(i), inst.products.at(i))) {
      trace(9993, "transform") << "mismatch: product " << i << end();
      return -1;
    }
  }
  // the greater the number of unused ingredients, the lower the score
  return 100 - (SIZE(get(Recipe, variant).products)-SIZE(inst.products))
             - (SIZE(inst.ingredients)-SIZE(get(Recipe, variant).ingredients));  // ok to go negative
}

bool any_type_ingredient_in_header(recipe_ordinal variant) {
  for (long long int i = 0; i < SIZE(get(Recipe, variant).ingredients); ++i) {
    if (contains_type_ingredient_name(get(Recipe, variant).ingredients.at(i)))
      return true;
  }
  for (long long int i = 0; i < SIZE(get(Recipe, variant).products); ++i) {
    if (contains_type_ingredient_name(get(Recipe, variant).products.at(i)))
      return true;
  }
  return false;
}

bool deeply_equal_concrete_types(reagent lhs, reagent rhs) {
//?   cerr << debug_string(lhs) << " vs " << debug_string(rhs) << '\n';
//?   bool result = deeply_equal_concrete_types(lhs.properties.at(0).second, rhs.properties.at(0).second, rhs);
//?   cerr << "  => " << result << '\n';
//?   return result;
//?   cerr << "== " << debug_string(lhs) << " vs " << debug_string(rhs) << '\n';
  canonize_type(lhs);
  canonize_type(rhs);
  return deeply_equal_concrete_types(lhs.properties.at(0).second, rhs.properties.at(0).second, rhs);
}

bool deeply_equal_concrete_types(const string_tree* lhs, const string_tree* rhs, const reagent& rhs_reagent) {
  if (!lhs) return !rhs;
  if (!rhs) return !lhs;
  if (is_type_ingredient_name(lhs->value)) return true;  // type ingredient matches anything
  if (Literal_type_names.find(lhs->value) != Literal_type_names.end())
    return Literal_type_names.find(rhs->value) != Literal_type_names.end();
  if (rhs->value == "literal" && lhs->value == "address")
    return rhs_reagent.name == "0";
//?   cerr << lhs->value << " vs " << rhs->value << '\n';
  return lhs->value == rhs->value
      && deeply_equal_concrete_types(lhs->left, rhs->left, rhs_reagent)
      && deeply_equal_concrete_types(lhs->right, rhs->right, rhs_reagent);
}

bool contains_type_ingredient_name(const reagent& x) {
  return contains_type_ingredient_name(x.properties.at(0).second);
}

bool contains_type_ingredient_name(const string_tree* type) {
  if (!type) return false;
  if (is_type_ingredient_name(type->value)) return true;
  return contains_type_ingredient_name(type->left) || contains_type_ingredient_name(type->right);
}

bool is_type_ingredient_name(const string& type) {
  return !type.empty() && type.at(0) == '_';
}

recipe_ordinal new_variant(recipe_ordinal exemplar, const instruction& inst, const recipe& caller_recipe) {
  string new_name = next_unused_recipe_name(inst.name);
  trace(9993, "transform") << "switching " << inst.name << " to " << new_name << end();
  assert(!contains_key(Recipe_ordinal, new_name));
  recipe_ordinal new_recipe_ordinal = put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
  // make a copy
  assert(contains_key(Recipe, exemplar));
  assert(!contains_key(Recipe, new_recipe_ordinal));
  recently_added_recipes.push_back(new_recipe_ordinal);
  put(Recipe, new_recipe_ordinal, get(Recipe, exemplar));
  recipe& new_recipe = get(Recipe, new_recipe_ordinal);
  // Since the exemplar never ran any transforms, we have to redo some of the
  // work of the check_types_by_name transform while supporting type-ingredients.
  compute_type_names(new_recipe);
  // that gives enough information to replace type-ingredients with concrete types
  {
    map<string, const string_tree*> mappings;
    bool error = false;
    compute_type_ingredient_mappings(get(Recipe, exemplar), inst, mappings, caller_recipe, &error);
    if (!error) replace_type_ingredients(new_recipe, mappings);
    for (map<string, const string_tree*>::iterator p = mappings.begin(); p != mappings.end(); ++p)
      delete p->second;
    if (error) return exemplar;
  }
  ensure_all_concrete_types(new_recipe, get(Recipe, exemplar));
  // update the name after specialization is complete (so earlier error messages look better)
  new_recipe.name = new_name;
  // perform all transforms on the new specialization
  for (long long int t = 0; t < SIZE(Transform); ++t) {
    (*Transform.at(t))(new_recipe_ordinal);
  }
  new_recipe.transformed_until = SIZE(Transform)-1;
  return new_recipe_ordinal;
}

void compute_type_names(recipe& variant) {
  trace(9993, "transform") << "compute type names: " << variant.name << end();
  map<string, string_tree*> type_names;
  for (long long int i = 0; i < SIZE(variant.ingredients); ++i)
    save_or_deduce_type_name(variant.ingredients.at(i), type_names, variant);
  for (long long int i = 0; i < SIZE(variant.products); ++i)
    save_or_deduce_type_name(variant.products.at(i), type_names, variant);
  for (long long int i = 0; i < SIZE(variant.steps); ++i) {
    instruction& inst = variant.steps.at(i);
    trace(9993, "transform") << "  instruction: " << inst.to_string() << end();
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in)
      save_or_deduce_type_name(inst.ingredients.at(in), type_names, variant);
    for (long long int out = 0; out < SIZE(inst.products); ++out)
      save_or_deduce_type_name(inst.products.at(out), type_names, variant);
  }
}

void save_or_deduce_type_name(reagent& x, map<string, string_tree*>& type_name, const recipe& variant) {
  trace(9994, "transform") << "    checking " << x.to_string() << ": " << debug_string(x.properties.at(0).second) << end();
  if (!x.properties.at(0).second && contains_key(type_name, x.name)) {
    x.properties.at(0).second = new string_tree(*get(type_name, x.name));
    trace(9994, "transform") << "    deducing type to " << debug_string(x.properties.at(0).second) << end();
    return;
  }
  if (!x.properties.at(0).second) {
    raise_error << maybe(variant.name) << "unknown type for " << x.original_string << " (check the name for typos)\n" << end();
    return;
  }
  if (contains_key(type_name, x.name)) return;
  if (x.properties.at(0).second->value == "offset" || x.properties.at(0).second->value == "variant") return;  // special-case for container-access instructions
  put(type_name, x.name, x.properties.at(0).second);
  trace(9993, "transform") << "type of " << x.name << " is " << debug_string(x.properties.at(0).second) << end();
}

void compute_type_ingredient_mappings(const recipe& exemplar, const instruction& inst, map<string, const string_tree*>& mappings, const recipe& caller_recipe, bool* error) {
  long long int limit = min(SIZE(inst.ingredients), SIZE(exemplar.ingredients));
  for (long long int i = 0; i < limit; ++i) {
    const reagent& exemplar_reagent = exemplar.ingredients.at(i);
    reagent ingredient = inst.ingredients.at(i);
    assert(ingredient.properties.at(0).second);
    canonize_type(ingredient);
    if (is_mu_address(exemplar_reagent) && ingredient.name == "0") continue;  // assume it matches
    accumulate_type_ingredients(exemplar_reagent, ingredient, mappings, exemplar, inst, caller_recipe, error);
  }
  limit = min(SIZE(inst.products), SIZE(exemplar.products));
  for (long long int i = 0; i < limit; ++i) {
    const reagent& exemplar_reagent = exemplar.products.at(i);
    reagent product = inst.products.at(i);
    assert(product.properties.at(0).second);
    canonize_type(product);
    accumulate_type_ingredients(exemplar_reagent, product, mappings, exemplar, inst, caller_recipe, error);
  }
}

inline long long int min(long long int a, long long int b) {
  return (a < b) ? a : b;
}

void accumulate_type_ingredients(const reagent& exemplar_reagent, reagent& refinement, map<string, const string_tree*>& mappings, const recipe& exemplar, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  assert(refinement.properties.at(0).second);
  accumulate_type_ingredients(exemplar_reagent.properties.at(0).second, refinement.properties.at(0).second, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
}

void accumulate_type_ingredients(const string_tree* exemplar_type, const string_tree* refinement_type, map<string, const string_tree*>& mappings, const recipe& exemplar, const reagent& exemplar_reagent, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  if (!exemplar_type) return;
  if (!refinement_type) {
    // todo: make this smarter; only warn if exemplar_type contains some *new* type ingredient
    raise_error << maybe(exemplar.name) << "missing type ingredient in " << exemplar_reagent.original_string << '\n' << end();
    return;
  }
  if (!exemplar_type->value.empty() && exemplar_type->value.at(0) == '_') {
    assert(!refinement_type->value.empty());
    if (exemplar_type->right) {
      raise_error << "type_ingredients in non-last position not currently supported\n" << end();
      return;
    }
    if (!contains_key(mappings, exemplar_type->value)) {
      trace(9993, "transform") << "adding mapping from " << exemplar_type->value << " to " << debug_string(refinement_type) << end();
      if (refinement_type->value == "literal")
        put(mappings, exemplar_type->value, new string_tree("number"));
      else
        put(mappings, exemplar_type->value, new string_tree(*refinement_type));
    }
    else {
      if (!deeply_equal_types(get(mappings, exemplar_type->value), refinement_type)) {
        raise_error << maybe(caller_recipe.name) << "no call found for '" << call_instruction.to_string() << "'\n" << end();
//?         cerr << exemplar_type->value << ": " << debug_string(get(mappings, exemplar_type->value)) << " vs " << debug_string(refinement_type) << '\n';
        *error = true;
        return;
      }
    }
  }
  else {
    accumulate_type_ingredients(exemplar_type->left, refinement_type->left, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
  }
  accumulate_type_ingredients(exemplar_type->right, refinement_type->right, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
}

void replace_type_ingredients(recipe& new_recipe, const map<string, const string_tree*>& mappings) {
  // update its header
  if (mappings.empty()) return;
  trace(9993, "transform") << "replacing in recipe header ingredients" << end();
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    replace_type_ingredients(new_recipe.ingredients.at(i), mappings, new_recipe);
  trace(9993, "transform") << "replacing in recipe header products" << end();
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i)
    replace_type_ingredients(new_recipe.products.at(i), mappings, new_recipe);
  // update its body
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    trace(9993, "transform") << "replacing in instruction '" << inst.to_string() << "'" << end();
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j)
      replace_type_ingredients(inst.ingredients.at(j), mappings, new_recipe);
    for (long long int j = 0; j < SIZE(inst.products); ++j)
      replace_type_ingredients(inst.products.at(j), mappings, new_recipe);
    // special-case for new: replace type ingredient in first ingredient *value*
    if (inst.name == "new" && inst.ingredients.at(0).name.at(0) != '[') {
      string_tree* type_name = parse_string_tree(inst.ingredients.at(0).name);
      replace_type_ingredients(type_name, mappings);
      inst.ingredients.at(0).name = type_name->to_string();
      delete type_name;
    }
  }
}

void replace_type_ingredients(reagent& x, const map<string, const string_tree*>& mappings, const recipe& caller) {
  trace(9993, "transform") << "replacing in ingredient " << x.original_string << end();
  // replace properties
  if (!x.properties.at(0).second) {
    raise_error << "specializing " << caller.name << ": missing type for " << x.original_string << '\n' << end();
    return;
  }
  replace_type_ingredients(x.properties.at(0).second, mappings);
  // refresh types from properties
  delete x.type;
  x.type = new_type_tree(x.properties.at(0).second);
  if (x.type)
    trace(9993, "transform") << "  after: " << debug_string(x.type) << end();
}

void replace_type_ingredients(string_tree* type, const map<string, const string_tree*>& mappings) {
  if (!type) return;
  if (is_type_ingredient_name(type->value) && contains_key(mappings, type->value)) {
    const string_tree* replacement = get(mappings, type->value);
    trace(9993, "transform") << type->value << " => " << debug_string(replacement) << end();
    type->value = replacement->value;
    if (replacement->left) type->left = new string_tree(*replacement->left);
    if (replacement->right) type->right = new string_tree(*replacement->right);
  }
  replace_type_ingredients(type->left, mappings);
  replace_type_ingredients(type->right, mappings);
}

void ensure_all_concrete_types(/*const*/ recipe& new_recipe, const recipe& exemplar) {
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    ensure_all_concrete_types(new_recipe.ingredients.at(i), exemplar);
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i)
    ensure_all_concrete_types(new_recipe.products.at(i), exemplar);
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j)
      ensure_all_concrete_types(inst.ingredients.at(j), exemplar);
    for (long long int j = 0; j < SIZE(inst.products); ++j)
      ensure_all_concrete_types(inst.products.at(j), exemplar);
  }
}

void ensure_all_concrete_types(/*const*/ reagent& x, const recipe& exemplar) {
  if (!x.type) {
    raise_error << maybe(exemplar.name) << "failed to map a type to " << x.original_string << '\n' << end();
    x.type = new type_tree(0);  // just to prevent crashes later
    return;
  }
  if (x.type->value == -1) {
    raise_error << maybe(exemplar.name) << "failed to map a type to the unknown " << x.original_string << '\n' << end();
    return;
  }
}

long long int non_ghost_size(vector<recipe_ordinal>& variants) {
  long long int result = 0;
  for (long long int i = 0; i < SIZE(variants); ++i)
    if (variants.at(i) != -1) ++result;
  return result;
}

:(scenario shape_shifting_recipe_2)
recipe main [
  10:point <- merge 14, 15
  11:point <- foo 10:point
]
# non-matching shape-shifting variant
recipe foo a:_t, b:_t -> result:number [
  local-scope
  load-ingredients
  result <- copy 34
]
# matching shape-shifting variant
recipe foo a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 14 in location 11
+mem: storing 15 in location 12

:(scenario shape_shifting_recipe_nonroot)
recipe main [
  10:foo:point <- merge 14, 15, 16
  20:point/raw <- bar 10:foo:point
]
# shape-shifting recipe with type ingredient following some other type
recipe bar a:foo:_t -> result:_t [
  local-scope
  load-ingredients
  result <- get a, x:offset
]
container foo:_t [
  x:_t
  y:number
]
+mem: storing 14 in location 20
+mem: storing 15 in location 21

:(scenario shape_shifting_recipe_type_deduction_ignores_offsets)
recipe main [
  10:foo:point <- merge 14, 15, 16
  20:point/raw <- bar 10:foo:point
]
recipe bar a:foo:_t -> result:_t [
  local-scope
  load-ingredients
  x:number <- copy 1
  result <- get a, x:offset  # shouldn't collide with other variable
]
container foo:_t [
  x:_t
  y:number
]
+mem: storing 14 in location 20
+mem: storing 15 in location 21

:(scenario shape_shifting_recipe_handles_shape_shifting_new_ingredient)
recipe main [
  1:address:foo:point <- bar 3
  11:foo:point <- copy *1:address:foo:point
]
container foo:_t [
  x:_t
  y:number
]
recipe bar x:number -> result:address:foo:_t [
  local-scope
  load-ingredients
  # new refers to _t in its ingredient *value*
  result <- new {(foo _t) : type}
]
+mem: storing 0 in location 11
+mem: storing 0 in location 12
+mem: storing 0 in location 13

:(scenario shape_shifting_recipe_handles_shape_shifting_new_ingredient_2)
recipe main [
  1:address:foo:point <- bar 3
  11:foo:point <- copy *1:address:foo:point
]
recipe bar x:number -> result:address:foo:_t [
  local-scope
  load-ingredients
  # new refers to _t in its ingredient *value*
  result <- new {(foo _t) : type}
]
# container defined after use
container foo:_t [
  x:_t
  y:number
]
+mem: storing 0 in location 11
+mem: storing 0 in location 12
+mem: storing 0 in location 13

:(scenario shape_shifting_recipe_supports_compound_types)
recipe main [
  1:address:point <- new point:type
  2:address:number <- get-address *1:address:point, y:offset
  *2:address:number <- copy 34
  3:address:point <- bar 1:address:point  # specialize _t to address:point
  4:point <- copy *3:address:point
]
recipe bar a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 34 in location 5

:(scenario shape_shifting_recipe_error)
% Hide_errors = true;
recipe main [
  a:number <- copy 3
  b:address:number <- foo a
]
recipe foo a:_t -> b:_t [
  load-ingredients
  b <- copy a
]
+error: main: no call found for 'b:address:number <- foo a'

:(scenario specialize_inside_recipe_without_header)
recipe main [
  foo 3
]
recipe foo [
  local-scope
  x:number <- next-ingredient  # ensure no header
  1:number/raw <- bar x  # call a shape-shifting recipe
]
recipe bar x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal)
recipe main [
  local-scope
  # permit literal to map to number
  1:number/raw <- foo 3
]
recipe foo x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal_2)
recipe main [
  local-scope
  # permit literal to map to character
  1:character/raw <- foo 3
]
recipe foo x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal_3)
% Hide_errors = true;
recipe main [
  local-scope
  # permit '0' to map to address to shape-shifting type-ingredient
  1:address:character/raw <- foo 0
]
recipe foo x:address:_elem -> y:address:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 0 in location 1
$error: 0

:(scenario specialize_with_literal_4)
% Hide_errors = true;
recipe main [
  local-scope
  # ambiguous call: what's the type of its ingredient?!
  foo 0
]
recipe foo x:address:_elem -> y:address:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+error: foo: failed to map a type to x
+error: foo: failed to map a type to y

:(scenario specialize_with_literal_5)
recipe main [
  foo 3, 4  # recipe mapping two variables to literals
]
recipe foo x:_elem, y:_elem [
  local-scope
  load-ingredients
  1:number/raw <- add x, y
]
+mem: storing 7 in location 1

:(scenario multiple_shape_shifting_variants)
# try to call two different shape-shifting recipes with the same name
recipe main [
  e1:d1:number <- merge 3
  e2:d2:number <- merge 4, 5
  1:number/raw <- foo e1
  2:number/raw <- foo e2
]
# the two shape-shifting definitions
recipe foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo a:d2:_elem -> b:number [
  local-scope
  load-ingredients
  reply 35
]
# the shape-shifting containers they use
container d1:_elem [
  x:_elem
]
container d2:_elem [
  x:number
  y:_elem
]
+mem: storing 34 in location 1
+mem: storing 35 in location 2

:(scenario multiple_shape_shifting_variants_2)
# static dispatch between shape-shifting variants, _including pointer lookups_
recipe main [
  e1:d1:number <- merge 3
  e2:address:d2:number <- new {(d2 number): type}
  1:number/raw <- foo e1
  2:number/raw <- foo *e2  # different from previous scenario
]
recipe foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo a:d2:_elem -> b:number [
  local-scope
  load-ingredients
  reply 35
]
container d1:_elem [
  x:_elem
]
container d2:_elem [
  x:number
  y:_elem
]
+mem: storing 34 in location 1
+mem: storing 35 in location 2

:(scenario missing_type_in_shape_shifting_recipe)
% Hide_errors = true;
recipe main [
  a:d1:number <- merge 3
  foo a
]
recipe foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  copy e  # no such variable
  reply 34
]
container d1:_elem [
  x:_elem
]
+error: foo: unknown type for e (check the name for typos)
+error: specializing foo: missing type for e
# and it doesn't crash

:(scenario missing_type_in_shape_shifting_recipe_2)
% Hide_errors = true;
recipe main [
  a:d1:number <- merge 3
  foo a
]
recipe foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  get e, x:offset  # unknown variable in a 'get', which does some extra checking
  reply 34
]
container d1:_elem [
  x:_elem
]
+error: foo: unknown type for e (check the name for typos)
+error: specializing foo: missing type for e
# and it doesn't crash
