//:: Like container definitions, recipes too can contain type parameters.

void test_shape_shifting_recipe() {
  run(
      "def main [\n"
      "  10:point <- merge 14, 15\n"
      "  12:point <- foo 10:point\n"
      "]\n"
      // non-matching variant
      "def foo a:num -> result:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy 34\n"
      "]\n"
      // matching shape-shifting variant
      "def foo a:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy a\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 14 in location 12\n"
      "mem: storing 15 in location 13\n"
  );
}

//: Before anything else, disable transforms for shape-shifting recipes and
//: make sure we never try to actually run a shape-shifting recipe. We should
//: be rewriting such instructions to *specializations* with the type
//: ingredients filled in.

//: One exception (and this makes things very ugly): we need to expand type
//: abbreviations in shape-shifting recipes because we need them types for
//: deciding which variant to specialize.

:(before "End Transform Checks")
r.transformed_until = t;
if (Transform.at(t) != static_cast<transform_fn>(expand_type_abbreviations) && any_type_ingredient_in_header(/*recipe_ordinal*/p->first)) continue;

:(after "Running One Instruction")
if (Current_routine->calls.front().running_step_index == 0
    && any_type_ingredient_in_header(Current_routine->calls.front().running_recipe)) {
//?   DUMP("");
  raise << "ran into unspecialized shape-shifting recipe " << current_recipe_name() << '\n' << end();
//?   exit(0);
}

//: Make sure we don't match up literals with type ingredients without
//: specialization.
:(before "End Matching Types For Literal(to)")
if (contains_type_ingredient_name(to)) return false;

:(after "Static Dispatch Phase 2")
candidates = strictly_matching_shape_shifting_variants(inst, variants);
if (!candidates.empty()) {
  recipe_ordinal exemplar = best_shape_shifting_variant(inst, candidates);
  trace(102, "transform") << "found variant to specialize: " << exemplar << ' ' << get(Recipe, exemplar).name << end();
  string new_recipe_name = insert_new_variant(exemplar, inst, caller_recipe);
  if (new_recipe_name != "") {
    trace(102, "transform") << "new specialization: " << new_recipe_name << end();
    return new_recipe_name;
  }
}

//: before running Mu programs, make sure no unspecialized shape-shifting
//: recipes can be called

:(before "End Instruction Operation Checks")
if (contains_key(Recipe, inst.operation) && !is_primitive(inst.operation)
    && any_type_ingredient_in_header(inst.operation)) {
  raise << maybe(caller.name) << "instruction '" << inst.name << "' has no valid specialization\n" << end();
  return;
}

:(code)
// phase 3 of static dispatch
vector<recipe_ordinal> strictly_matching_shape_shifting_variants(const instruction& inst, const vector<recipe_ordinal>& variants) {
  vector<recipe_ordinal> result;
  for (int i = 0;  i < SIZE(variants);  ++i) {
    if (variants.at(i) == -1) continue;
    if (!any_type_ingredient_in_header(variants.at(i))) continue;
    if (!all_concrete_header_reagents_strictly_match(inst, get(Recipe, variants.at(i)))) continue;
    result.push_back(variants.at(i));
  }
  return result;
}

bool all_concrete_header_reagents_strictly_match(const instruction& inst, const recipe& variant) {
  for (int i = 0;  i < min(SIZE(inst.ingredients), SIZE(variant.ingredients));  ++i) {
    if (!concrete_type_names_strictly_match(variant.ingredients.at(i), inst.ingredients.at(i))) {
      trace(103, "transform") << "concrete-type match failed: ingredient " << i << end();
      return false;
    }
  }
  for (int i = 0;  i < min(SIZE(inst.products), SIZE(variant.products));  ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!concrete_type_names_strictly_match(variant.products.at(i), inst.products.at(i))) {
      trace(103, "transform") << "concrete-type match failed: product " << i << end();
      return false;
    }
  }
  return true;
}

// manual prototype
vector<recipe_ordinal> keep_max(const instruction&, const vector<recipe_ordinal>&,
                                int (*)(const instruction&, recipe_ordinal));

// tie-breaker for phase 3
recipe_ordinal best_shape_shifting_variant(const instruction& inst, const vector<recipe_ordinal>& candidates) {
  assert(!candidates.empty());
  if (SIZE(candidates) == 1) return candidates.at(0);
//?   cerr << "A picking shape-shifting variant:\n";
  vector<recipe_ordinal> result1 = keep_max(inst, candidates, number_of_concrete_type_names);
  assert(!result1.empty());
  if (SIZE(result1) == 1) return result1.at(0);
//?   cerr << "B picking shape-shifting variant:\n";
  vector<recipe_ordinal> result2 = keep_max(inst, result1, arity_fit);
  assert(!result2.empty());
  if (SIZE(result2) == 1) return result2.at(0);
//?   cerr << "C picking shape-shifting variant:\n";
  vector<recipe_ordinal> result3 = keep_max(inst, result2, number_of_type_ingredients);
  if (SIZE(result3) > 1) {
    raise << "\nCouldn't decide the best shape-shifting variant for instruction '" << to_original_string(inst) << "'\n" << end();
    cerr << "This is a hole in Mu. Please copy the following candidates into an email to Kartik Agaram <mu@akkartik.com>\n";
    for (int i = 0;  i < SIZE(candidates);  ++i)
      cerr << "  " << header_label(get(Recipe, candidates.at(i))) << '\n';
  }
  return result3.at(0);
}

