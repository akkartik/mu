//: Some simple sanity checks for types, and also attempts to guess them where
//: they aren't provided.
//:
//: You still have to provide the full type the first time you mention a
//: variable in a recipe. You have to explicitly name :offset and :variant
//: every single time. You can't use the same name with multiple types in a
//: single recipe.

:(scenario transform_fails_on_reusing_name_with_different_type)
% Hide_errors = true;
recipe main [
  x:number <- copy 1
  x:boolean <- copy 1
]
+error: main: x used with multiple types

:(after "Begin Instruction Modifying Transforms")
Transform.push_back(check_or_set_types_by_name);  // idempotent

:(code)
void check_or_set_types_by_name(const recipe_ordinal r) {
  trace(9991, "transform") << "--- deduce types for recipe " << get(Recipe, r).name << end();
//?   cerr << "--- deduce types for recipe " << get(Recipe, r).name << '\n';
  map<string, type_tree*> type;
  map<string, string_tree*> type_name;
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in) {
      deduce_missing_type(type, type_name, inst.ingredients.at(in));
      check_type(type, type_name, inst.ingredients.at(in), r);
    }
    for (long long int out = 0; out < SIZE(inst.products); ++out) {
      deduce_missing_type(type, type_name, inst.products.at(out));
      check_type(type, type_name, inst.products.at(out), r);
    }
  }
}

void deduce_missing_type(map<string, type_tree*>& type, map<string, string_tree*>& type_name, reagent& x) {
  if (x.type) return;
  if (!contains_key(type, x.name)) return;
  x.type = new type_tree(*type[x.name]);
  trace(9992, "transform") << x.name << " <= " << to_string(x.type) << end();
  assert(!x.properties.at(0).second);
  x.properties.at(0).second = new string_tree(*type_name[x.name]);
}

void check_type(map<string, type_tree*>& type, map<string, string_tree*>& type_name, const reagent& x, const recipe_ordinal r) {
  if (is_literal(x)) return;
  if (is_integer(x.name)) return;  // if you use raw locations you're probably doing something unsafe
  if (!x.type) return;  // might get filled in by other logic later
  if (!contains_key(type, x.name)) {
    trace(9992, "transform") << x.name << " => " << to_string(x.type) << end();
    put(type, x.name, x.type);
  }
  if (!contains_key(type_name, x.name))
    put(type_name, x.name, x.properties.at(0).second);
  if (!types_strictly_match(type[x.name], x.type)) {
    raise_error << maybe(get(Recipe, r).name) << x.name << " used with multiple types\n" << end();
    return;
  }
  if (type_name[x.name]->value == "array") {
    if (!type_name[x.name]->right) {
      raise_error << maybe(get(Recipe, r).name) << x.name << " can't be just an array. What is it an array of?\n" << end();
      return;
    }
    if (!type_name[x.name]->right->right) {
      raise_error << get(Recipe, r).name << " can't determine the size of array variable " << x.name << ". Either allocate it separately and make the type of " << x.name << " address:shared:..., or specify the length of the array in the type of " << x.name << ".\n" << end();
      return;
    }
  }
}

:(scenario transform_fills_in_missing_types)
recipe main [
  x:number <- copy 1
  y:number <- add x, 1
]

:(scenario transform_fills_in_missing_types_in_product)
recipe main [
  x:number <- copy 1
  x <- copy 2
]

:(scenario transform_fills_in_missing_types_in_product_and_ingredient)
recipe main [
  x:number <- copy 1
  x <- add x, 1
]
+mem: storing 2 in location 1

:(scenario transform_fails_on_missing_types_in_first_mention)
% Hide_errors = true;
recipe main [
  x <- copy 1
  x:number <- copy 2
]
+error: main: missing type for x in 'x <- copy 1'

:(scenario typo_in_address_type_fails)
% Hide_errors = true;
recipe main [
  y:address:shared:charcter <- new character:type
  *y <- copy 67
]
+error: main: unknown type charcter in 'y:address:shared:charcter <- new character:type'

:(scenario array_type_without_size_fails)
% Hide_errors = true;
recipe main [
  x:array:number <- merge 2, 12, 13
]
+error: main can't determine the size of array variable x. Either allocate it separately and make the type of x address:shared:..., or specify the length of the array in the type of x.
