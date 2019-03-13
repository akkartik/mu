//: Some simple sanity checks for types, and also attempts to guess them where
//: they aren't provided.
//:
//: You still have to provide the full type the first time you mention a
//: variable in a recipe. You have to explicitly name :offset and :variant
//: every single time. You can't use the same name with multiple types in a
//: single recipe.

void test_transform_fails_on_reusing_name_with_different_type() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  x:num <- copy 1\n"
      "  x:bool <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: 'x' used with multiple types\n"
  );
}

//: we need surrounding-space info for type-checking variables in other spaces
:(after "Transform.push_back(collect_surrounding_spaces)")
Transform.push_back(check_or_set_types_by_name);  // idempotent

// Keep the name->type mapping for all recipes around for the entire
// transformation phase.
:(before "End Globals")
map<recipe_ordinal, set<reagent, name_lt> > Types_by_space;  // internal to transform; no need to snapshot
:(before "End Reset")
Types_by_space.clear();
:(before "End transform_all")
Types_by_space.clear();
:(before "End Types")
struct name_lt {
  bool operator()(const reagent& a, const reagent& b) const { return a.name < b.name; }
};

:(code)
void check_or_set_types_by_name(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(101, "transform") << "--- deduce types for recipe " << caller.name << end();
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    instruction& inst = caller.steps.at(i);
    for (int in = 0;  in < SIZE(inst.ingredients);  ++in)
      check_or_set_type(inst.ingredients.at(in), caller);
    for (int out = 0;  out < SIZE(inst.products);  ++out)
      check_or_set_type(inst.products.at(out), caller);
  }
}

void check_or_set_type(reagent& curr, const recipe& caller) {
  if (is_literal(curr)) return;
  if (is_integer(curr.name)) return;  // no type-checking for raw locations
  set<reagent, name_lt>& known_types = Types_by_space[owning_recipe(curr, caller.ordinal)];
  deduce_missing_type(known_types, curr, caller);
  check_type(known_types, curr, caller);
}

void deduce_missing_type(set<reagent, name_lt>& known_types, reagent& x, const recipe& caller) {
  // Deduce Missing Type(x, caller)
  if (x.type) return;
  if (is_jump_target(x.name)) {
    x.type = new type_tree("label");
    return;
  }
  if (known_types.find(x) == known_types.end()) return;
  const reagent& exemplar = *known_types.find(x);
  x.type = new type_tree(*exemplar.type);
  trace(102, "transform") << x.name << " <= " << names_to_string(x.type) << end();
  // spaces are special; their type includes their /names property
  if (is_mu_space(x) && !has_property(x, "names")) {
    if (!has_property(exemplar, "names")) {
      raise << maybe(caller.name) << "missing /names property for space variable '" << exemplar.name << "'\n" << end();
      return;
    }
    x.properties.push_back(pair<string, string_tree*>("names", new string_tree(*property(exemplar, "names"))));
  }
}

void check_type(set<reagent, name_lt>& known_types, const reagent& x, const recipe& caller) {
  if (is_literal(x)) return;
  if (!x.type) return;  // might get filled in by other logic later
  if (is_jump_target(x.name)) {
    if (!x.type->atom || x.type->name != "label")
      raise << maybe(caller.name) << "non-label '" << x.name << "' must begin with a letter\n" << end();
    return;
  }
  if (known_types.find(x) == known_types.end()) {
    trace(102, "transform") << x.name << " => " << names_to_string(x.type) << end();
    known_types.insert(x);
  }
  if (!types_strictly_match(known_types.find(x)->type, x.type)) {
    raise << maybe(caller.name) << "'" << x.name << "' used with multiple types\n" << end();
    raise << "  " << to_string(known_types.find(x)->type) << " vs " << to_string(x.type) << '\n' << end();
    return;
  }
  if (is_mu_array(x)) {
    if (!x.type->right) {
      raise << maybe(caller.name) << "'" << x.name << ": can't be just an array. What is it an array of?\n" << end();
      return;
    }
    if (!x.type->right->right) {
      raise << caller.name << " can't determine the size of array variable '" << x.name << "'. Either allocate it separately and make the type of '" << x.name << "' an address, or specify the length of the array in the type of '" << x.name << "'.\n" << end();
      return;
    }
  }
}

recipe_ordinal owning_recipe(const reagent& x, recipe_ordinal r) {
  for (int s = space_index(x); s > 0; --s) {
    if (!contains_key(Surrounding_space, r)) break;  // error raised elsewhere
    r = Surrounding_space[r];
  }
  return r;
}

void test_transform_fills_in_missing_types() {
  run(
      "def main [\n"
      "  x:num <- copy 11\n"
      "  y:num <- add x, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // x is in location 2, y in location 3
      "mem: storing 12 in location 3\n"
  );
}

void test_transform_fills_in_missing_types_in_product() {
  run(
      "def main [\n"
      "  x:num <- copy 11\n"
      "  x <- copy 12\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // x is in location 2
      "mem: storing 12 in location 2\n"
  );
}

void test_transform_fills_in_missing_types_in_product_and_ingredient() {
  run(
      "def main [\n"
      "  x:num <- copy 11\n"
      "  x <- add x, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // x is in location 2
      "mem: storing 12 in location 2\n"
  );
}

void test_transform_fills_in_missing_label_type() {
  run(
      "def main [\n"
      "  jump +target\n"
      "  1:num <- copy 0\n"
      "  +target\n"
      "]\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 0 in location 1");
}

void test_transform_fails_on_missing_types_in_first_mention() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  x <- copy 1\n"
      "  x:num <- copy 2\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: missing type for 'x' in 'x <- copy 1'\n"
  );
}

void test_transform_fails_on_wrong_type_for_label() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  +foo:num <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: non-label '+foo' must begin with a letter\n"
  );
}

void test_typo_in_address_type_fails() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  y:&:charcter <- new character:type\n"
      "  *y <- copy 67\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: unknown type charcter in 'y:&:charcter <- new character:type'\n"
  );
}

void test_array_type_without_size_fails() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  x:@:num <- merge 2, 12, 13\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main can't determine the size of array variable 'x'. Either allocate it separately and make the type of 'x' an address, or specify the length of the array in the type of 'x'.\n"
  );
}

void test_transform_checks_types_of_identical_reagents_in_multiple_spaces() {
  transform(
      "def foo [\n"  // dummy function for names
      "]\n"
      "def main [\n"
      "  local-scope\n"
      "  0:space/names:foo <- copy null\n"  // specify surrounding space
      "  x:bool <- copy true\n"
      "  x:num/space:1 <- copy 34\n"
      "  x/space:1 <- copy 35\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_transform_handles_empty_reagents() {
  Hide_errors = true;
  transform(
      "def main [\n"
      "  add *\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: illegal name '*'\n"
  );
  // no crash
}

void test_transform_checks_types_in_surrounding_spaces() {
  Hide_errors = true;
  transform(
      // 'x' is a bool in foo's space
      "def foo [\n"
      "  local-scope\n"
      "  x:bool <- copy false\n"
      "  return default-space/names:foo\n"
      "]\n"
      // try to read 'x' as a num in foo's space
      "def main [\n"
      "  local-scope\n"
      "  0:space/names:foo <- foo\n"
      "  x:num/space:1 <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: 'x' used with multiple types\n"
  );
}
