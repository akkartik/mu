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
:(before "End Matching Types For Literal(to)")
if (contains_type_ingredient_name(to)) return false;

//: We'll be creating recipes without loading them from anywhere by
//: *specializing* existing recipes.
//:
//: Keep track of these new recipes in a separate variable in addition to
//: Recently_added_recipes, so that edit/ can clear them before reloading to
//: regenerate errors.
:(before "End Globals")
vector<recipe_ordinal> Recently_added_shape_shifting_recipes;
:(before "End Setup")
//? cerr << "setup: clearing recently-added shape-shifting recipes\n";
Recently_added_shape_shifting_recipes.clear();

//: make sure we don't clear any of these recipes when we start running tests
:(before "End Loading .mu Files")
Recently_added_recipes.clear();
Recently_added_types.clear();
//? cerr << "clearing recently-added shape-shifting recipes\n";
Recently_added_shape_shifting_recipes.clear();

//: save original name of specialized recipes
:(before "End recipe Fields")
string original_name;
//: original name is only set during load
:(before "End Load Recipe Name")
result.original_name = result.name;

:(after "Static Dispatch Phase 2")
candidates = strictly_matching_shape_shifting_variants(inst, variants);
if (!candidates.empty()) {
  recipe_ordinal exemplar = best_shape_shifting_variant(inst, candidates);
  trace(9992, "transform") << "found variant to specialize: " << exemplar << ' ' << get(Recipe, exemplar).name << end();
  recipe_ordinal new_recipe_ordinal = new_variant(exemplar, inst, caller_recipe);
  if (new_recipe_ordinal == 0) goto skip_shape_shifting_variants;
  variants.push_back(new_recipe_ordinal);  // side-effect
  recipe& variant = get(Recipe, new_recipe_ordinal);
  // perform all transforms on the new specialization
  if (!variant.steps.empty()) {
    trace(9992, "transform") << "transforming new specialization: " << variant.name << end();
    for (long long int t = 0; t < SIZE(Transform); ++t) {
      (*Transform.at(t))(new_recipe_ordinal);
    }
  }
  variant.transformed_until = SIZE(Transform)-1;
  trace(9992, "transform") << "new specialization: " << variant.name << end();
  return variant.name;
}
skip_shape_shifting_variants:;

//: make sure we have no unspecialized shape-shifting recipes being called
//: before running mu programs

:(before "End Instruction Operation Checks")
if (contains_key(Recipe, inst.operation) && inst.operation >= MAX_PRIMITIVE_RECIPES
    && any_type_ingredient_in_header(inst.operation)) {
  raise_error << maybe(caller.name) << "instruction " << inst.name << " has no valid specialization\n" << end();
  return;
}

:(code)
// phase 2 of static dispatch
vector<recipe_ordinal> strictly_matching_shape_shifting_variants(const instruction& inst, vector<recipe_ordinal>& variants) {
  vector<recipe_ordinal> result;
  for (long long int i = 0; i < SIZE(variants); ++i) {
    if (variants.at(i) == -1) continue;
    if (!any_type_ingredient_in_header(variants.at(i))) continue;
    if (all_concrete_header_reagents_strictly_match(inst, get(Recipe, variants.at(i))))
      result.push_back(variants.at(i));
  }
  return result;
}

bool all_concrete_header_reagents_strictly_match(const instruction& inst, const recipe& variant) {
  if (SIZE(inst.ingredients) < SIZE(variant.ingredients)) {
    trace(9993, "transform") << "too few ingredients" << end();
    return false;
  }
  if (SIZE(variant.products) < SIZE(inst.products)) {
    trace(9993, "transform") << "too few products" << end();
    return false;
  }
  for (long long int i = 0; i < SIZE(variant.ingredients); ++i) {
    if (!concrete_types_strictly_match(variant.ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "concrete-type match failed: ingredient " << i << end();
      return false;
    }
  }
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!concrete_types_strictly_match(variant.products.at(i), inst.products.at(i))) {
      trace(9993, "transform") << "strict match failed: product " << i << end();
      return false;
    }
  }
  return true;
}

