//: Exclusive containers contain exactly one of a fixed number of 'variants'
//: of different types.
//:
//: They also implicitly contain a tag describing precisely which variant is
//: currently stored in them.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two integer elements.
{
type_number tmp = Type_number["integer-or-point"] = Next_type_number++;
Type[tmp].size = 2;
Type[tmp].kind = exclusive_container;
Type[tmp].name = "integer-or-point";
//? cout << tmp << ": " << Type[tmp].elements.size() << '\n'; //? 1
vector<type_number> t1;
t1.push_back(integer);
Type[tmp].elements.push_back(t1);
//? cout << Type[tmp].elements.size() << '\n'; //? 1
vector<type_number> t2;
t2.push_back(point);
Type[tmp].elements.push_back(t2);
//? cout << Type[tmp].elements.size() << '\n'; //? 1
//? cout << "point: " << point << '\n'; //? 1
Type[tmp].element_names.push_back("i");
Type[tmp].element_names.push_back("p");
}

:(scenario copy_exclusive_container)
# Copying exclusive containers copies all their contents and an extra location for the tag.
recipe main [
  1:integer <- copy 1:literal  # 'point' variant
  2:integer <- copy 34:literal
  3:integer <- copy 35:literal
  4:integer-or-point <- copy 1:integer-or-point
]
+mem: storing 1 in location 4
+mem: storing 34 in location 5
+mem: storing 35 in location 6

:(before "End size_of(types) Cases")
if (t.kind == exclusive_container) {
  // size of an exclusive container is the size of its largest variant
  // (So like containers, it can't contain arrays.)
//?   cout << "--- " << types.at(0) << ' ' << t.size << '\n'; //? 1
//?   cout << "point: " << Type_number["point"] << " " << Type[Type_number["point"]].name << " " << Type[Type_number["point"]].size << '\n'; //? 1
//?   cout << t.name << ' ' << t.size << ' ' << t.elements.size() << '\n'; //? 1
  size_t result = 0;
  for (index_t i = 0; i < t.size; ++i) {
    size_t tmp = size_of(t.elements.at(i));
//?     cout << i << ": " << t.elements.at(i).at(0) << ' ' << tmp << ' ' << result << '\n'; //? 1
    if (tmp > result) result = tmp;
  }
  // ...+1 for its tag.
  return result+1;
}

//:: To access variants of an exclusive container, use 'maybe-convert'.
//: It always returns an address (so that you can modify it) or null (to
//: signal that the conversion failed (because the container contains a
//: different variant).

//: 'maybe-convert' requires a literal in ingredient 1. We'll use a synonym
//: called 'variant'.
:(before "End Mu Types Initialization")
Type_number["variant"] = 0;

:(scenario maybe_convert)
recipe main [
  12:integer <- copy 1:literal
  13:integer <- copy 35:literal
  14:integer <- copy 36:literal
  20:address:point <- maybe-convert 12:integer-or-point, 1:variant
]
+mem: storing 13 in location 20

:(scenario maybe_convert_fail)
recipe main [
  12:integer <- copy 1:literal
  13:integer <- copy 35:literal
  14:integer <- copy 36:literal
  20:address:point <- maybe-convert 12:integer-or-point, 0:variant
]
+mem: storing 0 in location 20

:(before "End Primitive Recipe Declarations")
MAYBE_CONVERT,
:(before "End Primitive Recipe Numbers")
Recipe_number["maybe-convert"] = MAYBE_CONVERT;
:(before "End Primitive Recipe Implementations")
case MAYBE_CONVERT: {
  reagent base = canonize(current_instruction().ingredients.at(0));
  index_t base_address = base.value;
  type_number base_type = base.types.at(0);
  assert(Type[base_type].kind == exclusive_container);
  assert(isa_literal(current_instruction().ingredients.at(1)));
  index_t tag = current_instruction().ingredients.at(1).value;
  long long int result;
  if (tag == static_cast<index_t>(Memory[base_address])) {
    result = base_address+1;
  }
  else {
    result = 0;
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}
