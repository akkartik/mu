:(before "End Primitive Recipe Declarations")
TO_LOCATION_ARRAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "to-location-array", TO_LOCATION_ARRAY);
:(before "End Primitive Recipe Checks")
case TO_LOCATION_ARRAY: {
  const recipe& caller = get(Recipe, r);
  if (!is_address_of_array_of_numbers(inst.products.at(0))) {
    raise << maybe(caller.name) << "product of 'to-location-array' has incorrect type: '" << inst.original_string << "'\n" << end();
    break;
  }
  break;
}
:(code)
bool is_address_of_array_of_numbers(reagent/*copy*/ x) {
  canonize_type(x);
  if (!is_compound_type_starting_with(x.type, "address")) return false;
  drop_from_type(x, "address");
  if (!is_compound_type_starting_with(x.type, "array")) return false;
  drop_from_type(x, "array");
  return x.type && x.type->atom && x.type->value == get(Type_ordinal, "number");
}
bool is_compound_type_starting_with(const type_tree* type, const string& expected_name) {
  if (!type) return false;
  if (type->atom) return false;
  if (!type->left->atom) return false;
  return type->left->value == get(Type_ordinal, expected_name);
}

:(before "End Primitive Recipe Implementations")
case TO_LOCATION_ARRAY: {
  int array_size = SIZE(ingredients.at(0));
  int allocation_size = array_size + /*refcount and length*/2;
  ensure_space(allocation_size);
  const int result = Current_routine->alloc;
  products.resize(1);
  products.at(0).push_back(result);
  // initialize array refcount
  put(Memory, result, 0);
  // initialize array length
  put(Memory, result+1, array_size);
  // now copy over data
  for (int i = 0; i < array_size; ++i)
    put(Memory, result+2+i, ingredients.at(0).at(i));
  break;
}
