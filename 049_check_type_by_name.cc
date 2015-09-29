//: Some simple sanity checks for types, and also attempts to guess them where
//: they aren't provided.
//:
//: You still have to provide the full type the first time you mention a
//: variable in a recipe. You have to explicitly name :offset and :variant
//: every single time. You can't use the same name with multiple types in a
//: single recipe.

:(scenario transform_types_warns_on_reusing_name_with_different_type)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1
  x:boolean <- copy 1
]
+warn: x used with multiple types in main

:(after "int main")
  Transform.push_back(transform_types);

:(code)
void transform_types(const recipe_ordinal r) {
  map<string, vector<type_ordinal> > metadata;
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in) {
      deduce_missing_type(metadata, inst.ingredients.at(in));
      check_metadata(metadata, inst.ingredients.at(in), r);
    }
    for (long long int out = 0; out < SIZE(inst.products); ++out) {
      deduce_missing_type(metadata, inst.products.at(out));
      check_metadata(metadata, inst.products.at(out), r);
    }
  }
}

void check_metadata(map<string, vector<type_ordinal> >& metadata, const reagent& x, const recipe_ordinal r) {
  if (is_literal(x)) return;
  if (is_raw(x)) return;
  // if you use raw locations you're probably doing something unsafe
  if (is_integer(x.name)) return;
  if (x.types.empty()) return;  // will throw a more precise warning elsewhere
  if (metadata.find(x.name) == metadata.end())
    metadata[x.name] = x.types;
  if (metadata[x.name] != x.types)
    raise << x.name << " used with multiple types in " << Recipe[r].name << '\n' << end();
}

:(scenario transform_types_fills_in_missing_types)
recipe main [
  x:number <- copy 1
  y:number <- add x, 1
]

:(code)
void deduce_missing_type(map<string, vector<type_ordinal> >& metadata, reagent& x) {
  if (!x.types.empty()) return;
  if (metadata.find(x.name) == metadata.end()) return;
  copy(metadata[x.name].begin(), metadata[x.name].end(), inserter(x.types, x.types.begin()));
  assert(x.properties.at(0).second.empty());
  x.properties.at(0).second.resize(metadata[x.name].size());
  x.properties.push_back(pair<string, vector<string> >("as-before", vector<string>()));
}

:(scenario transform_types_fills_in_missing_types_in_product)
recipe main [
  x:number <- copy 1
  x <- copy 2
]

:(scenario transform_types_fills_in_missing_types_in_product_and_ingredient)
recipe main [
  x:number <- copy 1
  x <- add x, 1
]
+mem: storing 2 in location 1

:(scenario transform_warns_on_missing_types_in_first_mention)
% Hide_warnings = true;
recipe main [
  x <- copy 1
  x:number <- copy 2
]
+warn: missing type in 'x <- copy 1'

:(scenario typo_in_address_type_warns)
% Hide_warnings = true;
recipe main [
  y:address:charcter <- new character:type
  *y <- copy 67
]
+warn: unknown type: charcter