vector<recipe_ordinal> keep_max(const instruction& inst, const vector<recipe_ordinal>& in,
                                int (*scorer)(const instruction&, recipe_ordinal)) {
  assert(!in.empty());
  vector<recipe_ordinal> out;
  out.push_back(in.at(0));
  int best_score = (*scorer)(inst, in.at(0));
//?   cerr << best_score << " " << header_label(get(Recipe, in.at(0))) << '\n';
  for (int i = 1;  i < SIZE(in);  ++i) {
    int score = (*scorer)(inst, in.at(i));
//?     cerr << score << " " << header_label(get(Recipe, in.at(i))) << '\n';
    if (score == best_score) {
      out.push_back(in.at(i));
    }
    else if (score > best_score) {
      best_score = score;
      out.clear();
      out.push_back(in.at(i));
    }
  }
  return out;
}

int arity_fit(const instruction& inst, recipe_ordinal candidate) {
  const recipe& r = get(Recipe, candidate);
  return (SIZE(inst.products) - SIZE(r.products))
       + (SIZE(r.ingredients) - SIZE(inst.ingredients));
}

bool any_type_ingredient_in_header(recipe_ordinal variant) {
  const recipe& caller = get(Recipe, variant);
  for (int i = 0;  i < SIZE(caller.ingredients);  ++i) {
    if (contains_type_ingredient_name(caller.ingredients.at(i)))
      return true;
  }
  for (int i = 0;  i < SIZE(caller.products);  ++i) {
    if (contains_type_ingredient_name(caller.products.at(i)))
      return true;
  }
  return false;
}

bool concrete_type_names_strictly_match(reagent/*copy*/ to, reagent/*copy*/ from) {
  canonize_type(to);
  canonize_type(from);
  return concrete_type_names_strictly_match(to.type, from.type, from);
}

bool concrete_type_names_strictly_match(const type_tree* to, const type_tree* from, const reagent& rhs_reagent) {
  if (!to) return !from;
  if (!from) return !to;
  if (to->atom && is_type_ingredient_name(to->name)) return true;  // type ingredient matches anything
  if (!to->atom && to->right == NULL && to->left != NULL && to->left->atom && is_type_ingredient_name(to->left->name)) return true;
  if (from->atom && is_mu_address(to))
    return from->name == "literal-address" && rhs_reagent.name == "null";
  if (!from->atom && !to->atom)
    return concrete_type_names_strictly_match(to->left, from->left, rhs_reagent)
        && concrete_type_names_strictly_match(to->right, from->right, rhs_reagent);
  if (from->atom != to->atom) return false;
  // both from and to are atoms
  if (from->name == "literal")
    return Literal_type_names.find(to->name) != Literal_type_names.end();
  if (to->name == "literal")
    return Literal_type_names.find(from->name) != Literal_type_names.end();
  return to->name == from->name;
}

bool contains_type_ingredient_name(const reagent& x) {
  return contains_type_ingredient_name(x.type);
}

bool contains_type_ingredient_name(const type_tree* type) {
  if (!type) return false;
  if (is_type_ingredient_name(type->name)) return true;
  return contains_type_ingredient_name(type->left) || contains_type_ingredient_name(type->right);
}

int number_of_concrete_type_names(const instruction& /*unused*/, recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  int result = 0;
  for (int i = 0;  i < SIZE(caller.ingredients);  ++i)
    result += number_of_concrete_type_names(caller.ingredients.at(i).type);
  for (int i = 0;  i < SIZE(caller.products);  ++i)
    result += number_of_concrete_type_names(caller.products.at(i).type);
  return result;
}

int number_of_concrete_type_names(const type_tree* type) {
  if (!type) return 0;
  if (type->atom)
    return is_type_ingredient_name(type->name) ? 0 : 1;
  return number_of_concrete_type_names(type->left)
       + number_of_concrete_type_names(type->right);
}

int number_of_type_ingredients(const instruction& /*unused*/, recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  int result = 0;
  for (int i = 0;  i < SIZE(caller.ingredients);  ++i)
    result += number_of_type_ingredients(caller.ingredients.at(i).type);
  for (int i = 0;  i < SIZE(caller.products);  ++i)
    result += number_of_type_ingredients(caller.products.at(i).type);
  return result;
}

int number_of_type_ingredients(const type_tree* type) {
  if (!type) return 0;
  if (type->atom)
    return is_type_ingredient_name(type->name) ? 1 : 0;
  return number_of_type_ingredients(type->left)
       + number_of_type_ingredients(type->right);
}

