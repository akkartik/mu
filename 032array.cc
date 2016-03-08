//: Arrays contain a variable number of elements of the same type. Their value
//: starts with the length of the array.
//:
//: You can create arrays of containers, but containers can only contain
//: elements of a fixed size, so you can't create containers containing arrays.
//: Create containers containing addresses to arrays instead.

//: You can create arrays using 'create-array'.
:(scenario create_array)
def main [
  # create an array occupying locations 1 (for the size) and 2-4 (for the elements)
  1:array:number:3 <- create-array
]
+run: creating array of size 4

:(before "End Primitive Recipe Declarations")
CREATE_ARRAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "create-array", CREATE_ARRAY);
:(before "End Primitive Recipe Checks")
case CREATE_ARRAY: {
  if (inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'create-array' needs one product and no ingredients but got '" << to_string(inst) << '\n' << end();
    break;
  }
  reagent product = inst.products.at(0);
  canonize_type(product);
  if (!is_mu_array(product)) {
    raise << maybe(get(Recipe, r).name) << "'create-array' cannot create non-array " << product.original_string << '\n' << end();
    break;
  }
  if (!product.type->right) {
    raise << maybe(get(Recipe, r).name) << "create array of what? " << to_string(inst) << '\n' << end();
    break;
  }
  // 'create-array' will need to check properties rather than types
  if (!product.type->right->right) {
    raise << maybe(get(Recipe, r).name) << "create array of what size? " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_integer(product.type->right->right->name)) {
    raise << maybe(get(Recipe, r).name) << "'create-array' product should specify size of array after its element type, but got " << product.type->right->right->name << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CREATE_ARRAY: {
  reagent product = current_instruction().products.at(0);
  canonize(product);
  long long int base_address = product.value;
  long long int array_size = to_integer(product.type->right->right->name);
  // initialize array size, so that size_of will work
  put(Memory, base_address, array_size);  // in array elements
  long long int size = size_of(product);  // in locations
  trace(9998, "run") << "creating array of size " << size << '\n' << end();
  // initialize array
  for (long long int i = 1; i <= size_of(product); ++i) {
    put(Memory, base_address+i, 0);
  }
  // dummy product; doesn't actually do anything
  products.resize(1);
  products.at(0).push_back(array_size);
  break;
}

:(scenario copy_array)
# Arrays can be copied around with a single instruction just like numbers,
# no matter how large they are.
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:array:number <- copy 1:array:number:3
]
+mem: storing 3 in location 5
+mem: storing 14 in location 6
+mem: storing 15 in location 7
+mem: storing 16 in location 8

:(scenario copy_array_indirect)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:array:number <- copy 1/unsafe
  6:array:number <- copy *5:address:array:number
]
+mem: storing 3 in location 6
+mem: storing 14 in location 7
+mem: storing 15 in location 8
+mem: storing 16 in location 9

:(scenario stash_array)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  stash [foo:], 1:array:number:3
]
+app: foo: 3 14 15 16

//: disable the size mismatch check since the destination array need not be initialized
:(before "End size_mismatch(x) Cases")
if (x.type && x.type->value == get(Type_ordinal, "array")) return false;
:(before "End size_of(reagent) Cases")
if (r.type && r.type->value == get(Type_ordinal, "array")) {
  if (!r.type->right) {
    raise << maybe(current_recipe_name()) << "'" << r.original_string << "' is an array of what?\n" << end();
    return 1;
  }
  return 1 + get_or_insert(Memory, r.value)*size_of(array_element(r.type));
}

//: arrays are disallowed inside containers unless their length is fixed in
//: advance

:(scenario container_contains_array)
container foo [
  x:array:number:3
]
$error: 0

:(scenario container_disallows_dynamic_array_element)
% Hide_errors = true;
container foo [
  x:array:number
]
+error: container 'foo' cannot determine size of element x

:(before "End Load Container Element Definition")
{
  const type_tree* type = info.elements.back().type;
  if (type->name == "array") {
    if (!type->right) {
      raise << "container '" << name << "' doesn't specify type of array elements for " << info.elements.back().name << '\n' << end();
      continue;
    }
    if (!type->right->right) {  // array has no length
      raise << "container '" << name << "' cannot determine size of element " << info.elements.back().name << '\n' << end();
      continue;
    }
  }
}

//:: To access elements of an array, use 'index'

:(scenario index)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- index 1:array:number:3, 0
]
+mem: storing 14 in location 5

:(scenario index_direct_offset)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 0
  6:number <- index 1:array:number, 5:number
]
+mem: storing 14 in location 6

:(before "End Primitive Recipe Declarations")
INDEX,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "index", INDEX);
:(before "End Primitive Recipe Checks")
case INDEX: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'index' expects exactly 2 ingredients in '" << to_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  canonize_type(base);
  if (!is_mu_array(base)) {
    raise << maybe(get(Recipe, r).name) << "'index' on a non-array " << base.original_string << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;
  reagent product = inst.products.at(0);
  canonize_type(product);
  reagent element;
  element.type = new type_tree(*array_element(base.type));
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'index' on " << base.original_string << " can't be saved in " << product.original_string << "; type should be " << names_to_string_without_quotes(element.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case INDEX: {
  reagent base = current_instruction().ingredients.at(0);
  canonize(base);
  long long int base_address = base.value;
  trace(9998, "run") << "base address is " << base_address << end();
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  reagent offset = current_instruction().ingredients.at(1);
  canonize(offset);
  vector<double> offset_val(read_memory(offset));
  type_tree* element_type = array_element(base.type);
  if (offset_val.at(0) < 0 || offset_val.at(0) >= get_or_insert(Memory, base_address)) {
    raise << maybe(current_recipe_name()) << "invalid index " << no_scientific(offset_val.at(0)) << '\n' << end();
    break;
  }
  long long int src = base_address + 1 + offset_val.at(0)*size_of(element_type);
  trace(9998, "run") << "address to copy is " << src << end();
  trace(9998, "run") << "its type is " << get(Type, element_type->value).name << end();
  reagent tmp;
  tmp.set_value(src);
  tmp.type = new type_tree(*element_type);
  products.push_back(read_memory(tmp));
  break;
}

