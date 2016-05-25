//:: Like container definitions, recipes too can contain type parameters.

:(scenario shape_shifting_recipe)
def main [
  10:point <- merge 14, 15
  11:point <- foo 10:point
]
# non-matching variant
def foo a:number -> result:number [
  local-scope
  load-ingredients
  result <- copy 34
]
# matching shape-shifting variant
def foo a:_t -> result:_t [
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
  raise << "ran into unspecialized shape-shifting recipe " << current_recipe_name() << '\n' << end();
//?   exit(0);
}

//: Make sure we don't match up literals with type ingredients without
//: specialization.
:(before "End Matching Types For Literal(to)")
if (contains_type_ingredient_name(to)) return false;

//: save original name of specialized recipes
:(before "End recipe Fields")
string original_name;
//: original name is only set during load
:(before "End Load Recipe Name")
result.original_name = result.name;

:(after "Static Dispatch Phase 3")
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
    for (int t = 0; t < SIZE(Transform); ++t) {
      // one exception: skip tangle, which would have already occurred inside new_variant above
      if (Transform.at(t) == /*disambiguate overloading*/static_cast<transform_fn>(insert_fragments))
        continue;
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
  raise << maybe(caller.name) << "instruction '" << inst.name << "' has no valid specialization\n" << end();
  return;
}

:(replace{} "bool types_strictly_match_except_literal_zero_against_address(const reagent& to, const reagent& from)")
bool types_strictly_match_except_literal_zero_against_address(const reagent& to, const reagent& from) {
  if (is_literal(from) && is_mu_address(to))
    return from.name == "0" && !contains_type_ingredient_name(to);
  return types_strictly_match(to, from);
}

