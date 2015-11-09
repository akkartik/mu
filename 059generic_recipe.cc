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

//: Before anything else, disable transforms for generic recipes.

:(before "End Transform Checks")
if (any_type_ingredient_in_header(/*recipe_ordinal*/p->first)) continue;

//: We'll be creating recipes without loading them from anywhere by
//: *specializing* existing recipes, so make sure we don't clear any of those
//: when we start running tests.
:(before "End Loading .mu Files")
recently_added_recipes.clear();
recently_added_types.clear();

:(before "End Instruction Dispatch(inst, best_score)")
if (best_score == -1) {
  trace(9992, "transform") << "no variant found; searching for variant with suitable type ingredients" << end();
  recipe_ordinal exemplar = pick_matching_generic_variant(variants, inst, best_score);
  if (exemplar) {
    trace(9992, "transform") << "found variant to specialize: " << exemplar << ' ' << get(Recipe, exemplar).name << end();
    variants.push_back(new_variant(exemplar, inst));
    inst.name = get(Recipe, variants.back()).name;
    trace(9992, "transform") << "new specialization: " << inst.name << end();
  }
}

:(code)
recipe_ordinal pick_matching_generic_variant(vector<recipe_ordinal>& variants, const instruction& inst, long long int& best_score) {
  recipe_ordinal result = 0;
  for (long long int i = 0; i < SIZE(variants); ++i) {
    if (variants.at(i) == -1) continue;  // ghost from a previous test
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
  const vector<reagent>& header_ingredients = get(Recipe, variant).ingredients;
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
  if (SIZE(inst.products) > SIZE(get(Recipe, variant).products)) {
    trace(9993, "transform") << "too few products" << end();
    return -1;
  }
  const vector<reagent>& header_products = get(Recipe, variant).products;
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (!non_type_ingredients_match(header_products.at(i), inst.products.at(i))) {
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
  assert(!contains_key(Recipe_ordinal, new_name));
  recipe_ordinal new_recipe_ordinal = put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
  // make a copy
  assert(contains_key(Recipe, exemplar));
  assert(!contains_key(Recipe, new_recipe_ordinal));
  recently_added_recipes.push_back(new_recipe_ordinal);
  put(Recipe, new_recipe_ordinal, get(Recipe, exemplar));
  recipe& new_recipe = get(Recipe, new_recipe_ordinal);
  new_recipe.name = new_name;
  // Since the exemplar never ran any transforms, we have to redo some of the
  // work of the check_types_by_name transform while supporting type-ingredients.
  compute_type_names(new_recipe);
  // that gives enough information to replace type-ingredients with concrete types
  map<string, const string_tree*> mappings;
  compute_type_ingredient_mappings(get(Recipe, exemplar), inst, mappings);
  replace_type_ingredients(new_recipe, mappings);
  ensure_all_concrete_types(new_recipe);
  // finally, perform all transforms on the new specialization
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
    save_or_deduce_type_name(variant.ingredients.at(i), type_names);
  for (long long int i = 0; i < SIZE(variant.products); ++i)
    save_or_deduce_type_name(variant.products.at(i), type_names);
  for (long long int i = 0; i < SIZE(variant.steps); ++i) {
    instruction& inst = variant.steps.at(i);
    trace(9993, "transform") << "  instruction: " << inst.to_string() << end();
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in)
      save_or_deduce_type_name(inst.ingredients.at(in), type_names);
    for (long long int out = 0; out < SIZE(inst.products); ++out)
      save_or_deduce_type_name(inst.products.at(out), type_names);
  }
}

void save_or_deduce_type_name(reagent& x, map<string, string_tree*>& type_name) {
  trace(9994, "transform") << "    checking " << x.to_string() << ": " << debug_string(x.properties.at(0).second) << end();
  if (!x.properties.at(0).second && contains_key(type_name, x.name)) {
    x.properties.at(0).second = new string_tree(*get(type_name, x.name));
    trace(9994, "transform") << "    deducing type to " << debug_string(x.properties.at(0).second) << end();
    return;
  }
  if (!x.properties.at(0).second) {
    raise << "unknown type for " << x.original_string << '\n' << end();
    return;
  }
  if (contains_key(type_name, x.name)) return;
  if (x.properties.at(0).second->value == "offset" || x.properties.at(0).second->value == "variant") return;  // special-case for container-access instructions
  put(type_name, x.name, x.properties.at(0).second);
  trace(9993, "transform") << "type of " << x.name << " is " << debug_string(x.properties.at(0).second) << end();
}

void compute_type_ingredient_mappings(const recipe& exemplar, const instruction& inst, map<string, const string_tree*>& mappings) {
  for (long long int i = 0; i < SIZE(exemplar.ingredients); ++i) {
    const reagent& base = exemplar.ingredients.at(i);
    reagent ingredient = inst.ingredients.at(i);
    assert(ingredient.properties.at(0).second);
    canonize_type(ingredient);
    accumulate_type_ingredients(base, ingredient, mappings, exemplar);
  }
  for (long long int i = 0; i < SIZE(exemplar.products); ++i) {
    const reagent& base = exemplar.products.at(i);
    reagent product = inst.products.at(i);
    assert(product.properties.at(0).second);
    canonize_type(product);
    accumulate_type_ingredients(base, product, mappings, exemplar);
  }
}

void accumulate_type_ingredients(const reagent& base, reagent& refinement, map<string, const string_tree*>& mappings, const recipe& exemplar) {
  assert(refinement.properties.at(0).second);
  accumulate_type_ingredients(base.properties.at(0).second, refinement.properties.at(0).second, mappings, exemplar, base);
}

void accumulate_type_ingredients(const string_tree* base, const string_tree* refinement, map<string, const string_tree*>& mappings, const recipe& exemplar, const reagent& r) {
  if (!base) return;
  if (!refinement) {
    raise_error << maybe(exemplar.name) << "missing type ingredient in " << r.original_string << '\n' << end();
    return;
  }
  if (!base->value.empty() && base->value.at(0) == '_') {
    assert(!refinement->value.empty());
    if (base->right) {
      raise_error << "type_ingredients in non-last position not currently supported\n" << end();
      return;
    }
    if (!contains_key(mappings, base->value)) {
      trace(9993, "transform") << "adding mapping from " << base->value << " to " << debug_string(refinement) << end();
      put(mappings, base->value, new string_tree(*refinement));
    }
    else {
      assert(deeply_equal(get(mappings, base->value), refinement));
    }
  }
  else {
    accumulate_type_ingredients(base->left, refinement->left, mappings, exemplar, r);
  }
  accumulate_type_ingredients(base->right, refinement->right, mappings, exemplar, r);
}

void replace_type_ingredients(recipe& new_recipe, const map<string, const string_tree*>& mappings) {
  // update its header
  if (mappings.empty()) return;
  trace(9993, "transform") << "replacing in recipe header ingredients" << end();
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    replace_type_ingredients(new_recipe.ingredients.at(i), mappings);
  trace(9993, "transform") << "replacing in recipe header products" << end();
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i)
    replace_type_ingredients(new_recipe.products.at(i), mappings);
  // update its body
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    trace(9993, "transform") << "replacing in instruction '" << inst.to_string() << "'" << end();
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j)
      replace_type_ingredients(inst.ingredients.at(j), mappings);
    for (long long int j = 0; j < SIZE(inst.products); ++j)
      replace_type_ingredients(inst.products.at(j), mappings);
    // special-case for new: replace type ingredient in first ingredient *value*
    if (inst.name == "new" && inst.ingredients.at(0).name.at(0) != '[') {
      string_tree* type_name = parse_string_tree(inst.ingredients.at(0).name);
      replace_type_ingredients(type_name, mappings);
      inst.ingredients.at(0).name = type_name->to_string();
      delete type_name;
    }
  }
}

void replace_type_ingredients(reagent& x, const map<string, const string_tree*>& mappings) {
  trace(9993, "transform") << "replacing in ingredient " << x.original_string << end();
  // replace properties
  assert(x.properties.at(0).second);
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

void ensure_all_concrete_types(const recipe& new_recipe) {
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    ensure_all_concrete_types(new_recipe.ingredients.at(i).type);
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i)
    ensure_all_concrete_types(new_recipe.products.at(i).type);
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    const instruction& inst = new_recipe.steps.at(i);
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j)
      ensure_all_concrete_types(inst.ingredients.at(j).type);
    for (long long int j = 0; j < SIZE(inst.products); ++j)
      ensure_all_concrete_types(inst.products.at(j).type);
  }
}

void ensure_all_concrete_types(const type_tree* x) {
  if (!x) {
    raise << "null type\n" << end();
    return;
  }
  if (x->value == -1) {
    raise << "unknown type\n" << end();
    return;
  }
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
