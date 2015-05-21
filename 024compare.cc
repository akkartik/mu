//: Comparison primitives

:(before "End Primitive Recipe Declarations")
EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["equal"] = EQUAL;
:(before "End Primitive Recipe Implementations")
case EQUAL: {
  vector<double>& exemplar = ingredients.at(0);
  bool result = true;
  for (long long int i = 1; i < SIZE(ingredients); ++i) {
    if (!equal(ingredients.at(i).begin(), ingredients.at(i).end(), exemplar.begin())) {
      result = false;
      break;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario equal)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 33:literal
  3:number <- equal 1:number, 2:number
]
+mem: location 1 is 34
+mem: location 2 is 33
+mem: storing 0 in location 3

:(scenario equal2)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 34:literal
  3:number <- equal 1:number, 2:number
]
+mem: location 1 is 34
+mem: location 2 is 34
+mem: storing 1 in location 3

:(scenario equal_multiple)
recipe main [
  1:number <- equal 34:literal, 34:literal, 34:literal
]
+mem: storing 1 in location 1

:(scenario equal_multiple2)
recipe main [
  1:number <- equal 34:literal, 34:literal, 35:literal
]
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
GREATER_THAN,
:(before "End Primitive Recipe Numbers")
Recipe_number["greater-than"] = GREATER_THAN;
:(before "End Primitive Recipe Implementations")
case GREATER_THAN: {
  bool result = true;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    assert(scalar(ingredients.at(i)));
  }
  for (long long int i = /**/1; i < SIZE(ingredients); ++i) {
    if (ingredients.at(i-1).at(0) <= ingredients.at(i).at(0)) {
      result = false;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario greater_than)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 33:literal
  3:boolean <- greater-than 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario greater_than2)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 34:literal
  3:boolean <- greater-than 1:number, 2:number
]
+mem: storing 0 in location 3

:(scenario greater_than_multiple)
recipe main [
  1:boolean <- greater-than 36:literal, 35:literal, 34:literal
]
+mem: storing 1 in location 1

:(scenario greater_than_multiple2)
recipe main [
  1:boolean <- greater-than 36:literal, 35:literal, 35:literal
]
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
LESSER_THAN,
:(before "End Primitive Recipe Numbers")
Recipe_number["lesser-than"] = LESSER_THAN;
:(before "End Primitive Recipe Implementations")
case LESSER_THAN: {
  bool result = true;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    assert(scalar(ingredients.at(i)));
  }
  for (long long int i = /**/1; i < SIZE(ingredients); ++i) {
    if (ingredients.at(i-1).at(0) >= ingredients.at(i).at(0)) {
      result = false;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario lesser_than)
recipe main [
  1:number <- copy 32:literal
  2:number <- copy 33:literal
  3:boolean <- lesser-than 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario lesser_than2)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 33:literal
  3:boolean <- lesser-than 1:number, 2:number
]
+mem: storing 0 in location 3

:(scenario lesser_than_multiple)
recipe main [
  1:boolean <- lesser-than 34:literal, 35:literal, 36:literal
]
+mem: storing 1 in location 1

:(scenario lesser_than_multiple2)
recipe main [
  1:boolean <- lesser-than 34:literal, 35:literal, 35:literal
]
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
GREATER_OR_EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["greater-or-equal"] = GREATER_OR_EQUAL;
:(before "End Primitive Recipe Implementations")
case GREATER_OR_EQUAL: {
  bool result = true;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    assert(scalar(ingredients.at(i)));
  }
  for (long long int i = /**/1; i < SIZE(ingredients); ++i) {
    if (ingredients.at(i-1).at(0) < ingredients.at(i).at(0)) {
      result = false;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario greater_or_equal)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 33:literal
  3:boolean <- greater-or-equal 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario greater_or_equal2)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 34:literal
  3:boolean <- greater-or-equal 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario greater_or_equal3)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 35:literal
  3:boolean <- greater-or-equal 1:number, 2:number
]
+mem: storing 0 in location 3

:(scenario greater_or_equal_multiple)
recipe main [
  1:boolean <- greater-or-equal 36:literal, 35:literal, 35:literal
]
+mem: storing 1 in location 1

:(scenario greater_or_equal_multiple2)
recipe main [
  1:boolean <- greater-or-equal 36:literal, 35:literal, 36:literal
]
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
LESSER_OR_EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["lesser-or-equal"] = LESSER_OR_EQUAL;
:(before "End Primitive Recipe Implementations")
case LESSER_OR_EQUAL: {
  bool result = true;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    assert(scalar(ingredients.at(i)));
  }
  for (long long int i = /**/1; i < SIZE(ingredients); ++i) {
    if (ingredients.at(i-1).at(0) > ingredients.at(i).at(0)) {
      result = false;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario lesser_or_equal)
recipe main [
  1:number <- copy 32:literal
  2:number <- copy 33:literal
  3:boolean <- lesser-or-equal 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario lesser_or_equal2)
recipe main [
  1:number <- copy 33:literal
  2:number <- copy 33:literal
  3:boolean <- lesser-or-equal 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario lesser_or_equal3)
recipe main [
  1:number <- copy 34:literal
  2:number <- copy 33:literal
  3:boolean <- lesser-or-equal 1:number, 2:number
]
+mem: storing 0 in location 3

:(scenario lesser_or_equal_multiple)
recipe main [
  1:boolean <- lesser-or-equal 34:literal, 35:literal, 35:literal
]
+mem: storing 1 in location 1

:(scenario lesser_or_equal_multiple2)
recipe main [
  1:boolean <- lesser-or-equal 34:literal, 35:literal, 34:literal
]
+mem: storing 0 in location 1