// returns name of new variant
string insert_new_variant(recipe_ordinal exemplar, const instruction& inst, const recipe& caller_recipe) {
  string new_name = next_unused_recipe_name(inst.name);
  assert(!contains_key(Recipe_ordinal, new_name));
  recipe_ordinal new_recipe_ordinal = put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
  // make a copy
  assert(contains_key(Recipe, exemplar));
  assert(!contains_key(Recipe, new_recipe_ordinal));
  put(Recipe, new_recipe_ordinal, /*copy*/get(Recipe, exemplar));
  recipe& new_recipe = get(Recipe, new_recipe_ordinal);
  new_recipe.name = new_name;
  new_recipe.ordinal = new_recipe_ordinal;
  new_recipe.is_autogenerated = true;
  trace(103, "transform") << "switching " << inst.name << " to specialized " << header_label(new_recipe) << end();

  trace(102, "transform") << "transforming new specialization: " << new_recipe.name << end();
  trace(102, "transform") << new_recipe.name << ": performing transforms until check_or_set_types_by_name" << end();
  int transform_index = 0;
  for (transform_index = 0;  transform_index < SIZE(Transform);  ++transform_index) {
    if (Transform.at(transform_index) == check_or_set_types_by_name) break;
    (*Transform.at(transform_index))(new_recipe_ordinal);
  }
  new_recipe.transformed_until = transform_index-1;

  trace(102, "transform") << new_recipe.name << ": performing type-ingredient-aware version of transform check_or_set_types_by_name" << end();
  compute_type_names(new_recipe);
  new_recipe.transformed_until++;

  trace(102, "transform") << new_recipe.name << ": replacing type ingredients" << end();
  {
    map<string, const type_tree*> mappings;
    bool error = false;
    compute_type_ingredient_mappings(get(Recipe, exemplar), inst, mappings, caller_recipe, &error);
    if (!error) error = (SIZE(mappings) != type_ingredient_count_in_header(exemplar));
    if (!error) replace_type_ingredients(new_recipe, mappings);
    for (map<string, const type_tree*>::iterator p = mappings.begin();  p != mappings.end();  ++p)
      delete p->second;
    if (error) return "";
  }
  ensure_all_concrete_types(new_recipe, get(Recipe, exemplar));

  trace(102, "transform") << new_recipe.name << ": recording the new variant before recursively calling resolve_ambiguous_calls" << end();
  get(Recipe_variants, inst.name).push_back(new_recipe_ordinal);
  trace(102, "transform") << new_recipe.name << ": performing remaining transforms (including resolve_ambiguous_calls)" << end();
  for (/*nada*/;  transform_index < SIZE(Transform);  ++transform_index)
    (*Transform.at(transform_index))(new_recipe_ordinal);
  new_recipe.transformed_until = SIZE(Transform)-1;
  return new_recipe.name;
}

void compute_type_names(recipe& variant) {
  trace(103, "transform") << "-- compute type names: " << variant.name << end();
  map<string, type_tree*> type_names;
  for (int i = 0;  i < SIZE(variant.ingredients);  ++i)
    save_or_deduce_type_name(variant.ingredients.at(i), type_names, variant, "");
  for (int i = 0;  i < SIZE(variant.products);  ++i)
    save_or_deduce_type_name(variant.products.at(i), type_names, variant, "");
  for (int i = 0;  i < SIZE(variant.steps);  ++i) {
    instruction& inst = variant.steps.at(i);
    trace(103, "transform") << "  instruction: " << to_string(inst) << end();
    for (int in = 0;  in < SIZE(inst.ingredients);  ++in)
      save_or_deduce_type_name(inst.ingredients.at(in), type_names, variant, " in '" + to_original_string(inst) + "'");
    for (int out = 0;  out < SIZE(inst.products);  ++out)
      save_or_deduce_type_name(inst.products.at(out), type_names, variant, " in '" + to_original_string(inst) + "'");
  }
}

void save_or_deduce_type_name(reagent& x, map<string, type_tree*>& type, const recipe& variant, const string& context) {
  trace(104, "transform") << "    checking " << to_string(x) << ": " << names_to_string(x.type) << end();
  if (!x.type && contains_key(type, x.name)) {
    x.type = new type_tree(*get(type, x.name));
    trace(104, "transform") << "    deducing type to " << names_to_string(x.type) << end();
    return;
  }
  // Type Check in Type-ingredient-aware check_or_set_types_by_name
  // This is different from check_or_set_types_by_name.
  // We've found it useful in the past for tracking down bugs in
  // specialization.
  if (!x.type) {
    raise << maybe(variant.original_name) << "unknown type for '" << x.original_string << "'" << context << " (check the name for typos)\n" << end();
    return;
  }
  if (contains_key(type, x.name)) return;
  if (x.type->name == "offset" || x.type->name == "variant") return;  // special-case for container-access instructions
  put(type, x.name, x.type);
  trace(103, "transform") << "type of '" << x.name << "' is " << names_to_string(x.type) << end();
}

