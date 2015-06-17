//: Exclusive containers contain exactly one of a fixed number of 'variants'
//: of different types.
//:
//: They also implicitly contain a tag describing precisely which variant is
//: currently stored in them.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
{
type_number tmp = Type_number["number-or-point"] = Next_type_number++;
Type[tmp].size = 2;
Type[tmp].kind = exclusive_container;
Type[tmp].name = "number-or-point";
//? cout << tmp << ": " << SIZE(Type[tmp].elements) << '\n'; //? 1
vector<type_number> t1;
t1.push_back(number);
Type[tmp].elements.push_back(t1);
//? cout << SIZE(Type[tmp].elements) << '\n'; //? 1
vector<type_number> t2;
t2.push_back(point);
Type[tmp].elements.push_back(t2);
//? cout << SIZE(Type[tmp].elements) << '\n'; //? 1
//? cout << "point: " << point << '\n'; //? 1
Type[tmp].element_names.push_back("i");
Type[tmp].element_names.push_back("p");
}

//: Tests in this layer often explicitly setup memory before reading it as an
//: array. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid warnings.
:(scenario copy_exclusive_container)
# Copying exclusive containers copies all their contents and an extra location for the tag.
recipe main [
  1:number <- copy 1:literal  # 'point' variant
  2:number <- copy 34:literal
  3:number <- copy 35:literal
  4:number-or-point <- copy 1:number-or-point/raw  # unsafe
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
//?   cout << t.name << ' ' << t.size << ' ' << SIZE(t.elements) << '\n'; //? 1
  long long int result = 0;
  for (long long int i = 0; i < t.size; ++i) {
    long long int tmp = size_of(t.elements.at(i));
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
  12:number <- copy 1:literal
  13:number <- copy 35:literal
  14:number <- copy 36:literal
  20:address:point <- maybe-convert 12:number-or-point/raw, 1:variant  # unsafe
]
+mem: storing 13 in location 20

:(scenario maybe_convert_fail)
recipe main [
  12:number <- copy 1:literal
  13:number <- copy 35:literal
  14:number <- copy 36:literal
  20:address:point <- maybe-convert 12:number-or-point/raw, 0:variant  # unsafe
]
+mem: storing 0 in location 20

:(before "End Primitive Recipe Declarations")
MAYBE_CONVERT,
:(before "End Primitive Recipe Numbers")
Recipe_number["maybe-convert"] = MAYBE_CONVERT;
:(before "End Primitive Recipe Implementations")
case MAYBE_CONVERT: {
  reagent base = canonize(current_instruction().ingredients.at(0));
  long long int base_address = base.value;
  type_number base_type = base.types.at(0);
  assert(Type[base_type].kind == exclusive_container);
  assert(is_literal(current_instruction().ingredients.at(1)));
  long long int tag = current_instruction().ingredients.at(1).value;
  long long int result;
  if (tag == static_cast<long long int>(Memory[base_address])) {
    result = base_address+1;
  }
  else {
    result = 0;
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

//:: Allow exclusive containers to be defined in mu code.

:(scenario exclusive_container)
exclusive-container foo [
  x:number
  y:number
]
+parse: reading exclusive-container foo
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

:(before "End Command Handlers")
else if (command == "exclusive-container") {
  insert_container(command, exclusive_container, in);
}
