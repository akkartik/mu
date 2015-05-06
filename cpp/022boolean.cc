//: Boolean primitives

:(before "End Primitive Recipe Declarations")
AND,
:(before "End Primitive Recipe Numbers")
Recipe_number["and"] = AND;
:(before "End Primitive Recipe Implementations")
case AND: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] && arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario and)
recipe main [
  1:integer <- copy 1:literal
  2:integer <- copy 0:literal
  3:integer <- and 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: ingredient 1 is 2
+mem: location 2 is 0
+run: product 0 is 0
+mem: storing 0 in location 3

:(before "End Primitive Recipe Declarations")
OR,
:(before "End Primitive Recipe Numbers")
Recipe_number["or"] = OR;
:(before "End Primitive Recipe Implementations")
case OR: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  vector<long long int> arg1 = read_memory(current_instruction().ingredients[1]);
  assert(arg1.size() == 1);
  vector<long long int> result;
  result.push_back(arg0[0] || arg1[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario or)
recipe main [
  1:integer <- copy 1:literal
  2:integer <- copy 0:literal
  3:integer <- or 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: ingredient 1 is 2
+mem: location 2 is 0
+run: product 0 is 1
+mem: storing 1 in location 3

:(before "End Primitive Recipe Declarations")
NOT,
:(before "End Primitive Recipe Numbers")
Recipe_number["not"] = NOT;
:(before "End Primitive Recipe Implementations")
case NOT: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  vector<long long int> result;
  result.push_back(!arg0[0]);
  trace("run") << "product 0 is " << result[0];
  write_memory(current_instruction().products[0], result);
  break;
}

:(scenario not)
recipe main [
  1:integer <- copy 1:literal
  2:integer <- not 1:integer
]
+run: instruction main/1
+run: ingredient 0 is 1
+mem: location 1 is 1
+run: product 0 is 0
+mem: storing 0 in location 2