void compute_type_ingredient_mappings(const recipe& exemplar, const instruction& inst, map<string, const type_tree*>& mappings, const recipe& caller_recipe, bool* error) {
  int limit = min(SIZE(inst.ingredients), SIZE(exemplar.ingredients));
  for (int i = 0;  i < limit;  ++i) {
    const reagent& exemplar_reagent = exemplar.ingredients.at(i);
    reagent/*copy*/ ingredient = inst.ingredients.at(i);
    canonize_type(ingredient);
    if (is_mu_address(exemplar_reagent) && ingredient.name == "null") continue;  // assume it matches
    accumulate_type_ingredients(exemplar_reagent, ingredient, mappings, exemplar, inst, caller_recipe, error);
  }
  limit = min(SIZE(inst.products), SIZE(exemplar.products));
  for (int i = 0;  i < limit;  ++i) {
    const reagent& exemplar_reagent = exemplar.products.at(i);
    reagent/*copy*/ product = inst.products.at(i);
    if (is_dummy(product)) continue;
    canonize_type(product);
    accumulate_type_ingredients(exemplar_reagent, product, mappings, exemplar, inst, caller_recipe, error);
  }
}

void accumulate_type_ingredients(const reagent& exemplar_reagent, reagent& refinement, map<string, const type_tree*>& mappings, const recipe& exemplar, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  assert(refinement.type);
  accumulate_type_ingredients(exemplar_reagent.type, refinement.type, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
}

void accumulate_type_ingredients(const type_tree* exemplar_type, const type_tree* refinement_type, map<string, const type_tree*>& mappings, const recipe& exemplar, const reagent& exemplar_reagent, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  if (!exemplar_type) return;
  if (!refinement_type) {
    // probably a bug in mu
    // todo: make this smarter; only flag an error if exemplar_type contains some *new* type ingredient
    raise << maybe(exemplar.name) << "missing type ingredient for " << exemplar_reagent.original_string << '\n' << end();
    raise << "  (called from '" << to_original_string(call_instruction) << "')\n" << end();
    return;
  }
  if (!exemplar_type->atom && exemplar_type->right == NULL && !refinement_type->atom && refinement_type->right != NULL) {
    exemplar_type = exemplar_type->left;
    assert_for_now(exemplar_type->atom);
  }
  if (exemplar_type->atom) {
    if (is_type_ingredient_name(exemplar_type->name)) {
      const type_tree* curr_refinement_type = NULL;  // temporary heap allocation; must always be deleted before it goes out of scope
      if (exemplar_type->atom)
        curr_refinement_type = new type_tree(*refinement_type);
      else {
        assert(!refinement_type->atom);
        curr_refinement_type = new type_tree(*refinement_type->left);
      }
      if (!contains_key(mappings, exemplar_type->name)) {
        trace(103, "transform") << "adding mapping from " << exemplar_type->name << " to " << to_string(curr_refinement_type) << end();
        put(mappings, exemplar_type->name, new type_tree(*curr_refinement_type));
      }
      else {
        if (!deeply_equal_type_names(get(mappings, exemplar_type->name), curr_refinement_type)) {
          raise << maybe(caller_recipe.name) << "no call found for '" << to_original_string(call_instruction) << "'\n" << end();
          *error = true;
          delete curr_refinement_type;
          return;
        }
        if (get(mappings, exemplar_type->name)->name == "literal") {
          delete get(mappings, exemplar_type->name);
          put(mappings, exemplar_type->name, new type_tree(*curr_refinement_type));
        }
      }
      delete curr_refinement_type;
    }
  }
  else {
    accumulate_type_ingredients(exemplar_type->left, refinement_type->left, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
    accumulate_type_ingredients(exemplar_type->right, refinement_type->right, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
  }
}

void replace_type_ingredients(recipe& new_recipe, const map<string, const type_tree*>& mappings) {
  // update its header
  if (mappings.empty()) return;
  trace(103, "transform") << "replacing in recipe header ingredients" << end();
  for (int i = 0;  i < SIZE(new_recipe.ingredients);  ++i)
    replace_type_ingredients(new_recipe.ingredients.at(i), mappings, new_recipe);
  trace(103, "transform") << "replacing in recipe header products" << end();
  for (int i = 0;  i < SIZE(new_recipe.products);  ++i)
    replace_type_ingredients(new_recipe.products.at(i), mappings, new_recipe);
  // update its body
  for (int i = 0;  i < SIZE(new_recipe.steps);  ++i) {
    instruction& inst = new_recipe.steps.at(i);
    trace(103, "transform") << "replacing in instruction '" << to_string(inst) << "'" << end();
    for (int j = 0;  j < SIZE(inst.ingredients);  ++j)
      replace_type_ingredients(inst.ingredients.at(j), mappings, new_recipe);
    for (int j = 0;  j < SIZE(inst.products);  ++j)
      replace_type_ingredients(inst.products.at(j), mappings, new_recipe);
    // special-case for new: replace type ingredient in first ingredient *value*
    if (inst.name == "new" && inst.ingredients.at(0).type->name != "literal-string") {
      type_tree* type = parse_type_tree(inst.ingredients.at(0).name);
      replace_type_ingredients(type, mappings);
      inst.ingredients.at(0).name = inspect(type);
      delete type;
    }
  }
}

void replace_type_ingredients(reagent& x, const map<string, const type_tree*>& mappings, const recipe& caller) {
  string before = to_string(x);
  trace(103, "transform") << "replacing in ingredient " << x.original_string << end();
  if (!x.type) {
    raise << "specializing " << caller.original_name << ": missing type for '" << x.original_string << "'\n" << end();
    return;
  }
  replace_type_ingredients(x.type, mappings);
}

void replace_type_ingredients(type_tree* type, const map<string, const type_tree*>& mappings) {
  if (!type) return;
  if (!type->atom) {
    if (type->right == NULL && type->left != NULL && type->left->atom && contains_key(mappings, type->left->name) && !get(mappings, type->left->name)->atom && get(mappings, type->left->name)->right != NULL) {
      *type = *get(mappings, type->left->name);
      return;
    }
    replace_type_ingredients(type->left, mappings);
    replace_type_ingredients(type->right, mappings);
    return;
  }
  if (contains_key(Type_ordinal, type->name))  // todo: ugly side effect
    type->value = get(Type_ordinal, type->name);
  if (!contains_key(mappings, type->name))
    return;
  const type_tree* replacement = get(mappings, type->name);
  trace(103, "transform") << type->name << " => " << names_to_string(replacement) << end();
  if (replacement->atom) {
    if (!contains_key(Type_ordinal, replacement->name)) {
      // error in program; should be reported elsewhere
      return;
    }
    type->name = (replacement->name == "literal") ? "number" : replacement->name;
    type->value = get(Type_ordinal, type->name);
  }
  else {
    *type = *replacement;
  }
}

int type_ingredient_count_in_header(recipe_ordinal variant) {
  const recipe& caller = get(Recipe, variant);
  set<string> type_ingredients;
  for (int i = 0;  i < SIZE(caller.ingredients);  ++i)
    accumulate_type_ingredients(caller.ingredients.at(i).type, type_ingredients);
  for (int i = 0;  i < SIZE(caller.products);  ++i)
    accumulate_type_ingredients(caller.products.at(i).type, type_ingredients);
  return SIZE(type_ingredients);
}

void accumulate_type_ingredients(const type_tree* type, set<string>& out) {
  if (!type) return;
  if (is_type_ingredient_name(type->name)) out.insert(type->name);
  accumulate_type_ingredients(type->left, out);
  accumulate_type_ingredients(type->right, out);
}

type_tree* parse_type_tree(const string& s) {
  string_tree* s2 = parse_string_tree(s);
  type_tree* result = new_type_tree(s2);
  delete s2;
  return result;
}

string inspect(const type_tree* x) {
  ostringstream out;
  dump_inspect(x, out);
  return out.str();
}

void dump_inspect(const type_tree* x, ostream& out) {
  if (!x->left && !x->right) {
    out << x->name;
    return;
  }
  out << '(';
  for (const type_tree* curr = x;  curr;  curr = curr->right) {
    if (curr != x) out << ' ';
    if (curr->left)
      dump_inspect(curr->left, out);
    else
      out << curr->name;
  }
  out << ')';
}

void ensure_all_concrete_types(/*const*/ recipe& new_recipe, const recipe& exemplar) {
  trace(103, "transform") << "-- ensure all concrete types in recipe " << new_recipe.name << end();
  for (int i = 0;  i < SIZE(new_recipe.ingredients);  ++i)
    ensure_all_concrete_types(new_recipe.ingredients.at(i), exemplar);
  for (int i = 0;  i < SIZE(new_recipe.products);  ++i)
    ensure_all_concrete_types(new_recipe.products.at(i), exemplar);
  for (int i = 0;  i < SIZE(new_recipe.steps);  ++i) {
    instruction& inst = new_recipe.steps.at(i);
    for (int j = 0;  j < SIZE(inst.ingredients);  ++j)
      ensure_all_concrete_types(inst.ingredients.at(j), exemplar);
    for (int j = 0;  j < SIZE(inst.products);  ++j)
      ensure_all_concrete_types(inst.products.at(j), exemplar);
  }
}

void ensure_all_concrete_types(/*const*/ reagent& x, const recipe& exemplar) {
  if (!x.type || contains_type_ingredient_name(x.type)) {
    raise << maybe(exemplar.name) << "failed to map a type to " << x.original_string << '\n' << end();
    if (!x.type) x.type = new type_tree("added_by_ensure_all_concrete_types", 0);  // just to prevent crashes later
    return;
  }
  if (x.type->value == -1) {
    raise << maybe(exemplar.name) << "failed to map a type to the unknown " << x.original_string << '\n' << end();
    return;
  }
}

void test_shape_shifting_recipe_2() {
  run(
      "def main [\n"
      "  10:point <- merge 14, 15\n"
      "  12:point <- foo 10:point\n"
      "]\n"
      // non-matching shape-shifting variant
      "def foo a:_t, b:_t -> result:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy 34\n"
      "]\n"
      // matching shape-shifting variant
      "def foo a:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy a\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 14 in location 12\n"
      "mem: storing 15 in location 13\n"
  );
}

void test_shape_shifting_recipe_nonroot() {
  run(
      "def main [\n"
      "  10:foo:point <- merge 14, 15, 16\n"
      "  20:point <- bar 10:foo:point\n"
      "]\n"
      // shape-shifting recipe with type ingredient following some other type
      "def bar a:foo:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- get a, x:offset\n"
      "]\n"
      "container foo:_t [\n"
      "  x:_t\n"
      "  y:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 14 in location 20\n"
      "mem: storing 15 in location 21\n"
  );
}

void test_shape_shifting_recipe_nested() {
  run(
      "container c:_a:_b [\n"
      "  a:_a\n"
      "  b:_b\n"
      "]\n"
      "def main [\n"
      "  s:text <- new [abc]\n"
      "  {x: (c (address array character) number)} <- merge s, 34\n"
      "  foo x\n"
      "]\n"
      "def foo x:c:_bar:_baz [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "]\n"
  );
  // no errors
}

void test_shape_shifting_recipe_type_deduction_ignores_offsets() {
  run(
      "def main [\n"
      "  10:foo:point <- merge 14, 15, 16\n"
      "  20:point <- bar 10:foo:point\n"
      "]\n"
      "def bar a:foo:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  x:num <- copy 1\n"
      "  result <- get a, x:offset  # shouldn't collide with other variable\n"
      "]\n"
      "container foo:_t [\n"
      "  x:_t\n"
      "  y:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 14 in location 20\n"
      "mem: storing 15 in location 21\n"
  );
}

void test_shape_shifting_recipe_empty() {
  run(
      "def main [\n"
      "  foo 1\n"
      "]\n"
      // shape-shifting recipe with no body
      "def foo a:_t [\n"
      "]\n"
  );
  // shouldn't crash
}

void test_shape_shifting_recipe_handles_shape_shifting_new_ingredient() {
  run(
      "def main [\n"
      "  1:&:foo:point <- bar 3\n"
      "  11:foo:point <- copy *1:&:foo:point\n"
      "]\n"
      "container foo:_t [\n"
      "  x:_t\n"
      "  y:num\n"
      "]\n"
      "def bar x:num -> result:&:foo:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
         // new refers to _t in its ingredient *value*
      "  result <- new {(foo _t) : type}\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 11\n"
      "mem: storing 0 in location 12\n"
      "mem: storing 0 in location 13\n"
  );
}

void test_shape_shifting_recipe_handles_shape_shifting_new_ingredient_2() {
  run(
      "def main [\n"
      "  1:&:foo:point <- bar 3\n"
      "  11:foo:point <- copy *1:&:foo:point\n"
      "]\n"
      "def bar x:num -> result:&:foo:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
         // new refers to _t in its ingredient *value*
      "  result <- new {(foo _t) : type}\n"
      "]\n"
      // container defined after use
      "container foo:_t [\n"
      "  x:_t\n"
      "  y:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 11\n"
      "mem: storing 0 in location 12\n"
      "mem: storing 0 in location 13\n"
  );
}

void test_shape_shifting_recipe_called_with_dummy() {
  run(
      "def main [\n"
      "  _ <- bar 34\n"
      "]\n"
      "def bar x:_t -> result:&:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy null\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

// this one needs a little more fine-grained control
void test_shape_shifting_new_ingredient_does_not_pollute_global_namespace() {
  // if you specialize a shape-shifting recipe that allocates a type-ingredient..
  transform("def barz x:_elem [\n"
            "  local-scope\n"
            "  load-ingredients\n"
            "  y:&:num <- new _elem:type\n"
            "]\n"
            "def fooz [\n"
            "  local-scope\n"
            "  barz 34\n"
            "]\n");
  // ..and if you then try to load a new shape-shifting container with that
  // type-ingredient
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "  y:num\n"
      "]\n");
  // then it should work as usual
  reagent callsite("x:foo:point");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.type->name, "point");
  CHECK(!element.type->right);
}

//: specializing a type ingredient with a compound type
void test_shape_shifting_recipe_supports_compound_types() {
  run(
      "def main [\n"
      "  1:&:point <- new point:type\n"
      "  *1:&:point <- put *1:&:point, y:offset, 34\n"
      "  3:&:point <- bar 1:&:point  # specialize _t to address:point\n"
      "  5:point <- copy *3:&:point\n"
      "]\n"
      "def bar a:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- copy a\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 6\n"
  );
}

//: specializing a type ingredient with a compound type -- while *inside* another compound type
void test_shape_shifting_recipe_supports_compound_types_2() {
  run(
      "container foo:_t [\n"
      "  value:_t\n"
      "]\n"
      "def bar x:&:foo:_t -> result:_t [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  result <- get *x, value:offset\n"
      "]\n"
      "def main [\n"
      "  1:&:foo:&:point <- new {(foo address point): type}\n"
      "  2:&:point <- bar 1:&:foo:&:point\n"
      "]\n"
  );
  // no errors; call to 'bar' successfully specialized
}

void test_shape_shifting_recipe_error() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  a:num <- copy 3\n"
      "  b:&:num <- foo a\n"
      "]\n"
      "def foo a:_t -> b:_t [\n"
      "  load-ingredients\n"
      "  b <- copy a\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: no call found for 'b:&:num <- foo a'\n"
  );
}