:(code)
type_tree* array_element(const type_tree* type) {
  if (type->right->left) {
    assert(!type->right->left->left);
    return type->right->left;
  }
  return type->right;
}

:(scenario index_indirect)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:array:number <- copy 1/unsafe
  6:number <- index *5:address:array:number, 1
]
+mem: storing 15 in location 6

:(scenario index_out_of_bounds)
% Hide_errors = true;
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  index *8:address:array:point, 4  # less than size of array in locations, but larger than its length in elements
]
+error: main: invalid index 4

:(scenario index_out_of_bounds_2)
% Hide_errors = true;
def main [
  1:array:point:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  index *8:address:array:point, -1
]
+error: main: invalid index -1

:(scenario index_product_type_mismatch)
% Hide_errors = true;
def main [
  1:array:point:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  9:number <- index *8:address:array:point, 0
]
+error: main: 'index' on *8:address:array:point can't be saved in 9:number; type should be point

//: we might want to call 'index' without saving the results, say in a sandbox

:(scenario index_without_product)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  index 1:array:number:3, 0
]
# just don't die

//:: To write to elements of containers, you need their address.

:(scenario index_address)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:number <- index-address 1:array:number, 0
]
+mem: storing 2 in location 5

:(before "End Primitive Recipe Declarations")
INDEX_ADDRESS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "index-address", INDEX_ADDRESS);
:(before "End Primitive Recipe Checks")
case INDEX_ADDRESS: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'index-address' expects exactly 2 ingredients in '" << to_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  canonize_type(base);
  if (!is_mu_array(base)) {
    raise << maybe(get(Recipe, r).name) << "'index-address' on a non-array " << base.original_string << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;
  reagent product = inst.products.at(0);
  canonize_type(product);
  reagent element;
  element.type = new type_tree("address", get(Type_ordinal, "address"),
                               new type_tree(*array_element(base.type)));
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'index' on " << base.original_string << " can't be saved in " << product.original_string << "; type should be " << names_to_string_without_quotes(element.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case INDEX_ADDRESS: {
  reagent base = current_instruction().ingredients.at(0);
  canonize(base);
  long long int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  reagent offset = current_instruction().ingredients.at(1);
  canonize(offset);
  vector<double> offset_val(read_memory(offset));
  type_tree* element_type = array_element(base.type);
  if (offset_val.at(0) < 0 || offset_val.at(0) >= get_or_insert(Memory, base_address)) {
    raise << maybe(current_recipe_name()) << "invalid index " << no_scientific(offset_val.at(0)) << '\n' << end();
    break;
  }
  long long int result = base_address + 1 + offset_val.at(0)*size_of(element_type);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario index_address_out_of_bounds)
% Hide_errors = true;
def main [
  1:array:point:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  index-address *8:address:array:point, 4  # less than size of array in locations, but larger than its length in elements
]
+error: main: invalid index 4

:(scenario index_address_out_of_bounds_2)
% Hide_errors = true;
def main [
  1:array:point:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  index-address *8:address:array:point, -1
]
+error: main: invalid index -1

:(scenario index_address_product_type_mismatch)
% Hide_errors = true;
def main [
  1:array:point:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1/unsafe
  9:address:number <- index-address *8:address:array:point, 0
]
+error: main: 'index' on *8:address:array:point can't be saved in 9:address:number; type should be (address point)

//:: compute the length of an array

:(scenario array_length)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- length 1:array:number:3
]
+mem: storing 3 in location 5

:(before "End Primitive Recipe Declarations")
LENGTH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "length", LENGTH);
:(before "End Primitive Recipe Checks")
case LENGTH: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'length' expects exactly 2 ingredients in '" << to_string(inst) << "'\n" << end();
    break;
  }
  reagent x = inst.ingredients.at(0);
  canonize_type(x);
  if (!is_mu_array(x)) {
    raise << "tried to calculate length of non-array " << x.original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case LENGTH: {
  reagent x = current_instruction().ingredients.at(0);
  canonize(x);
  if (x.value == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  products.resize(1);
  products.at(0).push_back(get_or_insert(Memory, x.value));
  break;
}

//: optimization: none of the instructions in this layer use 'ingredients' so
//: stop copying potentially huge arrays into it.
:(before "End should_copy_ingredients Special-cases")
recipe_ordinal r = current_instruction().operation;
if (r == CREATE_ARRAY || r == INDEX || r == INDEX_ADDRESS || r == LENGTH)
  return false;

//: a particularly common array type is the string, or address:array:character
:(code)
bool is_mu_string(const reagent& x) {
  return x.type
    && x.type->value == get(Type_ordinal, "address")
    && x.type->right
    && x.type->right->value == get(Type_ordinal, "shared")
    && x.type->right->right
    && x.type->right->right->value == get(Type_ordinal, "array")
    && x.type->right->right->right
    && x.type->right->right->right->value == get(Type_ordinal, "character")
    && x.type->right->right->right->right == NULL;
}
