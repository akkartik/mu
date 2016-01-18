//: Transform to maintain multiple variants of a recipe depending on the
//: number and types of the ingredients and products. Allows us to use nice
//: names like 'print' or 'length' in many mutually extensible ways.

:(scenario static_dispatch)
recipe main [
  7:number/raw <- test 3
]
recipe test a:number -> z:number [
  z <- copy 1
]
recipe test a:number, b:number -> z:number [
  z <- copy 2
]
+mem: storing 1 in location 7

//: When loading recipes, accumulate variants if headers don't collide, and
//: raise a warning if headers collide.

:(before "End Globals")
map<string, vector<recipe_ordinal> > Recipe_variants;
:(before "End One-time Setup")
put(Recipe_variants, "main", vector<recipe_ordinal>());  // since we manually added main to Recipe_ordinal
:(before "Clear Other State For Recently_added_recipes")
for (map<string, vector<recipe_ordinal> >::iterator p = Recipe_variants.begin(); p != Recipe_variants.end(); ++p) {
  for (long long int i = 0; i < SIZE(p->second); ++i) {
    if (find(Recently_added_recipes.begin(), Recently_added_recipes.end(), p->second.at(i)) != Recently_added_recipes.end())
      p->second.at(i) = -1;  // just leave a ghost
  }
}

:(before "End Load Recipe Header(result)")
if (contains_key(Recipe_ordinal, result.name)) {
  const recipe_ordinal r = get(Recipe_ordinal, result.name);
//?   cerr << result.name << ": " << contains_key(Recipe, r) << (contains_key(Recipe, r) ? get(Recipe, r).has_header : 0) << matching_variant_name(result) << '\n';
  if (!contains_key(Recipe, r) || get(Recipe, r).has_header) {
    string new_name = matching_variant_name(result);
    if (new_name.empty()) {
      // variant doesn't already exist
      new_name = next_unused_recipe_name(result.name);
      put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
      get_or_insert(Recipe_variants, result.name).push_back(get(Recipe_ordinal, new_name));
    }
    result.name = new_name;
//?     cerr << "=> " << new_name << '\n';
  }
}
else {
  // save first variant
  put(Recipe_ordinal, result.name, Next_recipe_ordinal++);
  get_or_insert(Recipe_variants, result.name).push_back(get(Recipe_ordinal, result.name));
}

:(code)
string matching_variant_name(const recipe& rr) {
  const vector<recipe_ordinal>& variants = get_or_insert(Recipe_variants, rr.name);
  for (long long int i = 0; i < SIZE(variants); ++i) {
    if (!contains_key(Recipe, variants.at(i))) continue;
    const recipe& candidate = get(Recipe, variants.at(i));
    if (!all_reagents_match(rr, candidate)) continue;
    return candidate.name;
  }
  return "";
}

bool all_reagents_match(const recipe& r1, const recipe& r2) {
  if (SIZE(r1.ingredients) != SIZE(r2.ingredients)) return false;
  if (SIZE(r1.products) != SIZE(r2.products)) return false;
  for (long long int i = 0; i < SIZE(r1.ingredients); ++i) {
    if (!deeply_equal_types(r1.ingredients.at(i).properties.at(0).second,
                            r2.ingredients.at(i).properties.at(0).second)) {
      return false;
    }
  }
  for (long long int i = 0; i < SIZE(r1.products); ++i) {
    if (!deeply_equal_types(r1.products.at(i).properties.at(0).second,
                            r2.products.at(i).properties.at(0).second)) {
      return false;
    }
  }
  return true;
}

:(before "End Globals")
set<string> Literal_type_names;
:(before "End One-time Setup")
Literal_type_names.insert("number");
Literal_type_names.insert("character");
:(code)
bool deeply_equal_types(const string_tree* a, const string_tree* b) {
  if (!a) return !b;
  if (!b) return !a;
  if (a->value == "literal" && b->value == "literal")
    return true;
  if (a->value == "literal")
    return Literal_type_names.find(b->value) != Literal_type_names.end();
  if (b->value == "literal")
    return Literal_type_names.find(a->value) != Literal_type_names.end();
  return a->value == b->value
      && deeply_equal_types(a->left, b->left)
      && deeply_equal_types(a->right, b->right);
}