:(code)
// phase 2 of static dispatch
vector<recipe_ordinal> strictly_matching_shape_shifting_variants(const instruction& inst, vector<recipe_ordinal>& variants) {
  vector<recipe_ordinal> result;
  for (int i = 0; i < SIZE(variants); ++i) {
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
  for (int i = 0; i < SIZE(variant.ingredients); ++i) {
    if (!concrete_type_names_strictly_match(variant.ingredients.at(i), inst.ingredients.at(i))) {
      trace(9993, "transform") << "concrete-type match failed: ingredient " << i << end();
      return false;
    }
  }
  for (int i = 0; i < SIZE(inst.products); ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!concrete_type_names_strictly_match(variant.products.at(i), inst.products.at(i))) {
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
  int max_score = -1;
  for (int i = 0; i < SIZE(candidates); ++i) {
    int score = number_of_concrete_type_names(candidates.at(i));
    assert(score > -1);
    if (score > max_score) max_score = score;
  }
  // break any ties at max_score by a secondary score
  int min_score2 = 999;
  int best_index = 0;
  for (int i = 0; i < SIZE(candidates); ++i) {
    int score1 = number_of_concrete_type_names(candidates.at(i));
    assert(score1 <= max_score);
    if (score1 != max_score) continue;
    const recipe& candidate = get(Recipe, candidates.at(i));
    int score2 = (SIZE(candidate.products)-SIZE(inst.products))
                           + (SIZE(inst.ingredients)-SIZE(candidate.ingredients));
    assert(score2 < 999);
    if (score2 < min_score2) {
      min_score2 = score2;
      best_index = i;
    }
  }
  return candidates.at(best_index);
}

bool any_type_ingredient_in_header(recipe_ordinal variant) {
  const recipe& caller = get(Recipe, variant);
  for (int i = 0; i < SIZE(caller.ingredients); ++i) {
    if (contains_type_ingredient_name(caller.ingredients.at(i)))
      return true;
  }
  for (int i = 0; i < SIZE(caller.products); ++i) {
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

int number_of_concrete_type_names(recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  int result = 0;
  for (int i = 0; i < SIZE(caller.ingredients); ++i)
    result += number_of_concrete_type_names(caller.ingredients.at(i));
  for (int i = 0; i < SIZE(caller.products); ++i)
    result += number_of_concrete_type_names(caller.products.at(i));
  return result;
}

int number_of_concrete_type_names(const reagent& r) {
  return number_of_concrete_type_names(r.type);
}

int number_of_concrete_type_names(const type_tree* type) {
  if (!type) return 0;
  int result = 0;
  if (!type->name.empty() && !is_type_ingredient_name(type->name))
    result++;
  result += number_of_concrete_type_names(type->left);
  result += number_of_concrete_type_names(type->right);
  return result;
}

bool concrete_type_names_strictly_match(const type_tree* to, const type_tree* from, const reagent& rhs_reagent) {
  if (!to) return !from;
  if (!from) return !to;
  if (is_type_ingredient_name(to->name)) return true;  // type ingredient matches anything
  if (to->name == "literal" && from->name == "literal")
    return true;
  if (to->name == "literal"
      && Literal_type_names.find(from->name) != Literal_type_names.end())
    return true;
  if (from->name == "literal"
      && Literal_type_names.find(to->name) != Literal_type_names.end())
    return true;
  if (from->name == "literal" && to->name == "address")
    return rhs_reagent.name == "0";
  return to->name == from->name
      && concrete_type_names_strictly_match(to->left, from->left, rhs_reagent)
      && concrete_type_names_strictly_match(to->right, from->right, rhs_reagent);
}

bool contains_type_ingredient_name(const reagent& x) {
  return contains_type_ingredient_name(x.type);
}

bool contains_type_ingredient_name(const type_tree* type) {
  if (!type) return false;
  if (is_type_ingredient_name(type->name)) return true;
  return contains_type_ingredient_name(type->left) || contains_type_ingredient_name(type->right);
}

recipe_ordinal new_variant(recipe_ordinal exemplar, const instruction& inst, const recipe& caller_recipe) {
  string new_name = next_unused_recipe_name(inst.name);
  assert(!contains_key(Recipe_ordinal, new_name));
  recipe_ordinal new_recipe_ordinal = put(Recipe_ordinal, new_name, Next_recipe_ordinal++);
  // make a copy
  assert(contains_key(Recipe, exemplar));
  assert(!contains_key(Recipe, new_recipe_ordinal));
  recipe new_recipe = get(Recipe, exemplar);
  new_recipe.name = new_name;
  trace(9993, "transform") << "switching " << inst.name << " to specialized " << header_label(new_recipe) << end();

  // Replace type ingredients with concrete types in new_recipe.
  //
  // preprocessing: micro-manage a couple of transforms
  // a) perform tangle *before* replacing type ingredients, just in case
  // inserted code involves type ingredients
  insert_fragments(new_recipe);
  // b) do the work of check_types_by_name while supporting type-ingredients
  compute_type_names(new_recipe);
  // that gives enough information to replace type-ingredients with concrete types
  {
    map<string, const type_tree*> mappings;
    bool error = false;
    compute_type_ingredient_mappings(get(Recipe, exemplar), inst, mappings, caller_recipe, &error);
    if (!error) error = (SIZE(mappings) != type_ingredient_count_in_header(exemplar));
    if (!error) replace_type_ingredients(new_recipe, mappings);
    for (map<string, const type_tree*>::iterator p = mappings.begin(); p != mappings.end(); ++p)
      delete p->second;
    if (error) return 0;
  }
  ensure_all_concrete_types(new_recipe, get(Recipe, exemplar));
  put(Recipe, new_recipe_ordinal, new_recipe);
  return new_recipe_ordinal;
}

void compute_type_names(recipe& variant) {
  trace(9993, "transform") << "compute type names: " << variant.name << end();
  map<string, type_tree*> type_names;
  for (int i = 0; i < SIZE(variant.ingredients); ++i)
    save_or_deduce_type_name(variant.ingredients.at(i), type_names, variant);
  for (int i = 0; i < SIZE(variant.products); ++i)
    save_or_deduce_type_name(variant.products.at(i), type_names, variant);
  for (int i = 0; i < SIZE(variant.steps); ++i) {
    instruction& inst = variant.steps.at(i);
    trace(9993, "transform") << "  instruction: " << to_string(inst) << end();
    for (int in = 0; in < SIZE(inst.ingredients); ++in)
      save_or_deduce_type_name(inst.ingredients.at(in), type_names, variant);
    for (int out = 0; out < SIZE(inst.products); ++out)
      save_or_deduce_type_name(inst.products.at(out), type_names, variant);
  }
}

void save_or_deduce_type_name(reagent& x, map<string, type_tree*>& type, const recipe& variant) {
  trace(9994, "transform") << "    checking " << to_string(x) << ": " << names_to_string(x.type) << end();
  if (!x.type && contains_key(type, x.name)) {
    x.type = new type_tree(*get(type, x.name));
    trace(9994, "transform") << "    deducing type to " << names_to_string(x.type) << end();
    return;
  }
  if (!x.type) {
    raise << maybe(variant.original_name) << "unknown type for '" << x.original_string << "' (check the name for typos)\n" << end();
    return;
  }
  if (contains_key(type, x.name)) return;
  if (x.type->name == "offset" || x.type->name == "variant") return;  // special-case for container-access instructions
  put(type, x.name, x.type);
  trace(9993, "transform") << "type of '" << x.name << "' is " << names_to_string(x.type) << end();
}

void compute_type_ingredient_mappings(const recipe& exemplar, const instruction& inst, map<string, const type_tree*>& mappings, const recipe& caller_recipe, bool* error) {
  int limit = min(SIZE(inst.ingredients), SIZE(exemplar.ingredients));
  for (int i = 0; i < limit; ++i) {
    const reagent& exemplar_reagent = exemplar.ingredients.at(i);
    reagent/*copy*/ ingredient = inst.ingredients.at(i);
    canonize_type(ingredient);
    if (is_mu_address(exemplar_reagent) && ingredient.name == "0") continue;  // assume it matches
    accumulate_type_ingredients(exemplar_reagent, ingredient, mappings, exemplar, inst, caller_recipe, error);
  }
  limit = min(SIZE(inst.products), SIZE(exemplar.products));
  for (int i = 0; i < limit; ++i) {
    const reagent& exemplar_reagent = exemplar.products.at(i);
    reagent/*copy*/ product = inst.products.at(i);
    if (is_dummy(product)) continue;
    canonize_type(product);
    accumulate_type_ingredients(exemplar_reagent, product, mappings, exemplar, inst, caller_recipe, error);
  }
}

inline int min(int a, int b) {
  return (a < b) ? a : b;
}

void accumulate_type_ingredients(const reagent& exemplar_reagent, reagent& refinement, map<string, const type_tree*>& mappings, const recipe& exemplar, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  assert(refinement.type);
  accumulate_type_ingredients(exemplar_reagent.type, refinement.type, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
}

void accumulate_type_ingredients(const type_tree* exemplar_type, const type_tree* refinement_type, map<string, const type_tree*>& mappings, const recipe& exemplar, const reagent& exemplar_reagent, const instruction& call_instruction, const recipe& caller_recipe, bool* error) {
  if (!exemplar_type) return;
  if (!refinement_type) {
    // todo: make this smarter; only flag an error if exemplar_type contains some *new* type ingredient
    raise << maybe(exemplar.name) << "missing type ingredient for " << exemplar_reagent.original_string << '\n' << end();
    raise << "  (called from '" << to_original_string(call_instruction) << "')\n" << end();
    return;
  }
  if (is_type_ingredient_name(exemplar_type->name)) {
    const type_tree* curr_refinement_type = NULL;  // temporary heap allocation; must always be deleted before it goes out of scope
    if (refinement_type->left)
      curr_refinement_type = new type_tree(*refinement_type->left);
    else if (exemplar_type->right)
      // splice out refinement_type->right, it'll be used later by the exemplar_type->right
      curr_refinement_type = new type_tree(refinement_type->name, refinement_type->value, NULL);
    else
      curr_refinement_type = new type_tree(*refinement_type);
    assert(!curr_refinement_type->left);
    if (!contains_key(mappings, exemplar_type->name)) {
      trace(9993, "transform") << "adding mapping from " << exemplar_type->name << " to " << to_string(curr_refinement_type) << end();
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
  else {
    accumulate_type_ingredients(exemplar_type->left, refinement_type->left, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
  }
  accumulate_type_ingredients(exemplar_type->right, refinement_type->right, mappings, exemplar, exemplar_reagent, call_instruction, caller_recipe, error);
}

void replace_type_ingredients(recipe& new_recipe, const map<string, const type_tree*>& mappings) {
  // update its header
  if (mappings.empty()) return;
  trace(9993, "transform") << "replacing in recipe header ingredients" << end();
  for (int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    replace_type_ingredients(new_recipe.ingredients.at(i), mappings, new_recipe);
  trace(9993, "transform") << "replacing in recipe header products" << end();
  for (int i = 0; i < SIZE(new_recipe.products); ++i)
    replace_type_ingredients(new_recipe.products.at(i), mappings, new_recipe);
  // update its body
  for (int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    trace(9993, "transform") << "replacing in instruction '" << to_string(inst) << "'" << end();
    for (int j = 0; j < SIZE(inst.ingredients); ++j)
      replace_type_ingredients(inst.ingredients.at(j), mappings, new_recipe);
    for (int j = 0; j < SIZE(inst.products); ++j)
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
  trace(9993, "transform") << "replacing in ingredient " << x.original_string << end();
  if (!x.type) {
    raise << "specializing " << caller.original_name << ": missing type for '" << x.original_string << "'\n" << end();
    return;
  }
  replace_type_ingredients(x.type, mappings);
}

// todo: too complicated and likely incomplete; maybe avoid replacing in place?
void replace_type_ingredients(type_tree* type, const map<string, const type_tree*>& mappings) {
  if (!type) return;
  if (contains_key(Type_ordinal, type->name))  // todo: ugly side effect
    type->value = get(Type_ordinal, type->name);
  if (!is_type_ingredient_name(type->name) || !contains_key(mappings, type->name)) {
    replace_type_ingredients(type->left, mappings);
    replace_type_ingredients(type->right, mappings);
    return;
  }

  const type_tree* replacement = get(mappings, type->name);
  trace(9993, "transform") << type->name << " => " << names_to_string(replacement) << end();
  if (!contains_key(Type_ordinal, replacement->name)) {
    // error in program; should be reported elsewhere
    return;
  }

  // type is a single type ingredient
  assert(!type->left);
  if (!type->right) assert(!replacement->left);

  if (!replacement->right) {
    if (!replacement->left) {
      type->name = (replacement->name == "literal") ? "number" : replacement->name;
      type->value = get(Type_ordinal, type->name);
    }
    else {
      type->name = "";
      type->value = 0;
      type->left = new type_tree(*replacement);
    }
    replace_type_ingredients(type->right, mappings);
  }
  // replace non-last type?
  else if (type->right) {
    type->name = "";
    type->value = 0;
    type->left = new type_tree(*replacement);
    replace_type_ingredients(type->right, mappings);
  }
  // replace last type?
  else {
    type->name = replacement->name;
    type->value = get(Type_ordinal, type->name);
    type->right = new type_tree(*replacement->right);
  }
}

int type_ingredient_count_in_header(recipe_ordinal variant) {
  const recipe& caller = get(Recipe, variant);
  set<string> type_ingredients;
  for (int i = 0; i < SIZE(caller.ingredients); ++i)
    accumulate_type_ingredients(caller.ingredients.at(i).type, type_ingredients);
  for (int i = 0; i < SIZE(caller.products); ++i)
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
  istringstream in(s);
  in >> std::noskipws;
  return parse_type_tree(in);
}

type_tree* parse_type_tree(istream& in) {
  skip_whitespace_but_not_newline(in);
  if (!has_data(in)) return NULL;
  if (in.peek() == ')') {
    in.get();
    return NULL;
  }
  if (in.peek() != '(')
    return new type_tree(next_word(in), 0);
  in.get();  // skip '('
  type_tree* result = NULL;
  type_tree** curr = &result;
  while (in.peek() != ')') {
    assert(has_data(in));
    *curr = new type_tree("", 0);
    skip_whitespace_but_not_newline(in);
    if (in.peek() == '(')
      (*curr)->left = parse_type_tree(in);
    else
      (*curr)->name = next_word(in);
    curr = &(*curr)->right;
  }
  in.get();  // skip ')'
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
  for (const type_tree* curr = x; curr; curr = curr->right) {
    if (curr != x) out << ' ';
    if (curr->left)
      dump_inspect(curr->left, out);
    else
      out << curr->name;
  }
  out << ')';
}

void ensure_all_concrete_types(/*const*/ recipe& new_recipe, const recipe& exemplar) {
  for (int i = 0; i < SIZE(new_recipe.ingredients); ++i)
    ensure_all_concrete_types(new_recipe.ingredients.at(i), exemplar);
  for (int i = 0; i < SIZE(new_recipe.products); ++i)
    ensure_all_concrete_types(new_recipe.products.at(i), exemplar);
  for (int i = 0; i < SIZE(new_recipe.steps); ++i) {
    instruction& inst = new_recipe.steps.at(i);
    for (int j = 0; j < SIZE(inst.ingredients); ++j)
      ensure_all_concrete_types(inst.ingredients.at(j), exemplar);
    for (int j = 0; j < SIZE(inst.products); ++j)
      ensure_all_concrete_types(inst.products.at(j), exemplar);
  }
}

void ensure_all_concrete_types(/*const*/ reagent& x, const recipe& exemplar) {
  if (!x.type || contains_type_ingredient_name(x.type)) {
    raise << maybe(exemplar.name) << "failed to map a type to " << x.original_string << '\n' << end();
    if (!x.type) x.type = new type_tree("", 0);  // just to prevent crashes later
    return;
  }
  if (x.type->value == -1) {
    raise << maybe(exemplar.name) << "failed to map a type to the unknown " << x.original_string << '\n' << end();
    return;
  }
}

:(scenario shape_shifting_recipe_2)
def main [
  10:point <- merge 14, 15
  11:point <- foo 10:point
]
# non-matching shape-shifting variant
def foo a:_t, b:_t -> result:number [
  local-scope
  load-ingredients
  result <- copy 34
]
# matching shape-shifting variant
def foo a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 14 in location 11
+mem: storing 15 in location 12

:(scenario shape_shifting_recipe_nonroot)
def main [
  10:foo:point <- merge 14, 15, 16
  20:point/raw <- bar 10:foo:point
]
# shape-shifting recipe with type ingredient following some other type
def bar a:foo:_t -> result:_t [
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

:(scenario shape_shifting_recipe_nested)
container c:_a:_b [
  a:_a
  b:_b
]
def main [
  s:address:array:character <- new [abc]
  {x: (c (address array character) number)} <- merge s, 34
  foo x
]
def foo x:c:_bar:_baz [
  local-scope
  load-ingredients
]

:(scenario shape_shifting_recipe_type_deduction_ignores_offsets)
def main [
  10:foo:point <- merge 14, 15, 16
  20:point/raw <- bar 10:foo:point
]
def bar a:foo:_t -> result:_t [
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
def main [
  foo 1
]
# shape-shifting recipe with no body
def foo a:_t [
]
# shouldn't crash

:(scenario shape_shifting_recipe_handles_shape_shifting_new_ingredient)
def main [
  1:address:foo:point <- bar 3
  11:foo:point <- copy *1:address:foo:point
]
container foo:_t [
  x:_t
  y:number
]
def bar x:number -> result:address:foo:_t [
  local-scope
  load-ingredients
  # new refers to _t in its ingredient *value*
  result <- new {(foo _t) : type}
]
+mem: storing 0 in location 11
+mem: storing 0 in location 12
+mem: storing 0 in location 13

:(scenario shape_shifting_recipe_handles_shape_shifting_new_ingredient_2)
def main [
  1:address:foo:point <- bar 3
  11:foo:point <- copy *1:address:foo:point
]
def bar x:number -> result:address:foo:_t [
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

:(scenario shape_shifting_recipe_called_with_dummy)
def main [
  _ <- bar 34
]
def bar x:_t -> result:address:_t [
  local-scope
  load-ingredients
  result <- copy 0
]
$error: 0

:(code)
// this one needs a little more fine-grained control
void test_shape_shifting_new_ingredient_does_not_pollute_global_namespace() {
  Trace_file = "shape_shifting_new_ingredient_does_not_pollute_global_namespace";

  // if you specialize a shape-shifting recipe that allocates a type-ingredient..
  transform("def barz x:_elem [\n"
            "  local-scope\n"
            "  load-ingredients\n"
            "  y:address:number <- new _elem:type\n"
            "]\n"
            "def fooz [\n"
            "  local-scope\n"
            "  barz 34\n"
            "]\n");
  // ..and if you then try to load a new shape-shifting container with that
  // type-ingredient
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "  y:number\n"
      "]\n");
  // then it should work as usual
  reagent callsite("x:foo:point");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.type->name, "point");
  CHECK(!element.type->right);
}

:(scenario shape_shifting_recipe_supports_compound_types)
def main [
  1:address:point <- new point:type
  *1:address:point <- put *1:address:point, y:offset, 34
  3:address:point <- bar 1:address:point  # specialize _t to address:point
  4:point <- copy *3:address:point
]
def bar a:_t -> result:_t [
  local-scope
  load-ingredients
  result <- copy a
]
+mem: storing 34 in location 5

:(scenario shape_shifting_recipe_error)
% Hide_errors = true;
def main [
  a:number <- copy 3
  b:address:number <- foo a
]
def foo a:_t -> b:_t [
  load-ingredients
  b <- copy a
]
+error: main: no call found for 'b:address:number <- foo a'

:(scenario specialize_inside_recipe_without_header)
def main [
  foo 3
]
def foo [
  local-scope
  x:number <- next-ingredient  # ensure no header
  1:number/raw <- bar x  # call a shape-shifting recipe
]
def bar x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal)
def main [
  local-scope
  # permit literal to map to number
  1:number/raw <- foo 3
]
def foo x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal_2)
def main [
  local-scope
  # permit literal to map to character
  1:character/raw <- foo 3
]
def foo x:_elem -> y:_elem [
  local-scope
  load-ingredients
  y <- add x, 1
]
+mem: storing 4 in location 1

:(scenario specialize_with_literal_3)
def main [
  local-scope
  # permit '0' to map to address to shape-shifting type-ingredient
  1:address:character/raw <- foo 0
]
def foo x:address:_elem -> y:address:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+mem: storing 0 in location 1
$error: 0

:(scenario specialize_with_literal_4)
% Hide_errors = true;
def main [
  local-scope
  # ambiguous call: what's the type of its ingredient?!
  foo 0
]
def foo x:address:_elem -> y:address:_elem [
  local-scope
  load-ingredients
  y <- copy x
]
+error: main: instruction 'foo' has no valid specialization

:(scenario specialize_with_literal_5)
def main [
  foo 3, 4  # recipe mapping two variables to literals
]
def foo x:_elem, y:_elem [
  local-scope
  load-ingredients
  1:number/raw <- add x, y
]
+mem: storing 7 in location 1

:(scenario multiple_shape_shifting_variants)
# try to call two different shape-shifting recipes with the same name
def main [
  e1:d1:number <- merge 3
  e2:d2:number <- merge 4, 5
  1:number/raw <- foo e1
  2:number/raw <- foo e2
]
# the two shape-shifting definitions
def foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  return 34
]
def foo a:d2:_elem -> b:number [
  local-scope
  load-ingredients
  return 35
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
def main [
  e1:d1:number <- merge 3
  e2:address:d2:number <- new {(d2 number): type}
  1:number/raw <- foo e1
  2:number/raw <- foo *e2  # different from previous scenario
]
def foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  return 34
]
def foo a:d2:_elem -> b:number [
  local-scope
  load-ingredients
  return 35
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
def main [
  a:d1:number <- merge 3
  foo a
]
def foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  copy e  # no such variable
  return 34
]
container d1:_elem [
  x:_elem
]
+error: foo: unknown type for 'e' (check the name for typos)
+error: specializing foo: missing type for 'e'
# and it doesn't crash

:(scenario missing_type_in_shape_shifting_recipe_2)
% Hide_errors = true;
def main [
  a:d1:number <- merge 3
  foo a
]
def foo a:d1:_elem -> b:number [
  local-scope
  load-ingredients
  get e, x:offset  # unknown variable in a 'get', which does some extra checking
  return 34
]
container d1:_elem [
  x:_elem
]
+error: foo: unknown type for 'e' (check the name for typos)
+error: specializing foo: missing type for 'e'
# and it doesn't crash

:(scenarios transform)
:(scenario specialize_recursive_shape_shifting_recipe)
def main [
  1:number <- copy 34
  2:number <- foo 1:number
]
def foo x:_elem -> y:number [
  local-scope
  load-ingredients
  {
    break
    y:number <- foo x
  }
  return y
]
+transform: new specialization: foo_2
# transform terminates

:(scenarios run)
:(scenario specialize_most_similar_variant)
def main [
  1:address:number <- new number:type
  2:number <- foo 1:address:number
]
def foo x:_elem -> y:number [
  local-scope
  load-ingredients
  return 34
]
def foo x:address:_elem -> y:number [
  local-scope
  load-ingredients
  return 35
]
+mem: storing 35 in location 2

:(scenario specialize_most_similar_variant_2)
# version with headers padded with lots of unrelated concrete types
def main [
  1:number <- copy 23
  2:address:array:number <- copy 0
  3:number <- foo 2:address:array:number, 1:number
]
# variant with concrete type
def foo dummy:address:array:number, x:number -> y:number, dummy:address:array:number [
  local-scope
  load-ingredients
  return 34
]
# shape-shifting variant
def foo dummy:address:array:number, x:_elem -> y:number, dummy:address:array:number [
  local-scope
  load-ingredients
  return 35
]
# prefer the concrete variant
+mem: storing 34 in location 3

:(scenario specialize_most_similar_variant_3)
def main [
  1:address:array:character <- new [abc]
  foo 1:address:array:character
]
def foo x:address:array:character [
  2:number <- copy 34
]
def foo x:address:_elem [
  2:number <- copy 35
]
# make sure the more precise version was used
+mem: storing 34 in location 2

:(scenario specialize_literal_as_number)
def main [
  1:number <- foo 23
]
def foo x:_elem -> y:number [
  local-scope
  load-ingredients
  return 34
]
def foo x:character -> y:number [
  local-scope
  load-ingredients
  return 35
]
+mem: storing 34 in location 1

:(scenario specialize_literal_as_number_2)
# version calling with literal
def main [
  1:number <- foo 0
]
# variant with concrete type
def foo x:number -> y:number [
  local-scope
  load-ingredients
  return 34
]
# shape-shifting variant
def foo x:address:_elem -> y:number [
  local-scope
  load-ingredients
  return 35
]
# prefer the concrete variant, ignore concrete types in scoring the shape-shifting variant
+mem: storing 34 in location 1

:(scenario specialize_literal_as_address)
def main [
  1:number <- foo 0
]
# variant with concrete address type
def foo x:address:number -> y:number [
  local-scope
  load-ingredients
  return 34
]
# shape-shifting variant
def foo x:address:_elem -> y:number [
  local-scope
  load-ingredients
  return 35
]
# prefer the concrete variant, ignore concrete types in scoring the shape-shifting variant
+mem: storing 34 in location 1

:(scenario missing_type_during_specialization)
% Hide_errors = true;
# define a shape-shifting recipe
def foo a:_elem [
]
# define a container with field 'z'
container foo2 [
  z:number
]
def main [
  local-scope
  x:foo2 <- merge 34
  y:number <- get x, z:offse  # typo in 'offset'
  # define a variable with the same name 'z'
  z:number <- copy 34
  # trigger specialization of the shape-shifting recipe
  foo z
]
# shouldn't crash

:(scenario missing_type_during_specialization2)
% Hide_errors = true;
# define a shape-shifting recipe
def foo a:_elem [
]
# define a container with field 'z'
container foo2 [
  z:number
]
def main [
  local-scope
  x:foo2 <- merge 34
  y:number <- get x, z:offse  # typo in 'offset'
  # define a variable with the same name 'z'
  z:address:number <- copy 34
  # trigger specialization of the shape-shifting recipe
  foo *z
]
# shouldn't crash

:(scenario tangle_shape_shifting_recipe)
# shape-shifting recipe
def foo a:_elem [
  local-scope
  load-ingredients
  <label1>
]
# tangle some code that refers to the type ingredient
after <label1> [
  b:_elem <- copy a
]
# trigger specialization
def main [
  local-scope
  foo 34
]
$error: 0

:(scenario shape_shifting_recipe_coexists_with_primitive)
# recipe overloading a primitive with a generic type
def add a:address:foo:_elem [
  assert 0, [should not get here]
]

def main [
  # call primitive add with literal 0
  add 0, 0
]
$error: 0
