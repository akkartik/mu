//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two integer elements.
type_number point = Type_number["point"] = Next_type_number++;
Type[point].size = 2;
Type[point].kind = container;
Type[point].name = "point";
vector<type_number> i;
i.push_back(integer);
Type[point].elements.push_back(i);
Type[point].elements.push_back(i);

//: Containers can be copied around with a single instruction just like
//: integers, no matter how large they are.

:(scenario copy_multiple_locations)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 35:literal
  3:point <- copy 1:point
]
+run: ingredient 0 is 1
+mem: location 1 is 34
+mem: location 2 is 35
+mem: storing 34 in location 3
+mem: storing 35 in location 4

:(before "End Mu Types Initialization")
// A more complex container, containing another container as one of its
// elements.
type_number point_integer = Type_number["point-integer"] = Next_type_number++;
Type[point_integer].size = 2;
Type[point_integer].kind = container;
Type[point_integer].name = "point-integer";
vector<type_number> p2;
p2.push_back(point);
Type[point_integer].elements.push_back(p2);
vector<type_number> i2;
i2.push_back(integer);
Type[point_integer].elements.push_back(i2);

:(scenario copy_handles_nested_container_elements)
recipe main [
  12:integer <- copy 34:literal
  13:integer <- copy 35:literal
  14:integer <- copy 36:literal
  15:point-integer <- copy 12:point-integer
]
+mem: storing 36 in location 17

//: Containers can be checked for equality with a single instruction just like
//: integers, no matter how large they are.

:(scenario compare_multiple_locations)
recipe main [
  1:integer <- copy 34:literal  # first
  2:integer <- copy 35:literal
  3:integer <- copy 36:literal
  4:integer <- copy 34:literal  # second
  5:integer <- copy 35:literal
  6:integer <- copy 36:literal
  7:boolean <- equal 1:point-integer, 4:point-integer
]
+mem: storing 1 in location 7

:(scenario compare_multiple_locations2)
recipe main [
  1:integer <- copy 34:literal  # first
  2:integer <- copy 35:literal
  3:integer <- copy 36:literal
  4:integer <- copy 34:literal  # second
  5:integer <- copy 35:literal
  6:integer <- copy 37:literal  # different
  7:boolean <- equal 1:point-integer, 4:point-integer
]
+mem: storing 0 in location 7

:(before "End size_of(types) Cases")
type_info t = Type[types.at(0)];
if (t.kind == container) {
  // size of a container is the sum of the sizes of its elements
  size_t result = 0;
  for (index_t i = 0; i < t.elements.size(); ++i) {
    result += size_of(t.elements.at(i));
  }
  return result;
}

//:: To access elements of a container, use 'get'
:(scenario get)
recipe main [
  12:integer <- copy 34:literal
  13:integer <- copy 35:literal
  15:integer <- get 12:point, 1:offset
]
+run: instruction main/2
+run: ingredient 0 is 12
+run: ingredient 1 is 1
+run: address to copy is 13
+run: its type is 1
+mem: location 13 is 35
+run: product 0 is 15
+mem: storing 35 in location 15

:(before "End Primitive Recipe Declarations")
GET,
:(before "End Primitive Recipe Numbers")
Recipe_number["get"] = GET;
:(before "End Primitive Recipe Implementations")
case GET: {
  reagent base = current_instruction().ingredients.at(0);
  index_t base_address = base.value;
  type_number base_type = base.types.at(0);
  assert(Type[base_type].kind == container);
  assert(isa_literal(current_instruction().ingredients.at(1)));
  assert(ingredients.at(1).size() == 1);  // scalar
  index_t offset = ingredients.at(1).at(0);
  index_t src = base_address;
  for (index_t i = 0; i < offset; ++i) {
    src += size_of(Type[base_type].elements.at(i));
  }
  trace("run") << "address to copy is " << src;
  assert(Type[base_type].kind == container);
  assert(Type[base_type].elements.size() > offset);
  type_number src_type = Type[base_type].elements.at(offset).at(0);
  trace("run") << "its type is " << src_type;
  reagent tmp;
  tmp.set_value(src);
  tmp.types.push_back(src_type);
  products.push_back(read_memory(tmp));
  break;
}

//: 'get' requires a literal in ingredient 1. We'll use a synonym called
//: 'offset'.
:(before "End Mu Types Initialization")
Type_number["offset"] = 0;

:(scenario get_handles_nested_container_elements)
recipe main [
  12:integer <- copy 34:literal
  13:integer <- copy 35:literal
  14:integer <- copy 36:literal
  15:integer <- get 12:point-integer, 1:offset
]
+run: instruction main/2
+run: ingredient 0 is 12
+run: ingredient 1 is 1
+run: address to copy is 14
+run: its type is 1
+mem: location 14 is 36
+run: product 0 is 15
+mem: storing 36 in location 15

//:: To write to elements of containers, you need their address.

:(scenario get_address)
recipe main [
  12:integer <- copy 34:literal
  13:integer <- copy 35:literal
  15:address:integer <- get-address 12:point, 1:offset
]
+run: instruction main/2
+run: ingredient 0 is 12
+run: ingredient 1 is 1
+run: address to copy is 13
+mem: storing 13 in location 15

:(before "End Primitive Recipe Declarations")
GET_ADDRESS,
:(before "End Primitive Recipe Numbers")
Recipe_number["get-address"] = GET_ADDRESS;
:(before "End Primitive Recipe Implementations")
case GET_ADDRESS: {
  reagent base = current_instruction().ingredients.at(0);
  index_t base_address = base.value;
  type_number base_type = base.types.at(0);
  assert(Type[base_type].kind == container);
  assert(isa_literal(current_instruction().ingredients.at(1)));
  assert(ingredients.at(1).size() == 1);  // scalar
  index_t offset = ingredients.at(1).at(0);
  index_t result = base_address;
  for (index_t i = 0; i < offset; ++i) {
    result += size_of(Type[base_type].elements.at(i));
  }
  trace("run") << "address to copy is " << result;
  products.resize(1);
  products.at(0).push_back(result);
  break;
}