// tie-breaker for phase 2
recipe_ordinal best_shape_shifting_variant(const instruction& inst, vector<recipe_ordinal>& candidates) {
  assert(!candidates.empty());
  // primary score
  long long int max_score = -1;
  for (long long int i = 0; i < SIZE(candidates); ++i) {
    long long int score = number_of_concrete_types(candidates.at(i));
    assert(score > -1);
    if (score > max_score) max_score = score;
  }
  // break any ties at max_score by a secondary score
  long long int min_score2 = 999;
  long long int best_index = 0;
  for (long long int i = 0; i < SIZE(candidates); ++i) {
    long long int score1 = number_of_concrete_types(candidates.at(i));
    assert(score1 <= max_score);
    if (score1 != max_score) continue;
    const recipe& candidate = get(Recipe, candidates.at(i));
    long long int score2 = (SIZE(candidate.products)-SIZE(inst.products))
                           + (SIZE(inst.ingredients)-SIZE(candidate.ingredients));
    assert(score2 < 999);
    if (score2 < min_score2) {
      min_score2 = score2;
      best_index = i;
    }
  }
  return candidates.at(best_index);
}


string header(const recipe& caller) {
  if (!caller.has_header) return maybe(caller.name);
  ostringstream out;
  out << caller.name;
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i) {
    if (i > 0) out << ',';
    out << ' ' << debug_string(caller.ingredients.at(i));
  }
  if (!caller.products.empty()) {
    out << " ->";
    for (long long int i = 0; i < SIZE(caller.products); ++i) {
      if (i > 0) out << ',';
      out << ' ' << debug_string(caller.products.at(i));
    }
  }
  out << ": ";
  return out.str();
}

bool any_type_ingredient_in_header(recipe_ordinal variant) {
  const recipe& caller = get(Recipe, variant);
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i) {
    if (contains_type_ingredient_name(caller.ingredients.at(i)))
      return true;
  }
  for (long long int i = 0; i < SIZE(caller.products); ++i) {
    if (contains_type_ingredient_name(caller.products.at(i)))
      return true;
  }
  return false;
}

bool concrete_types_strictly_match(reagent to, reagent from) {
  canonize_type(to);
  canonize_type(from);
  return concrete_types_strictly_match(to.properties.at(0).second, from.properties.at(0).second, from);
}

long long int number_of_concrete_types(recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  long long int result = 0;
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i)
    result += number_of_concrete_types(caller.ingredients.at(i));
  for (long long int i = 0; i < SIZE(caller.products); ++i)
    result += number_of_concrete_types(caller.products.at(i));
  return result;
}

long long int number_of_concrete_types(const reagent& r) {
  return number_of_concrete_types(r.properties.at(0).second);
}

long long int number_of_concrete_types(const string_tree* type) {
  if (!type) return 0;
  long long int result = 0;
  if (!type->value.empty() && !is_type_ingredient_name(type->value))
    result++;
  result += number_of_concrete_types(type->left);
  result += number_of_concrete_types(type->right);
  return result;
}

