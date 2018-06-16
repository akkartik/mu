//: Some simple sanity checks for types, and also attempts to guess them where
//: they aren't provided.
//:
//: You still have to provide the full type the first time you mention a
//: variable in a recipe. You have to explicitly name :offset and :variant
//: every single time. You can't use the same name with multiple types in a
//: single recipe.

:(scenario transform_fails_on_reusing_name_with_different_type)
% Hide_errors = true;
def main [
  x:num <- copy 1
  x:bool <- copy 1
]
+error: main: 'x' used with multiple types

:(after "Transform.push_back(expand_type_abbreviations)")
Transform.push_back(check_or_set_types_by_name);  // idempotent

:(code)
void check_or_set_types_by_name(const recipe_ordinal r) {
  trace(9991, "transform") << "--- deduce types for recipe " << get(Recipe, r).name << end();
  recipe& caller = get(Recipe, r);
  set<reagent> known;
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    instruction& inst = caller.steps.at(i);
    for (int in = 0;  in < SIZE(inst.ingredients);  ++in) {
      deduce_missing_type(known, inst.ingredients.at(in), caller);
      check_type(known, inst.ingredients.at(in), caller);
    }
    for (int out = 0;  out < SIZE(inst.products);  ++out) {
      deduce_missing_type(known, inst.products.at(out), caller);
      check_type(known, inst.products.at(out), caller);
    }
  }
}

void deduce_missing_type(set<reagent>& known, reagent& x, const recipe& caller) {
  // Deduce Missing Type(x, caller)
  if (x.type) return;
  if (is_jump_target(x.name)) {
    x.type = new type_tree("label");
    return;
  }
  if (known.find(x) == known.end()) return;
  const reagent& exemplar = *known.find(x);
  x.type = new type_tree(*exemplar.type);
  trace(9992, "transform") << x.name << " <= " << names_to_string(x.type) << end();
  // spaces are special; their type includes their /names property
  if (is_mu_space(x) && !has_property(x, "names")) {
    if (!has_property(exemplar, "names")) {
      raise << maybe(caller.name) << "missing /names property for space variable '" << exemplar.name << "'\n" << end();
      return;
    }
    x.properties.push_back(pair<string, string_tree*>("names", new string_tree(*property(exemplar, "names"))));
  }
}

void check_type(set<reagent>& known, const reagent& x, const recipe& caller) {
  if (is_literal(x)) return;
  if (is_integer(x.name)) return;  // if you use raw locations you're probably doing something unsafe
  if (!x.type) return;  // might get filled in by other logic later
  if (is_jump_target(x.name)) {
    if (!x.type->atom || x.type->name != "label")
      raise << maybe(caller.name) << "non-label '" << x.name << "' must begin with a letter\n" << end();
    return;
  }
  if (known.find(x) == known.end()) {
    trace(9992, "transform") << x.name << " => " << names_to_string(x.type) << end();
    known.insert(x);
  }
  if (!types_strictly_match(known.find(x)->type, x.type)) {
    raise << maybe(caller.name) << "'" << x.name << "' used with multiple types\n" << end();
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

:(scenario transform_fills_in_missing_types)
def main [
  x:num <- copy 10
  y:num <- add x, 1
]
# x is in location 2, y in location 3
+mem: storing 11 in location 3

:(scenario transform_fills_in_missing_types_in_product)
def main [
  x:num <- copy 10
  x <- copy 11
]
# x is in location 2
+mem: storing 11 in location 2

:(scenario transform_fills_in_missing_types_in_product_and_ingredient)
def main [
  x:num <- copy 10
  x <- add x, 1
]
# x is in location 1
+mem: storing 11 in location 2

:(scenario transform_fills_in_missing_label_type)
def main [
  jump +target
  1:num <- copy 0
  +target
]
-mem: storing 0 in location 1

:(scenario transform_fails_on_missing_types_in_first_mention)
% Hide_errors = true;
def main [
  x <- copy 1
  x:num <- copy 2
]
+error: main: missing type for 'x' in 'x <- copy 1'

:(scenario transform_fails_on_wrong_type_for_label)
% Hide_errors = true;
def main [
  +foo:num <- copy 34
]
+error: main: non-label '+foo' must begin with a letter

:(scenario typo_in_address_type_fails)
% Hide_errors = true;
def main [
  y:&:charcter <- new character:type
  *y <- copy 67
]
+error: main: unknown type charcter in 'y:&:charcter <- new character:type'

:(scenario array_type_without_size_fails)
% Hide_errors = true;
def main [
  x:@:num <- merge 2, 12, 13
]
+error: main can't determine the size of array variable 'x'. Either allocate it separately and make the type of 'x' an address, or specify the length of the array in the type of 'x'.

:(scenarios transform)
:(scenario transform_checks_types_of_identical_reagents_in_multiple_spaces)
def foo [  # dummy
]
def main [
  local-scope
  0:space/names:foo <- copy 0  # specify surrounding space
  x:bool <- copy 1/true
  x:num/space:1 <- copy 34
  x/space:1 <- copy 35
]
$error: 0

:(scenario transform_handles_empty_reagents)
% Hide_errors = true;
def main [
  add *
]
+error: illegal name '*'
# no crash