void test_specialize_inside_recipe_without_header() {
  run(
      "def main [\n"
      "  foo 3\n"
      "]\n"
      "def foo [\n"
      "  local-scope\n"
      "  x:num <- next-ingredient  # ensure no header\n"
      "  1:num/raw <- bar x  # call a shape-shifting recipe\n"
      "]\n"
      "def bar x:_elem -> y:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- add x, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 4 in location 1\n"
  );
}

void test_specialize_with_literal() {
  run(
      "def main [\n"
      "  local-scope\n"
         // permit literal to map to number
      "  1:num/raw <- foo 3\n"
      "]\n"
      "def foo x:_elem -> y:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- add x, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 4 in location 1\n"
  );
}

void test_specialize_with_literal_2() {
  run(
      "def main [\n"
      "  local-scope\n"
         // permit literal to map to character
      "  1:char/raw <- foo 3\n"
      "]\n"
      "def foo x:_elem -> y:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- add x, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 4 in location 1\n"
  );
}

void test_specialize_with_literal_3() {
  run(
      "def main [\n"
      "  local-scope\n"
         // permit '0' to map to address to shape-shifting type-ingredient
      "  1:&:char/raw <- foo null\n"
      "]\n"
      "def foo x:&:_elem -> y:&:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- copy x\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 1\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_specialize_with_literal_4() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  local-scope\n"
         // ambiguous call: what's the type of its ingredient?!
      "  foo 0\n"
      "]\n"
      "def foo x:&:_elem -> y:&:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- copy x\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: instruction 'foo' has no valid specialization\n"
  );
}