string next_unused_recipe_name(const string& recipe_name) {
  for (long long int i = 2; ; ++i) {
    ostringstream out;
    out << recipe_name << '_' << i;
    if (!contains_key(Recipe_ordinal, out.str()))
      return out.str();
  }
}

//: Once all the recipes are loaded, transform their bodies to replace each
//: call with the most suitable variant.

:(scenario static_dispatch_picks_most_similar_variant)
recipe main [
  7:number/raw <- test 3, 4, 5
]
recipe test a:number -> z:number [
  z <- copy 1
]
recipe test a:number, b:number -> z:number [
  z <- copy 2
]
+mem: storing 2 in location 7

//: support recipe headers in a previous transform to fill in missing types
:(before "End check_or_set_invalid_types")
for (long long int i = 0; i < SIZE(caller.ingredients); ++i) {
  check_or_set_invalid_types(caller.ingredients.at(i).type, caller.ingredients.at(i).properties.at(0).second,
                             maybe(caller.name), "recipe header ingredient");
}
for (long long int i = 0; i < SIZE(caller.products); ++i) {
  check_or_set_invalid_types(caller.products.at(i).type, caller.products.at(i).properties.at(0).second,
                             maybe(caller.name), "recipe header product");
}

//: after filling in all missing types (because we'll be introducing 'blank' types in this transform in a later layer, for shape-shifting recipes)
:(after "Transform.push_back(transform_names)")
Transform.push_back(resolve_ambiguous_calls);  // idempotent

:(code)
void resolve_ambiguous_calls(recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  trace(9991, "transform") << "--- resolve ambiguous calls for recipe " << caller_recipe.name << end();
//?   cerr << "--- resolve ambiguous calls for recipe " << caller_recipe.name << '\n';
  for (long long int index = 0; index < SIZE(caller_recipe.steps); ++index) {
    instruction& inst = caller_recipe.steps.at(index);
    if (inst.is_label) continue;
    if (get_or_insert(Recipe_variants, inst.name).empty()) continue;
    replace_best_variant(inst, caller_recipe);
  }
}

void replace_best_variant(instruction& inst, const recipe& caller_recipe) {
  trace(9992, "transform") << "instruction " << inst.name << end();
  vector<recipe_ordinal>& variants = get(Recipe_variants, inst.name);
//?   trace(9992, "transform") << "checking base: " << get(Recipe_ordinal, inst.name) << end();
  long long int best_score = variant_score(inst, get(Recipe_ordinal, inst.name));
  trace(9992, "transform") << "score for base: " << best_score << end();
  for (long long int i = 0; i < SIZE(variants); ++i) {
//?     trace(9992, "transform") << "checking variant " << i << ": " << variants.at(i) << end();
    long long int current_score = variant_score(inst, variants.at(i));
    trace(9992, "transform") << "score for variant " << i << ": " << current_score << end();
    if (current_score > best_score) {
      inst.name = get(Recipe, variants.at(i)).name;
      best_score = current_score;
    }
  }
  // End Instruction Dispatch(inst, best_score)
  if (best_score == -1 && get(Recipe_ordinal, inst.name) >= MAX_PRIMITIVE_RECIPES) {
    raise_error << maybe(caller_recipe.name) << "failed to find a matching call for '" << inst.to_string() << "'\n" << end();
  }
}

