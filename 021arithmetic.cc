//: Arithmetic primitives

:(before "End Primitive Recipe Declarations")
ADD,
:(before "End Primitive Recipe Numbers")
Recipe_number["add"] = ADD;
:(before "End Primitive Recipe Implementations")
case ADD: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] + arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario add_literal)
recipe main [
  1:integer <- add 23:literal, 34:literal
]
+run: instruction main/0
+run: ingredient 0 is 23
+run: ingredient 1 is 34
+run: product 0 is 57
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
+run: product 0 is 57
+mem: storing 57 in location 3

:(before "End Primitive Recipe Declarations")
SUBTRACT,
:(before "End Primitive Recipe Numbers")
Recipe_number["subtract"] = SUBTRACT;
:(before "End Primitive Recipe Implementations")
case SUBTRACT: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] - arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario subtract_literal)
recipe main [
  1:integer <- subtract 5:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 5
+run: ingredient 1 is 2
+run: product 0 is 3
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
+run: product 0 is -11
+mem: storing -11 in location 3

:(before "End Primitive Recipe Declarations")
MULTIPLY,
:(before "End Primitive Recipe Numbers")
Recipe_number["multiply"] = MULTIPLY;
:(before "End Primitive Recipe Implementations")
case MULTIPLY: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  trace("run") << "ingredient 1 is " << arg1[0];
  vector<long long int> result;
  result.push_back(arg0[0] * arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario multiply_literal)
recipe main [
  1:integer <- multiply 2:literal, 3:literal
]
+run: instruction main/0
+run: ingredient 0 is 2
+run: ingredient 1 is 3
+run: product 0 is 6
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
+run: product 0 is 24
+mem: storing 24 in location 3

:(before "End Primitive Recipe Declarations")
DIVIDE,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide"] = DIVIDE;
:(before "End Primitive Recipe Implementations")
case DIVIDE: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  trace("run") << "ingredient 1 is " << arg1[0];
  vector<long long int> result;
  result.push_back(arg0[0] / arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario divide_literal)
recipe main [
  1:integer <- divide 8:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 8
+run: ingredient 1 is 2
+run: product 0 is 4
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
+run: product 0 is 9
+mem: storing 9 in location 3

:(before "End Primitive Recipe Declarations")
DIVIDE_WITH_REMAINDER,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide-with-remainder"] = DIVIDE_WITH_REMAINDER;
:(before "End Primitive Recipe Implementations")
case DIVIDE_WITH_REMAINDER: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result0;
  result0.push_back(arg0[0] / arg1[0]);
  trace("run") << "product 0 is " << result0[0];
  write_memory(current_instruction().products[0], result0);
  vector<long long int> result1;
  result1.push_back(arg0[0] % arg1[0]);
  trace("run") << "product 1 is " << result1[0];
  write_memory(current_instruction().products[1], result1);
  break;
}

:(scenario divide_with_remainder_literal)
recipe main [
  1:integer, 2:integer <- divide-with-remainder 9:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 9
+run: ingredient 1 is 2
+run: product 0 is 4
+mem: storing 4 in location 1
+run: product 1 is 1
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
+run: product 0 is 2
+mem: storing 2 in location 3
+run: product 1 is 5
+mem: storing 5 in location 4