bool concrete_types_strictly_match(const string_tree* to, const string_tree* from, const reagent& rhs_reagent) {
  if (!to) return !from;
  if (!from) return !to;
  if (is_type_ingredient_name(to->value)) return true;  // type ingredient matches anything
  if (to->value == "literal" && from->value == "literal")
    return true;
  if (to->value == "literal"
      && Literal_type_names.find(from->value) != Literal_type_names.end())
    return true;
  if (from->value == "literal"
      && Literal_type_names.find(to->value) != Literal_type_names.end())
    return true;
  if (from->value == "literal" && to->value == "address")
    return rhs_reagent.name == "0";
//?   cerr << to->value << " vs " << from->value << '\n';
  return to->value == from->value
      && concrete_types_strictly_match(to->left, from->left, rhs_reagent)
      && concrete_types_strictly_match(to->right, from->right, rhs_reagent);
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
  trace(9993, "transform") << "switching " << inst.name << " to specialized " << new_name << end();
  assert(!contains_key(Recipe_ordinal, new_name));
  recipe_ordinal new_recipe_ordinal = put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
  // make a copy
  assert(contains_key(Recipe, exemplar));
  assert(!contains_key(Recipe, new_recipe_ordinal));
  Recently_added_recipes.push_back(new_recipe_ordinal);
  Recently_added_shape_shifting_recipes.push_back(new_recipe_ordinal);
  put(Recipe, new_recipe_ordinal, get(Recipe, exemplar));
  recipe& new_recipe = get(Recipe, new_recipe_ordinal);
  new_recipe.name = new_name;
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
    if (error) return 0;  // todo: delete new_recipe_ordinal from Recipes and other global state
  }
  ensure_all_concrete_types(new_recipe, get(Recipe, exemplar));
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
    raise_error << maybe(variant.original_name) << "unknown type for " << x.original_string << " (check the name for typos)\n" << end();
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
      put(mappings, exemplar_type->value, new string_tree(*refinement_type));
    }
    else {
      if (!deeply_equal_types(get(mappings, exemplar_type->value), refinement_type)) {
        raise_error << maybe(caller_recipe.name) << "no call found for '" << call_instruction.to_string() << "'\n" << end();
//?         cerr << exemplar_type->value << ": " << debug_string(get(mappings, exemplar_type->value)) << " vs " << debug_string(refinement_type) << '\n';
        *error = true;
        return;
      }
//?       cerr << exemplar_type->value << ": " << debug_string(get(mappings, exemplar_type->value)) << " <= " << debug_string(refinement_type) << '\n';
      if (get(mappings, exemplar_type->value)->value == "literal") {
        delete get(mappings, exemplar_type->value);
        put(mappings, exemplar_type->value, new string_tree(*refinement_type));
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
    if (inst.name == "new" && inst.ingredients.at(0).properties.at(0).second->value != "literal-string") {
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
    raise_error << "specializing " << caller.original_name << ": missing type for " << x.original_string << '\n' << end();
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
    if (replacement->value == "literal")
      type->value = "number";
    else
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

:(scenario shape_shifting_recipe_empty)
recipe main [
  foo 1
]
# shape-shifting recipe with no body
recipe foo a:_t [
]
# shouldn't crash

:(scenario shape_shifting_recipe_handles_shape_shifting_new_ingredient)
recipe main [
  1:address:shared:foo:point <- bar 3
  11:foo:point <- copy *1:address:shared:foo:point
]
container foo:_t [
  x:_t
  y:number
]
recipe bar x:number -> result:address:shared:foo:_t [
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
  1:address:shared:foo:point <- bar 3
  11:foo:point <- copy *1:address:shared:foo:point
]
recipe bar x:number -> result:address:shared:foo:_t [
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
  1:address:shared:point <- new point:type
  2:address:number <- get-address *1:address:shared:point, y:offset
  *2:address:number <- copy 34
  3:address:shared:point <- bar 1:address:shared:point  # specialize _t to address:shared:point
  4:point <- copy *3:address:shared:point
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
  b:address:shared:number <- foo a
]
recipe foo a:_t -> b:_t [
  load-ingredients
  b <- copy a
]
+error: main: no call found for 'b:address:shared:number <- foo a'

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
  1:address:shared:character/raw <- foo 0
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
  e2:address:shared:d2:number <- new {(d2 number): type}
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

:(scenarios transform)
:(scenario specialize_recursive_shape_shifting_recipe)
recipe main [
  1:number <- copy 34
  2:number <- foo 1:number
]
recipe foo x:_elem -> y:number [
  local-scope
  load-ingredients
  {
    break
    y:number <- foo x
  }
  reply y
]
+transform: new specialization: foo_2
# transform terminates

:(scenarios run)
:(scenario specialize_most_similar_variant)
recipe main [
  1:address:shared:number <- new number:type
  2:number <- foo 1:address:shared:number
]
recipe foo x:_elem -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:address:shared:_elem -> y:number [
  local-scope
  load-ingredients
  reply 35
]
+mem: storing 35 in location 2

:(scenario specialize_most_similar_variant_2)
# version with headers padded with lots of unrelated concrete types
recipe main [
  1:number <- copy 23
  2:address:shared:array:number <- copy 0
  3:number <- foo 2:address:shared:array:number, 1:number
]
# variant with concrete type
recipe foo dummy:address:shared:array:number, x:number -> y:number, dummy:address:shared:array:number [
  local-scope
  load-ingredients
  reply 34
]
# shape-shifting variant
recipe foo dummy:address:shared:array:number, x:_elem -> y:number, dummy:address:shared:array:number [
  local-scope
  load-ingredients
  reply 35
]
# prefer the concrete variant
+mem: storing 34 in location 3

:(scenario specialize_most_similar_variant_3)
recipe main [
  1:address:shared:array:character <- new [abc]
  foo 1:address:shared:array:character
]
recipe foo x:address:shared:array:character [
  2:number <- copy 34
]
recipe foo x:address:_elem [
  2:number <- copy 35
]
# make sure the more precise version was used
+mem: storing 34 in location 2

:(scenario specialize_literal_as_number)
recipe main [
  1:number <- foo 23
]
recipe foo x:_elem -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:character -> y:number [
  local-scope
  load-ingredients
  reply 35
]
+mem: storing 34 in location 1

:(scenario specialize_literal_as_number_2)
# version calling with literal
recipe main [
  1:number <- foo 0
]
# variant with concrete type
recipe foo x:number -> y:number [
  local-scope
  load-ingredients
  reply 34
]
# shape-shifting variant
recipe foo x:address:shared:_elem -> y:number [
  local-scope
  load-ingredients
  reply 35
]
# prefer the concrete variant, ignore concrete types in scoring the shape-shifting variant
+mem: storing 34 in location 1