void test_specialize_with_literal_5() {
  run(
      "def main [\n"
      "  foo 3, 4\n"  // recipe mapping two variables to literals
      "]\n"
      "def foo x:_elem, y:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  1:num/raw <- add x, y\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 7 in location 1\n"
  );
}

void test_multiple_shape_shifting_variants() {
  run(
      // try to call two different shape-shifting recipes with the same name
      "def main [\n"
      "  e1:d1:num <- merge 3\n"
      "  e2:d2:num <- merge 4, 5\n"
      "  1:num/raw <- foo e1\n"
      "  2:num/raw <- foo e2\n"
      "]\n"
      // the two shape-shifting definitions
      "def foo a:d1:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      "def foo a:d2:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
      // the shape-shifting containers they use
      "container d1:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container d2:_elem [\n"
      "  x:num\n"
      "  y:_elem\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 1\n"
      "mem: storing 35 in location 2\n"
  );
}

void test_multiple_shape_shifting_variants_2() {
  run(
      // static dispatch between shape-shifting variants, _including pointer lookups_
      "def main [\n"
      "  e1:d1:num <- merge 3\n"
      "  e2:&:d2:num <- new {(d2 number): type}\n"
      "  1:num/raw <- foo e1\n"
      "  2:num/raw <- foo *e2\n"  // different from previous scenario
      "]\n"
      "def foo a:d1:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      "def foo a:d2:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
      "container d1:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container d2:_elem [\n"
      "  x:num\n"
      "  y:_elem\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 1\n"
      "mem: storing 35 in location 2\n"
  );
}

