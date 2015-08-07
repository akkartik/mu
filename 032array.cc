//: Arrays contain a variable number of elements of the same type. Their value
//: starts with the length of the array.
//:
//: You can create arrays of containers, but containers can only contain
//: elements of a fixed size, so you can't create containers containing arrays.
//: Create containers containing addresses to arrays instead.

//: Tests in this layer often explicitly setup memory before reading it as an
//: array. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid warnings.
:(scenario copy_array)
# Arrays can be copied around with a single instruction just like numbers,
# no matter how large they are.
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:array:number <- copy 1:array:number/raw  # unsafe
]
+mem: storing 3 in location 5
+mem: storing 14 in location 6
+mem: storing 15 in location 7
+mem: storing 16 in location 8

:(scenario copy_array_indirect)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:array:number <- copy 1
  6:array:number <- copy *5:address:array:number
]
+mem: storing 3 in location 6
+mem: storing 14 in location 7
+mem: storing 15 in location 8
+mem: storing 16 in location 9

//: disable the size mismatch check since the destination array need not be initialized
:(before "End size_mismatch(x) Cases")
if (x.types.at(0) == Type_ordinal["array"]) return false;
:(before "End size_of(reagent) Cases")
if (r.types.at(0) == Type_ordinal["array"]) {
  if (SIZE(r.types) == 1) {
    raise << current_recipe_name() << ": '" << r.original_string << "' is an array of what?\n" << end();
    return 1;
  }
  // skip the 'array' type to get at the element type
  return 1 + Memory[r.value]*size_of(array_element(r.types));
}

//:: To access elements of an array, use 'index'

:(scenario index)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- index 1:array:number/raw, 0  # unsafe
]
+mem: storing 14 in location 5

:(scenario index_direct_offset)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 0
  6:number <- index 1:array:number/raw, 5:number  # unsafe
]
+mem: storing 14 in location 6

:(before "End Primitive Recipe Declarations")
INDEX,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["index"] = INDEX;
:(before "End Primitive Recipe Implementations")
case INDEX: {
  if (SIZE(ingredients) != 2) {
    raise << current_recipe_name() << ": 'index' expects exactly 2 ingredients in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent base = canonize(current_instruction().ingredients.at(0));
  if (base.types.at(0) != Type_ordinal["array"]) {
    raise << current_recipe_name () << ": 'index' on a non-array " << base.original_string << '\n' << end();
    break;
  }
  long long int base_address = base.value;
  if (base_address == 0) {
    raise << current_recipe_name() << ": tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent offset = canonize(current_instruction().ingredients.at(1));
  vector<double> offset_val(read_memory(offset));
  vector<type_ordinal> element_type = array_element(base.types);
  if (offset_val.at(0) < 0 || offset_val.at(0) >= Memory[base_address]) {
    raise << current_recipe_name() << ": invalid index " << offset_val.at(0) << '\n' << end();
    break;
  }
  long long int src = base_address + 1 + offset_val.at(0)*size_of(element_type);
  trace(Primitive_recipe_depth, "run") << "address to copy is " << src << end();
  trace(Primitive_recipe_depth, "run") << "its type is " << Type[element_type.at(0)].name << end();
  reagent tmp;
  tmp.set_value(src);
  copy(element_type.begin(), element_type.end(), inserter(tmp.types, tmp.types.begin()));
  products.push_back(read_memory(tmp));
  break;
}

:(code)
vector<type_ordinal> array_element(const vector<type_ordinal>& types) {
  return vector<type_ordinal>(++types.begin(), types.end());
}

:(scenario index_indirect)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:array:number <- copy 1
  6:number <- index *5:address:array:number, 1
]
+mem: storing 15 in location 6

:(scenario index_out_of_bounds)
% Hide_warnings = true;
recipe main [
  1:number <- copy 3  # 3 points
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1
  index *8:address:array:point, 4  # less than size of array in locations, but larger than its length in elements
]
+warn: main: invalid index 4

:(scenario index_out_of_bounds2)
% Hide_warnings = true;
recipe main [
  1:number <- copy 3  # 3 points
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1
  index *8:address:array:point, -1
]
+warn: main: invalid index -1

//:: To write to elements of containers, you need their address.

:(scenario index_address)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- index-address 1:array:number/raw, 0  # unsafe
]
+mem: storing 2 in location 5

:(before "End Primitive Recipe Declarations")
INDEX_ADDRESS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["index-address"] = INDEX_ADDRESS;
:(before "End Primitive Recipe Implementations")
case INDEX_ADDRESS: {
  if (SIZE(ingredients) != 2) {
    raise << current_recipe_name() << ": 'index-address' expects exactly 2 ingredients in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent base = canonize(current_instruction().ingredients.at(0));
  if (base.types.at(0) != Type_ordinal["array"]) {
    raise << current_recipe_name () << ": 'index-address' on a non-array " << base.original_string << '\n' << end();
    break;
  }
  long long int base_address = base.value;
  if (base_address == 0) {
    raise << current_recipe_name() << ": tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent offset = canonize(current_instruction().ingredients.at(1));
  vector<double> offset_val(read_memory(offset));
  vector<type_ordinal> element_type = array_element(base.types);
  if (offset_val.at(0) < 0 || offset_val.at(0) >= Memory[base_address]) {
    raise << current_recipe_name() << ": invalid index " << offset_val.at(0) << '\n' << end();
    break;
  }
  long long int result = base_address + 1 + offset_val.at(0)*size_of(element_type);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario index_address_out_of_bounds)
% Hide_warnings = true;
recipe main [
  1:number <- copy 3  # 3 points
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1
  index-address *8:address:array:point, 4  # less than size of array in locations, but larger than its length in elements
]
+warn: main: invalid index 4

:(scenario index_address_out_of_bounds2)
% Hide_warnings = true;
recipe main [
  1:number <- copy 3  # 3 points
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- copy 14
  6:number <- copy 15
  7:number <- copy 16
  8:address:array:point <- copy 1
  index-address *8:address:array:point, -1
]
+warn: main: invalid index -1

//:: compute the length of an array

:(scenario array_length)
recipe main [
  1:number <- copy 3  # length
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:number <- length 1:array:number/raw  # unsafe
]
+mem: storing 3 in location 5

:(before "End Primitive Recipe Declarations")
LENGTH,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["length"] = LENGTH;
:(before "End Primitive Recipe Implementations")
case LENGTH: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'length' expects exactly 2 ingredients in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent x = canonize(current_instruction().ingredients.at(0));
  if (x.types.at(0) != Type_ordinal["array"]) {
    raise << "tried to calculate length of non-array " << x.original_string << '\n' << end();
    break;
  }
  if (x.value == 0) {
    raise << current_recipe_name() << ": tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  products.resize(1);
  products.at(0).push_back(Memory[x.value]);
  break;
}
