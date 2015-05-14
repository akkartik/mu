//: Boolean primitives

:(before "End Primitive Recipe Declarations")
AND,
:(before "End Primitive Recipe Numbers")
Recipe_number["and"] = AND;
:(before "End Primitive Recipe Implementations")
case AND: {
  bool result = true;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result = result && ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario and)
recipe main [
  1:boolean <- copy 1:literal
  2:boolean <- copy 0:literal
  3:boolean <- and 1:boolean, 2:boolean
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: ingredient 1 is 2
+mem: location 2 is 0
+run: product 0 is 3
+mem: storing 0 in location 3

:(scenario and2)
recipe main [
  1:boolean <- and 1:literal, 1:literal
]
+mem: storing 1 in location 1

:(scenario and_multiple)
recipe main [
  1:boolean <- and 1:literal, 1:literal, 0:literal
]
+mem: storing 0 in location 1

:(scenario and_multiple2)
recipe main [
  1:boolean <- and 1:literal, 1:literal, 1:literal
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
OR,
:(before "End Primitive Recipe Numbers")
Recipe_number["or"] = OR;
:(before "End Primitive Recipe Implementations")
case OR: {
  bool result = false;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result = result || ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario or)
recipe main [
  1:boolean <- copy 1:literal
  2:boolean <- copy 0:literal
  3:boolean <- or 1:boolean, 2:boolean
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: ingredient 1 is 2
+mem: location 2 is 0
+run: product 0 is 3
+mem: storing 1 in location 3

:(scenario or2)
recipe main [
  1:boolean <- or 0:literal, 0:literal
]
+mem: storing 0 in location 1

:(scenario or_multiple)
recipe main [
  1:boolean <- and 0:literal, 0:literal, 0:literal
]
+mem: storing 0 in location 1

:(scenario or_multiple2)
recipe main [
  1:boolean <- or 0:literal, 0:literal, 1:literal
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
NOT,
:(before "End Primitive Recipe Numbers")
Recipe_number["not"] = NOT;
:(before "End Primitive Recipe Implementations")
case NOT: {
  products.resize(ingredients.size());
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    products.at(i).push_back(!ingredients.at(i).at(0));
  }
  break;
}

:(scenario not)
recipe main [
  1:boolean <- copy 1:literal
  2:boolean <- not 1:boolean
]
+run: instruction main/1
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: product 0 is 2
+mem: storing 0 in location 2

:(scenario not_multiple)
recipe main [
  1:boolean, 2:boolean, 3:boolean <- not 1:literal, 0:literal, 1:literal
]
+mem: storing 0 in location 1
+mem: storing 1 in location 2
+mem: storing 0 in location 3
