//: Comparison primitives

:(before "End Primitive Recipe Declarations")
EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["equal"] = EQUAL;
:(before "End Primitive Recipe Implementations")
case EQUAL: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  vector<long long int> result;
  result.push_back(equal(arg0.begin(), arg0.end(), arg1.begin()));
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario equal)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 33:literal
  3:integer <- equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 0
+mem: storing 0 in location 3

:(scenario equal2)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 34:literal
  3:integer <- equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 1
+mem: storing 1 in location 3

:(before "End Primitive Recipe Declarations")
GREATER_THAN,
:(before "End Primitive Recipe Numbers")
Recipe_number["greater-than"] = GREATER_THAN;
:(before "End Primitive Recipe Implementations")
case GREATER_THAN: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] > arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario greater_than)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 33:literal
  3:integer <- greater-than 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario greater_than2)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 34:literal
  3:integer <- greater-than 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 0
+mem: storing 0 in location 3

:(before "End Primitive Recipe Declarations")
LESSER_THAN,
:(before "End Primitive Recipe Numbers")
Recipe_number["lesser-than"] = LESSER_THAN;
:(before "End Primitive Recipe Implementations")
case LESSER_THAN: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] < arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario lesser_than)
recipe main [
  1:integer <- copy 32:literal
  2:integer <- copy 33:literal
  3:integer <- lesser-than 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 32
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario lesser_than2)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 33:literal
  3:integer <- lesser-than 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 0
+mem: storing 0 in location 3

:(before "End Primitive Recipe Declarations")
GREATER_OR_EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["greater-or-equal"] = GREATER_OR_EQUAL;
:(before "End Primitive Recipe Implementations")
case GREATER_OR_EQUAL: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] >= arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario greater_or_equal)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 33:literal
  3:integer <- greater-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario greater_or_equal2)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 34:literal
  3:integer <- greater-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario greater_or_equal3)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 35:literal
  3:integer <- greater-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 35
+run: product 0 is 0
+mem: storing 0 in location 3

:(before "End Primitive Recipe Declarations")
LESSER_OR_EQUAL,
:(before "End Primitive Recipe Numbers")
Recipe_number["lesser-or-equal"] = LESSER_OR_EQUAL;
:(before "End Primitive Recipe Implementations")
case LESSER_OR_EQUAL: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] <= arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario lesser_or_equal)
recipe main [
  1:integer <- copy 32:literal
  2:integer <- copy 33:literal
  3:integer <- lesser-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 32
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario lesser_or_equal2)
recipe main [
  1:integer <- copy 33:literal
  2:integer <- copy 33:literal
  3:integer <- lesser-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 33
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 1
+mem: storing 1 in location 3

:(scenario lesser_or_equal3)
recipe main [
  1:integer <- copy 34:literal
  2:integer <- copy 33:literal
  3:integer <- lesser-or-equal 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 34
+run: ingredient 1 is 2
+mem: location 2 is 33
+run: product 0 is 0
+mem: storing 0 in location 3
