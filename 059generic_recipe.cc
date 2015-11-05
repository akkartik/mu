//:: Like container definitions, recipes too can contain type parameters.

:(scenario generic_recipe)
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
# matching generic variant
recipe foo a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 14 in location 11
+mem: storing 15 in location 12

//: Suppress unknown type checks in generic recipes. Their specializations
//: will be checked.

:(after "void check_invalid_types(const recipe_ordinal r)")
  if (any_type_ingredient_in_header(r)) return;

:(before "End Instruction Dispatch(inst, best_score)")
if (best_score == -1) {
  trace(9992, "transform") << "no variant found; searching for variant with suitable type ingredients" << end();
  recipe_ordinal exemplar = pick_matching_generic_variant(variants, inst, best_score);
  if (exemplar) {
    trace(9992, "transform") << "found variant to specialize: " << exemplar << ' ' << Recipe[exemplar].name << end();
    variants.push_back(new_variant(exemplar, inst));
    inst.name = Recipe[variants.back()].name;
    trace(9992, "transform") << "new specialization: " << inst.name << end();
  }
}

//: Don't bother resolving ambiguous calls inside generic recipes. Just do
//: their specializations.

:(after "void resolve_ambiguous_calls")
if (any_type_ingredient_in_header(r)) return;

:(code)
recipe_ordinal pick_matching_generic_variant(vector<recipe_ordinal>& variants, const instruction& inst, long long int& best_score) {
  recipe_ordinal result = 0;
  for (long long int i = 0; i < SIZE(variants); ++i) {
    trace(9992, "transform") << "checking generic variant " << i << end();
    long long int current_score = generic_variant_score(inst, variants.at(i));
    trace(9992, "transform") << "final score: " << current_score << end();
    if (current_score > best_score) {
      trace(9992, "transform") << "matches" << end();
      result = variants.at(i);
      best_score = current_score;
    }
  }
  return result;
}

long long int generic_variant_score(const instruction& inst, recipe_ordinal variant) {
  if (!any_type_ingredient_in_header(variant)) {
    trace(9993, "transform") << "no type ingredients" << end();
    return -1;
  }
  const vector<reagent>& header_ingredients = Recipe[variant].ingredients;
  if (SIZE(inst.ingredients) < SIZE(header_ingredients)) {
    trace(9993, "transform") << "too few ingredients" << end();
    return -1;
  }
  for (long long int i = 0; i < SIZE(header_ingredients); ++i) {
    if (!non_type_ingredients_match(header_ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "mismatch: ingredient " << i << end();
      return -1;
    }
  }
  if (SIZE(inst.products) > SIZE(Recipe[variant].products)) {
    trace(9993, "transform") << "too few products" << end();
    return -1;
  }
  const vector<reagent>& header_products = Recipe[variant].products;
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (!non_type_ingredients_match(header_products.at(i), inst.products.at(i))) {
      trace(9993, "transform") << "mismatch: product " << i << end();
      return -1;
    }
  }
  // the greater the number of unused ingredients, the lower the score
  return 100 - (SIZE(Recipe[variant].products)-SIZE(inst.products))
             - (SIZE(inst.ingredients)-SIZE(Recipe[variant].ingredients));  // ok to go negative
}

bool any_type_ingredient_in_header(recipe_ordinal variant) {
  for (long long int i = 0; i < SIZE(Recipe[variant].ingredients); ++i) {
    if (contains_type_ingredient_name(Recipe[variant].ingredients.at(i)))
      return true;
  }
  return false;
}

