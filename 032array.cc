//: Arrays contain a variable number of elements of the same type. Their value
//: starts with the length of the array.
//:
//: You can create arrays of containers, but containers can only contain
//: elements of a fixed size, so you can't create containers containing arrays.
//: Create containers containing addresses to arrays instead.

:(scenario copy_array)
# Arrays can be copied around with a single instruction just like integers,
# no matter how large they are.
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:array:integer <- copy 1:array:integer
]
+run: instruction main/4
+run: ingredient 0 is 1
+mem: location 1 is 3
+mem: location 2 is 14
+mem: location 3 is 15
+mem: location 4 is 16
+mem: storing 3 in location 5
+mem: storing 14 in location 6
+mem: storing 15 in location 7
+mem: storing 16 in location 8

:(scenario copy_array_indirect)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:address:array:integer <- copy 1:literal
  6:array:integer <- copy 5:address:array:integer/deref
]
+run: instruction main/5
+run: ingredient 0 is 5
+mem: location 1 is 3
+mem: location 2 is 14
+mem: location 3 is 15
+mem: location 4 is 16
+mem: storing 3 in location 6
+mem: storing 14 in location 7
+mem: storing 15 in location 8
+mem: storing 16 in location 9

//: disable the size mismatch check since the destination array need not be initialized
:(replace "if (size_of(x) != data.size())" following "void write_memory(reagent x, vector<long long int> data)")
if (x.types.at(0) != Type_number["array"] && size_of(x) != data.size())
:(after "size_t size_of(const reagent& r)")
  if (r.types.at(0) == Type_number["array"]) {
    assert(r.types.size() > 1);
    // skip the 'array' type to get at the element type
    return 1 + value(Memory[r.value])*size_of(array_element(r.types));
  }

//:: To access elements of an array, use 'index'

:(scenario index)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:integer <- index 1:array:integer, 0:literal
]
+run: instruction main/4
+run: address to copy is 2
+run: its type is 1
+mem: location 2 is 14
+run: product 0 is 5
+mem: storing 14 in location 5

:(scenario index_direct_offset)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:integer <- copy 0:literal
  6:integer <- index 1:array:integer, 5:integer
]
+run: instruction main/5
+run: address to copy is 2
+run: its type is 1
+mem: location 2 is 14
+run: product 0 is 6
+mem: storing 14 in location 6

:(before "End Primitive Recipe Declarations")
INDEX,
:(before "End Primitive Recipe Numbers")
Recipe_number["index"] = INDEX;
:(before "End Primitive Recipe Implementations")
case INDEX: {
//?   if (Trace_stream) Trace_stream->dump_layer = "run"; //? 1
  reagent base = canonize(current_instruction().ingredients.at(0));
//?   trace("run") << "ingredient 0 after canonize: " << base.to_string(); //? 1
  assert(!is_negative(base.value));
  index_t base_address = value(base.value);
  assert(base.types.at(0) == Type_number["array"]);
  reagent offset = canonize(current_instruction().ingredients.at(1));
//?   trace("run") << "ingredient 1 after canonize: " << offset.to_string(); //? 1
  vector<long long int> offset_val(read_memory(offset));
  vector<type_number> element_type = array_element(base.types);
//?   trace("run") << "offset: " << offset_val.at(0); //? 1
//?   trace("run") << "size of elements: " << size_of(element_type); //? 1
  assert(offset_val.size() == 1);  // scalar
  index_t src = base_address + 1 + value(offset_val.at(0))*size_of(element_type);
  trace("run") << "address to copy is " << src;
  trace("run") << "its type is " << element_type.at(0);
  reagent tmp;
  tmp.set_value(mu_integer(src));
  copy(element_type.begin(), element_type.end(), inserter(tmp.types, tmp.types.begin()));
  products.push_back(read_memory(tmp));
  break;
}

:(code)
vector<type_number> array_element(const vector<type_number>& types) {
  return vector<type_number>(++types.begin(), types.end());
}

:(scenario index_address)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:integer <- index-address 1:array:integer, 0:literal
]
+run: instruction main/4
+mem: storing 2 in location 5

//:: To write to elements of containers, you need their address.

:(scenario index_indirect)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 14:literal
  3:integer <- copy 15:literal
  4:integer <- copy 16:literal
  5:address:array:integer <- copy 1:literal
  6:integer <- index 5:address:array:integer/deref, 1:literal
]
+run: instruction main/5
+mem: storing 15 in location 6

:(before "End Primitive Recipe Declarations")
INDEX_ADDRESS,
:(before "End Primitive Recipe Numbers")
Recipe_number["index-address"] = INDEX_ADDRESS;
:(before "End Primitive Recipe Implementations")
case INDEX_ADDRESS: {
  reagent base = canonize(current_instruction().ingredients.at(0));
  assert(!is_negative(base.value));
  index_t base_address = value(base.value);
  assert(base.types.at(0) == Type_number["array"]);
  vector<long long int>& offset_val = ingredients.at(1);
  assert(offset_val.size() == 1);
  vector<type_number> element_type = array_element(base.types);
  index_t result = base_address + 1 + value(offset_val.at(0))*size_of(element_type);
  products.resize(1);
  products.at(0).push_back(mu_integer(result));  // address must be a positive integer
  break;
}