long long int variant_score(const instruction& inst, recipe_ordinal variant) {
  long long int result = 1000;
  if (variant == -1) return -1;  // ghost from a previous test
//?   cerr << "variant score: " << inst.to_string() << '\n';
  if (!contains_key(Recipe, variant)) {
    assert(variant < MAX_PRIMITIVE_RECIPES);
    return -1;
  }
  const vector<reagent>& header_ingredients = get(Recipe, variant).ingredients;
//?   cerr << "=== checking ingredients\n";
  for (long long int i = 0; i < min(SIZE(inst.ingredients), SIZE(header_ingredients)); ++i) {
    if (!types_match(header_ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "mismatch: ingredient " << i << end();
//?       cerr << "mismatch: ingredient " << i << '\n';
      return -1;
    }
    if (types_strictly_match(header_ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "strict match: ingredient " << i << end();
//?       cerr << "strict match: ingredient " << i << '\n';
    }
    else if (boolean_matches_literal(header_ingredients.at(i), inst.ingredients.at(i))) {
      // slight penalty for coercing literal to boolean (prefer direct conversion to number if possible)
      trace(9993, "transform") << "boolean matches literal: ingredient " << i << end();
      result--;
    }
    else {
      // slightly larger penalty for modifying type in other ways
      trace(9993, "transform") << "non-strict match: ingredient " << i << end();
//?       cerr << "non-strict match: ingredient " << i << '\n';
      result-=10;
    }
  }
//?   cerr << "=== done checking ingredients\n";
  const vector<reagent>& header_products = get(Recipe, variant).products;
  for (long long int i = 0; i < min(SIZE(header_products), SIZE(inst.products)); ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!types_match(header_products.at(i), inst.products.at(i))) {
      trace(9993, "transform") << "mismatch: product " << i << end();
//?       cerr << "mismatch: product " << i << '\n';
      return -1;
    }
    if (types_strictly_match(header_products.at(i), inst.products.at(i))) {
      trace(9993, "transform") << "strict match: product " << i << end();
//?       cerr << "strict match: product " << i << '\n';
    }
    else if (boolean_matches_literal(header_products.at(i), inst.products.at(i))) {
      // slight penalty for coercing literal to boolean (prefer direct conversion to number if possible)
      trace(9993, "transform") << "boolean matches literal: product " << i << end();
      result--;
    }
    else {
      // slightly larger penalty for modifying type in other ways
      trace(9993, "transform") << "non-strict match: product " << i << end();
//?       cerr << "non-strict match: product " << i << '\n';
      result-=10;
    }
  }
  // the greater the number of unused ingredients/products, the lower the score
  return result - abs(SIZE(get(Recipe, variant).products)-SIZE(inst.products))
                - abs(SIZE(inst.ingredients)-SIZE(get(Recipe, variant).ingredients));
}

:(scenario static_dispatch_disabled_on_headerless_definition)
% Hide_warnings = true;
recipe test a:number -> z:number [
  z <- copy 1
]
recipe test [
  reply 34
]
+warn: redefining recipe test

:(scenario static_dispatch_disabled_on_headerless_definition_2)
% Hide_warnings = true;
recipe test [
  reply 34
]
recipe test a:number -> z:number [
  z <- copy 1
]
+warn: redefining recipe test

:(scenario static_dispatch_on_primitive_names)
recipe main [
  1:number <- copy 34
  2:number <- copy 34
  3:boolean <- equal 1:number, 2:number
  4:boolean <- copy 0/false
  5:boolean <- copy 0/false
  6:boolean <- equal 4:boolean, 5:boolean
]

# temporarily hardcode number equality to always fail
recipe equal x:number, y:number -> z:boolean [
  local-scope
  load-ingredients
  z <- copy 0/false
]
# comparing numbers used overload
+mem: storing 0 in location 3
# comparing booleans continues to use primitive
+mem: storing 1 in location 6

:(scenario static_dispatch_works_with_dummy_results_for_containers)
% Hide_errors = true;
recipe main [
  _ <- test 3, 4
]
recipe test a:number -> z:point [
  local-scope
  load-ingredients
  z <- merge a, 0
]
recipe test a:number, b:number -> z:point [
  local-scope
  load-ingredients
  z <- merge a, b
]
$error: 0

:(scenario static_dispatch_works_with_compound_type_containing_container_defined_after_first_use)
% Hide_errors = true;
recipe main [
  x:address:foo <- new foo:type
  test x
]
container foo [
  x:number
]
recipe test a:address:foo -> z:number [
  local-scope
  load-ingredients
  z:number <- get *a, x:offset
]
$error: 0

:(scenario static_dispatch_works_with_compound_type_containing_container_defined_after_second_use)
% Hide_errors = true;
recipe main [
  x:address:foo <- new foo:type
  test x
]
recipe test a:address:foo -> z:number [
  local-scope
  load-ingredients
  z:number <- get *a, x:offset
]
container foo [
  x:number
]
$error: 0

:(scenario static_dispatch_prefers_literals_to_be_numbers_rather_than_addresses)
recipe main [
  1:number <- foo 0
]
recipe foo x:address:number -> y:number [
  reply 34
]
recipe foo x:number -> y:number [
  reply 35
]
+mem: storing 35 in location 1

:(scenario static_dispatch_on_non_literal_character_ignores_variant_with_numbers)
% Hide_errors = true;
recipe main [
  local-scope
  x:character <- copy 10/newline
  1:number/raw <- foo x
]
recipe foo x:number -> y:number [
  load-ingredients
  reply 34
]
+error: main: ingredient 0 has the wrong type at '1:number/raw <- foo x'
-mem: storing 34 in location 1

:(scenario static_dispatch_dispatches_literal_to_boolean_before_character)
recipe main [
  1:number/raw <- foo 0  # valid literal for boolean
]
recipe foo x:character -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:boolean -> y:number [
  local-scope
  load-ingredients
  reply 35
]
# boolean variant is preferred
+mem: storing 35 in location 1

:(scenario static_dispatch_dispatches_literal_to_character_when_out_of_boolean_range)
recipe main [
  1:number/raw <- foo 97  # not a valid literal for boolean
]
recipe foo x:character -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:boolean -> y:number [
  local-scope
  load-ingredients
  reply 35
]
# character variant is preferred
+mem: storing 34 in location 1

:(scenario static_dispatch_dispatches_literal_to_number_if_at_all_possible)
recipe main [
  1:number/raw <- foo 97
]
recipe foo x:character -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:number -> y:number [
  local-scope
  load-ingredients
  reply 35
]
# number variant is preferred
+mem: storing 35 in location 1

:(code)
string header_label(recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  ostringstream out;
  out << "recipe " << caller.name;
  for (long long int i = 0; i < SIZE(caller.ingredients); ++i)
    out << ' ' << caller.ingredients.at(i).original_string;
  if (!caller.products.empty()) out << " ->";
  for (long long int i = 0; i < SIZE(caller.products); ++i)
    out << ' ' << caller.products.at(i).original_string;
  return out.str();
}

:(scenario reload_variant_retains_other_variants)
recipe main [
  1:number <- copy 34
  2:number <- foo 1:number
]
recipe foo x:number -> y:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo x:address:number -> y:number [
  local-scope
  load-ingredients
  reply 35
]
recipe! foo x:address:number -> y:number [
  local-scope
  load-ingredients
  reply 36
]
+mem: storing 34 in location 2
$error: 0
$warn: 0

:(scenario dispatch_errors_come_after_unknown_name_errors)
% Hide_errors = true;
recipe main [
  y:number <- foo x
]
recipe foo a:number -> b:number [
  local-scope
  load-ingredients
  reply 34
]
recipe foo a:boolean -> b:number [
  local-scope
  load-ingredients
  reply 35
]
+error: main: missing type for x in 'y:number <- foo x'
+error: main: failed to find a matching call for 'y:number <- foo x'

:(before "End Includes")
using std::min;
using std::max;
using std::abs;
