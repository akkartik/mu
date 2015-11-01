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

:(code)
recipe_ordinal pick_matching_generic_variant(vector<recipe_ordinal>& variants, const instruction& inst, long long int& best_score) {
  recipe_ordinal result = 0;
  for (long long int i = 0; i < SIZE(variants); ++i) {
    trace(9992, "transform") << "checking variant " << i << end();
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
    trace(9993, "tranform") << "no type ingredients" << end();
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
    if (is_type_ingredient(Recipe[variant].ingredients.at(i)))
      return true;
  }
  return false;
}

bool non_type_ingredients_match(const reagent& lhs, const reagent& rhs) {
  if (is_type_ingredient(lhs)) return true;
  return types_match(lhs, rhs);
}

recipe_ordinal new_variant(recipe_ordinal exemplar, const instruction& inst) {
  string new_name = next_unused_recipe_name(inst.name);
  assert(Recipe_ordinal.find(new_name) == Recipe_ordinal.end());
  recipe_ordinal result = Recipe_ordinal[new_name] = Next_recipe_ordinal++;
  // make a copy
  Recipe[result] = Recipe[exemplar];
  recipe& new_recipe = Recipe[result];
  // update its name
  new_recipe.name = new_name;
  // update its header
  map<string, type_tree*> mappings;  // weak references
  for (long long int i = 0; i < SIZE(new_recipe.ingredients); ++i) {
    if (!is_type_ingredient(new_recipe.ingredients.at(i))) continue;
    type_tree* replacement_type = new type_tree(*inst.ingredients.at(i).type);
    delete new_recipe.ingredients.at(i).type;
    new_recipe.ingredients.at(i).type = replacement_type;
    mappings[new_recipe.ingredients.at(i).name] = replacement_type;
  }
  for (long long int i = 0; i < SIZE(new_recipe.products); ++i) {
    if (!is_type_ingredient(new_recipe.products.at(i))) continue;
    type_tree* replacement_type = new type_tree(*inst.products.at(i).type);
    delete new_recipe.products.at(i).type;
    new_recipe.products.at(i).type = replacement_type;
    mappings[new_recipe.products.at(i).name] = replacement_type;
  }
  // update its body
  for (long long int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    for (long long int j = 0; j < SIZE(inst.ingredients); ++j) {
      if (mappings.find(inst.ingredients.at(j).name) != mappings.end()) {
        delete inst.ingredients.at(j).type;
        inst.ingredients.at(j).type = new type_tree(*mappings[inst.ingredients.at(j).name]);
      }
    }
    for (long long int j = 0; j < SIZE(inst.products); ++j) {
      if (mappings.find(inst.products.at(j).name) != mappings.end()) {
        delete inst.products.at(j).type;
        inst.products.at(j).type = new type_tree(*mappings[inst.products.at(j).name]);
      }
    }
  }
  trace(9993, "transform") << "switching " << inst.name << " to " << new_name << end();
  return result;
}

bool is_type_ingredient(const reagent& x) {
  return x.properties.at(0).second->value.at(0) == '_';
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
