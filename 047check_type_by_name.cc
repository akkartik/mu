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
  x:number <- copy 1
  x:boolean <- copy 1
]
+error: main: 'x' used with multiple types

:(after "Begin Instruction Modifying Transforms")
Transform.push_back(check_or_set_types_by_name);  // idempotent

:(code)
void check_or_set_types_by_name(const recipe_ordinal r) {
  trace(9991, "transform") << "--- deduce types for recipe " << get(Recipe, r).name << end();
  recipe& caller = get(Recipe, r);
  set<reagent> known;
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    for (int in = 0; in < SIZE(inst.ingredients); ++in) {
      deduce_missing_type(known, inst.ingredients.at(in));
      check_type(known, inst.ingredients.at(in), caller);
    }
    for (int out = 0; out < SIZE(inst.products); ++out) {
      deduce_missing_type(known, inst.products.at(out));
      check_type(known, inst.products.at(out), caller);
    }
  }
}

void deduce_missing_type(set<reagent>& known, reagent& x) {
  if (x.type) return;
  if (known.find(x) == known.end()) return;
  x.type = new type_tree(*known.find(x)->type);
  trace(9992, "transform") << x.name << " <= " << names_to_string(x.type) << end();
}

void check_type(set<reagent>& known, const reagent& x, const recipe& caller) {
  if (is_literal(x)) return;
  if (is_integer(x.name)) return;  // if you use raw locations you're probably doing something unsafe
  if (!x.type) return;  // might get filled in by other logic later
  if (known.find(x) == known.end()) {
    trace(9992, "transform") << x.name << " => " << names_to_string(x.type) << end();
    known.insert(x);
  }
  if (!types_strictly_match(known.find(x)->type, x.type)) {
    raise << maybe(caller.name) << "'" << x.name << "' used with multiple types\n" << end();
    return;
  }
  if (x.type->name == "array") {
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
  x:number <- copy 1
  y:number <- add x, 1
]

:(scenario transform_fills_in_missing_types_in_product)
def main [
  x:number <- copy 1
  x <- copy 2
]

:(scenario transform_fills_in_missing_types_in_product_and_ingredient)
def main [
  x:number <- copy 1
  x <- add x, 1
]
+mem: storing 2 in location 1

:(scenario transform_fails_on_missing_types_in_first_mention)
% Hide_errors = true;
def main [
  x <- copy 1
  x:number <- copy 2
]
+error: main: missing type for 'x' in 'x <- copy 1'

:(scenario typo_in_address_type_fails)
% Hide_errors = true;
def main [
  y:address:charcter <- new character:type
  *y <- copy 67
]
+error: main: unknown type charcter in 'y:address:charcter <- new character:type'

:(scenario array_type_without_size_fails)
% Hide_errors = true;
def main [
  x:array:number <- merge 2, 12, 13
]
+error: main can't determine the size of array variable 'x'. Either allocate it separately and make the type of 'x' an address, or specify the length of the array in the type of 'x'.

:(scenarios transform)
:(scenario transform_checks_types_of_identical_reagents_in_multiple_spaces)
def foo [  # dummy
]
def main [
  local-scope
  0:address:array:location/names:foo <- copy 0  # specify surrounding space
  x:boolean <- copy 1/true
  x:number/space:1 <- copy 34
  x/space:1 <- copy 35
]
$error: 0