bool non_type_ingredients_match(const reagent& lhs, const reagent& rhs) {
  if (contains_type_ingredient_name(lhs)) return true;
  return types_match(lhs, rhs);
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

recipe_ordinal new_variant(recipe_ordinal exemplar, const instruction& inst) {
  string new_name = next_unused_recipe_name(inst.name);
  trace(9993, "transform") << "switching " << inst.name << " to " << new_name << end();
  assert(Recipe_ordinal.find(new_name) == Recipe_ordinal.end());
  recipe_ordinal result = Recipe_ordinal[new_name] = Next_recipe_ordinal++;
  // make a copy
  assert(Recipe.find(exemplar) != Recipe.end());
  assert(Recipe.find(result) == Recipe.end());
  recently_added_recipes.push_back(result);
  Recipe[result] = Recipe[exemplar];
  recipe& new_recipe = Recipe[result];
  // update its name
  new_recipe.name = new_name;
  // update its contents
  map<string, string> mappings;  // weak references
  compute_type_ingredient_mappings(Recipe[exemplar], inst, mappings);
  replace_type_ingredients(new_recipe, mappings);
  return result;
}

void compute_type_ingredient_mappings(const recipe& exemplar, const instruction& inst, map<string, string>& mappings) {
  if (SIZE(inst.ingredients) < SIZE(exemplar.ingredients)
      || SIZE(inst.products) < SIZE(exemplar.products)) {
    raise_error << "can't specialize " << exemplar.name << " without all ingredients and products, but got '" << inst.to_string() << "'\n" << end();
  }
  for (long long int i = 0; i < SIZE(exemplar.ingredients); ++i) {
    accumulate_type_ingredients(exemplar.ingredients.at(i), inst.ingredients.at(i), mappings, exemplar);
  }
  for (long long int i = 0; i < SIZE(exemplar.products); ++i) {
    accumulate_type_ingredients(exemplar.products.at(i), inst.products.at(i), mappings, exemplar);
  }
}

void accumulate_type_ingredients(const reagent& base, const reagent& refinement, map<string, string>& mappings, const recipe& exemplar) {
  if (!refinement.properties.at(0).second) {
    if (!Trace_stream) cerr << "Turn on START_TRACING_UNTIL_END_OF_SCOPE in 020run.cc for more details.\n";
    DUMP("");
  }
  assert(refinement.properties.at(0).second);
  accumulate_type_ingredients(base.properties.at(0).second, refinement.properties.at(0).second, mappings, exemplar, base);
}

void accumulate_type_ingredients(const string_tree* base, const string_tree* refinement, map<string, string>& mappings, const recipe& exemplar, const reagent& r) {
  if (!base) return;
  if (!refinement) {
    if (!Trace_stream) cerr << "Turn on START_TRACING_UNTIL_END_OF_SCOPE in 020run.cc for more details.\n";
    DUMP("");
  }
  assert(refinement);
  if (!base->value.empty() && base->value.at(0) == '_') {
    assert(!refinement->value.empty());
    if (mappings.find(base->value) == mappings.end()) {
      trace(9993, "transform") << "adding mapping from " << base->value << " to " << refinement->value << end();
      mappings[base->value] = refinement->value;
    }
    else {
      assert(mappings[base->value] == refinement->value);
    }
  }
  else {
    accumulate_type_ingredients(base->left, refinement->left, mappings, exemplar, r);
  }
  accumulate_type_ingredients(base->right, refinement->right, mappings, exemplar, r);
}

void replace_type_ingredients(recipe& new_recipe, const map<string, string>& mappings) {
  // update its header
  if (mappings.empty()) return;
  trace(9993, "transform") << "replacing in recipe header ingredients" << end();
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i) {
    replace_type_ingredients(new_recipe.ingredients.at(i), mappings);
  }
  trace(9993, "transform") << "replacing in recipe header products" << end();
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i) {
    replace_type_ingredients(new_recipe.products.at(i), mappings);
  }
  // update its body
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    trace(9993, "transform") << "replacing in instruction '" << inst.to_string() << "'" << end();
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j) {
      replace_type_ingredients(inst.ingredients.at(j), mappings);
    }
    for (long long int j = 0; j < SIZE(inst.products); ++j) {
      replace_type_ingredients(inst.products.at(j), mappings);
    }
  }
}

void replace_type_ingredients(reagent& x, const map<string, string>& mappings) {
  if (!x.type) return;
  trace(9993, "transform") << "replacing in ingredient " << x.original_string << end();
  // replace properties
  replace_type_ingredients(x.properties.at(0).second, mappings);
  // refresh types from properties
  delete x.type;
  x.type = new_type_tree(x.properties.at(0).second);
  if (x.type)
    trace(9993, "transform") << "  after: " << dump_types(x) << end();
}

void replace_type_ingredients(string_tree* type, const map<string, string>& mappings) {
  if (!type) return;
  if (is_type_ingredient_name(type->value) && mappings.find(type->value) != mappings.end()) {
    trace(9993, "transform") << type->value << " => " << mappings.find(type->value)->second << end();
    type->value = mappings.find(type->value)->second;
  }
  replace_type_ingredients(type->left, mappings);
  replace_type_ingredients(type->right, mappings);
}

:(scenario generic_recipe_2)
recipe main [
  10:point <- merge 14, 15
  11:point <- foo 10:point
]
# non-matching generic variant
recipe foo a:_t, b:_t -> result:number [
  local-scope
  load-ingredients
  result <- copy 34
]
# matching generic variant
recipe foo a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 14 in location 11
+mem: storing 15 in location 12

:(scenario generic_recipe_nonroot)
% Hide_warnings = Hide_errors = true;
recipe main [
  10:foo:point <- merge 14, 15, 16
  20:point/raw <- bar 10:foo:point
]
# generic recipe with type ingredient following some other type
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