void test_missing_type_in_shape_shifting_recipe() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  a:d1:num <- merge 3\n"
      "  foo a\n"
      "]\n"
      "def foo a:d1:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  copy e\n"  // no such variable
      "  return 34\n"
      "]\n"
      "container d1:_elem [\n"
      "  x:_elem\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: unknown type for 'e' in 'copy e' (check the name for typos)\n"
      "error: specializing foo: missing type for 'e'\n"
  );
  // and it doesn't crash
}

void test_missing_type_in_shape_shifting_recipe_2() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  a:d1:num <- merge 3\n"
      "  foo a\n"
      "]\n"
      "def foo a:d1:_elem -> b:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  get e, x:offset\n"  // unknown variable in a 'get', which does some extra checking
      "  return 34\n"
      "]\n"
      "container d1:_elem [\n"
      "  x:_elem\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: unknown type for 'e' in 'get e, x:offset' (check the name for typos)\n"
      "error: specializing foo: missing type for 'e'\n"
  );
  // and it doesn't crash
}

void test_specialize_recursive_shape_shifting_recipe() {
  transform(
      "def main [\n"
      "  1:num <- copy 34\n"
      "  2:num <- foo 1:num\n"
      "]\n"
      "def foo x:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  {\n"
      "    break\n"
      "    y:num <- foo x\n"
      "  }\n"
      "  return y\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: new specialization: foo_2\n"
  );
  // transform terminates
}

void test_specialize_most_similar_variant() {
  run(
      "def main [\n"
      "  1:&:num <- new number:type\n"
      "  10:num <- foo 1:&:num\n"
      "]\n"
      "def foo x:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      "def foo x:&:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 35 in location 10\n"
  );
}

