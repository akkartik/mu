:(before "End Primitive Recipe Declarations")
TO_LOCATION_ARRAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "to-location-array", TO_LOCATION_ARRAY);
:(before "End Primitive Recipe Checks")
case TO_LOCATION_ARRAY: {
  const recipe& caller = get(Recipe, r);
  if (!is_shared_address_of_array_of_numbers(inst.products.at(0))) {
    raise << maybe(caller.name) << "product of 'to-location-array' has incorrect type: " << to_original_string(inst) << '\n' << end();
    break;
  }
  break;
}
:(code)
bool is_shared_address_of_array_of_numbers(reagent product) {
  canonize_type(product);
  if (!product.type || product.type->value != get(Type_ordinal, "address")) return false;
  drop_from_type(product, "address");
  if (!product.type || product.type->value != get(Type_ordinal, "shared")) return false;
  drop_from_type(product, "shared");
  if (!product.type || product.type->value != get(Type_ordinal, "array")) return false;
  drop_from_type(product, "array");
  if (!product.type || product.type->value != get(Type_ordinal, "number")) return false;
  return true;
}
:(before "End Primitive Recipe Implementations")
case TO_LOCATION_ARRAY: {
  int array_size = SIZE(ingredients.at(0));
  int allocation_size = array_size + /*refcount*/1 + /*length*/1;
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
