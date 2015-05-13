//: Arithmetic primitives

:(before "End Primitive Recipe Declarations")
ADD,
:(before "End Primitive Recipe Numbers")
Recipe_number["add"] = ADD;
:(before "End Primitive Recipe Implementations")
case ADD: {
  long long int result = 0;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result += ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario add_literal)
recipe main [
  1:integer <- add 23:literal, 34:literal
]
+run: instruction main/0
+run: ingredient 0 is 23
+run: ingredient 1 is 34
+run: product 0 is 1
+mem: storing 57 in location 1

:(scenario add)
recipe main [
  1:integer <- copy 23:literal
  2:integer <- copy 34:literal
  3:integer <- add 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 23
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 3
+mem: storing 57 in location 3

:(scenario add_multiple)
recipe main [
  1:integer <- add 3:literal, 4:literal, 5:literal
]
+mem: storing 12 in location 1

:(before "End Primitive Recipe Declarations")
SUBTRACT,
:(before "End Primitive Recipe Numbers")
Recipe_number["subtract"] = SUBTRACT;
:(before "End Primitive Recipe Implementations")
case SUBTRACT: {
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int result = ingredients.at(0).at(0);
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result -= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario subtract_literal)
recipe main [
  1:integer <- subtract 5:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 5
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 3 in location 1

:(scenario subtract)
recipe main [
  1:integer <- copy 23:literal
  2:integer <- copy 34:literal
  3:integer <- subtract 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 23
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 3
+mem: storing -11 in location 3

:(scenario subtract_multiple)
recipe main [
  1:integer <- subtract 6:literal, 3:literal, 2:literal
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
MULTIPLY,
:(before "End Primitive Recipe Numbers")
Recipe_number["multiply"] = MULTIPLY;
:(before "End Primitive Recipe Implementations")
case MULTIPLY: {
  long long int result = 1;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result *= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario multiply_literal)
recipe main [
  1:integer <- multiply 2:literal, 3:literal
]
+run: instruction main/0
+run: ingredient 0 is 2
+run: ingredient 1 is 3
+run: product 0 is 1
+mem: storing 6 in location 1

:(scenario multiply)
recipe main [
  1:integer <- copy 4:literal
  2:integer <- copy 6:literal
  3:integer <- multiply 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 4
+run: ingredient 1 is 2
+mem: location 2 is 6
+run: product 0 is 3
+mem: storing 24 in location 3

:(scenario multiply_multiple)
recipe main [
  1:integer <- multiply 2:literal, 3:literal, 4:literal
]
+mem: storing 24 in location 1

:(before "End Primitive Recipe Declarations")
DIVIDE,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide"] = DIVIDE;
:(before "End Primitive Recipe Implementations")
case DIVIDE: {
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int result = ingredients.at(0).at(0);
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result /= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario divide_literal)
recipe main [
  1:integer <- divide 8:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 8
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 4 in location 1

:(scenario divide)
recipe main [
  1:integer <- copy 27:literal
  2:integer <- copy 3:literal
  3:integer <- divide 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 27
+run: ingredient 1 is 2
+mem: location 2 is 3
+run: product 0 is 3
+mem: storing 9 in location 3

:(scenario divide_multiple)
recipe main [
  1:integer <- divide 12:literal, 3:literal, 2:literal
]
+mem: storing 2 in location 1

:(before "End Primitive Recipe Declarations")
DIVIDE_WITH_REMAINDER,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide-with-remainder"] = DIVIDE_WITH_REMAINDER;
:(before "End Primitive Recipe Implementations")
case DIVIDE_WITH_REMAINDER: {
  long long int quotient = ingredients.at(0).at(0) / ingredients.at(1).at(0);
  long long int remainder = ingredients.at(0).at(0) % ingredients.at(1).at(0);
  products.resize(2);
  products.at(0).push_back(quotient);
  products.at(1).push_back(remainder);
  break;
}

:(scenario divide_with_remainder_literal)
recipe main [
  1:integer, 2:integer <- divide-with-remainder 9:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 9
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 4 in location 1
+run: product 1 is 2
+mem: storing 1 in location 2

:(scenario divide_with_remainder)
recipe main [
  1:integer <- copy 27:literal
  2:integer <- copy 11:literal
  3:integer, 4:integer <- divide-with-remainder 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 27
+run: ingredient 1 is 2
+mem: location 2 is 11
+run: product 0 is 3
+mem: storing 2 in location 3
+run: product 1 is 4
+mem: storing 5 in location 4