void test_specialize_most_similar_variant_2() {
  run(
      // version with headers padded with lots of unrelated concrete types
      "def main [\n"
      "  1:num <- copy 23\n"
      "  2:&:@:num <- copy null\n"
      "  4:num <- foo 2:&:@:num, 1:num\n"
      "]\n"
      // variant with concrete type
      "def foo dummy:&:@:num, x:num -> y:num, dummy:&:@:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      // shape-shifting variant
      "def foo dummy:&:@:num, x:_elem -> y:num, dummy:&:@:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  // prefer the concrete variant
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 4\n"
  );
}

void test_specialize_most_similar_variant_3() {
  run(
      "def main [\n"
      "  1:text <- new [abc]\n"
      "  foo 1:text\n"
      "]\n"
      "def foo x:text [\n"
      "  10:num <- copy 34\n"
      "]\n"
      "def foo x:&:_elem [\n"
      "  10:num <- copy 35\n"
      "]\n"
  );
  // make sure the more precise version was used
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 10\n"
  );
}

void test_specialize_literal_as_number() {
  run(
      "def main [\n"
      "  1:num <- foo 23\n"
      "]\n"
      "def foo x:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      "def foo x:char -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 1\n"
  );
}

void test_specialize_literal_as_number_2() {
  run(
      // version calling with literal
      "def main [\n"
      "  1:num <- foo 0\n"
      "]\n"
      // variant with concrete type
      "def foo x:num -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      // shape-shifting variant
      "def foo x:&:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  // prefer the concrete variant, ignore concrete types in scoring the shape-shifting variant
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 1\n"
  );
}

void test_specialize_literal_as_address() {
  run(
      "def main [\n"
      "  1:num <- foo null\n"
      "]\n"
      // variant with concrete address type
      "def foo x:&:num -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 34\n"
      "]\n"
      // shape-shifting variant
      "def foo x:&:_elem -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  // prefer the concrete variant, ignore concrete types in scoring the shape-shifting variant
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 1\n"
  );
}

void test_missing_type_during_specialization() {
  Hide_errors = true;
  run(
      // define a shape-shifting recipe
      "def foo a:_elem [\n"
      "]\n"
      // define a container with field 'z'
      "container foo2 [\n"
      "  z:num\n"
      "]\n"
      "def main [\n"
      "  local-scope\n"
      "  x:foo2 <- merge 34\n"
      "  y:num <- get x, z:offse  # typo in 'offset'\n"
         // define a variable with the same name 'z'
      "  z:num <- copy 34\n"
      "  foo z\n"
      "]\n"
  );
  // shouldn't crash
}

void test_missing_type_during_specialization2() {
  Hide_errors = true;
  run(
      // define a shape-shifting recipe
      "def foo a:_elem [\n"
      "]\n"
      // define a container with field 'z'
      "container foo2 [\n"
      "  z:num\n"
      "]\n"
      "def main [\n"
      "  local-scope\n"
      "  x:foo2 <- merge 34\n"
      "  y:num <- get x, z:offse  # typo in 'offset'\n"
         // define a variable with the same name 'z'
      "  z:&:num <- copy 34\n"
         // trigger specialization of the shape-shifting recipe
      "  foo *z\n"
      "]\n"
  );
  // shouldn't crash
}

void test_tangle_shape_shifting_recipe() {
  run(
      // shape-shifting recipe
      "def foo a:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  <label1>\n"
      "]\n"
      // tangle some code that refers to the type ingredient
      "after <label1> [\n"
      "  b:_elem <- copy a\n"
      "]\n"
      // trigger specialization
      "def main [\n"
      "  local-scope\n"
      "  foo 34\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_tangle_shape_shifting_recipe_with_type_abbreviation() {
  run(
      // shape-shifting recipe
      "def foo a:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  <label1>\n"
      "]\n"
      // tangle some code that refers to the type ingredient
      "after <label1> [\n"
      "  b:bool <- copy false\n"  // type abbreviation
      "]\n"
      // trigger specialization
      "def main [\n"
      "  local-scope\n"
      "  foo 34\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_shape_shifting_recipe_coexists_with_primitive() {
  run(
      // recipe overloading a primitive with a generic type
      "def add a:&:foo:_elem [\n"
      "  assert 0, [should not get here]\n"
      "]\n"
      "def main [\n"
         // call primitive add with literal 0
      "  add 0, 0\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_specialization_heuristic_test_1() {
  run(
      // modeled on the 'buffer' container in text.mu
      "container foo_buffer:_elem [\n"
      "  x:num\n"
      "]\n"
      "def main [\n"
      "  append 1:&:foo_buffer:char/raw, 2:text/raw\n"
      "]\n"
      "def append buf:&:foo_buffer:_elem, x:_elem -> buf:&:foo_buffer:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  stash 34\n"
      "]\n"
      "def append buf:&:foo_buffer:char, x:_elem -> buf:&:foo_buffer:char [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  stash 35\n"
      "]\n"
      "def append buf:&:foo_buffer:_elem, x:&:@:_elem -> buf:&:foo_buffer:_elem [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  stash 36\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: 36\n"
  );
}
