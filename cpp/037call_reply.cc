//: Calls can also generate products, using 'reply'.

:(scenario reply)
recipe main [
  3:integer, 4:integer <- f 2:literal
]
recipe f [
  12:integer <- next-ingredient
  13:integer <- add 1:literal, 12:integer
  reply 12:integer, 13:integer
]
+run: instruction main/0
+run: result 0 is 2
+mem: storing 2 in location 3
+run: result 1 is 3
+mem: storing 3 in location 4

:(before "End Primitive Recipe Declarations")
REPLY,
:(before "End Primitive Recipe Numbers")
Recipe_number["reply"] = REPLY;
:(before "End Primitive Recipe Implementations")
case REPLY: {
  vector<vector<int> > callee_results;
  for (index_t i = 0; i < current_instruction().ingredients.size(); ++i) {
    callee_results.push_back(read_memory(current_instruction().ingredients[i]));
  }
  const instruction& reply_inst = current_instruction();  // save pointer into recipe before pop
  Current_routine->calls.pop();
  assert(!Current_routine->calls.empty());
  const instruction& caller_instruction = current_instruction();
  assert(caller_instruction.products.size() <= callee_results.size());
  for (index_t i = 0; i < caller_instruction.products.size(); ++i) {
    trace("run") << "result " << i << " is " << to_string(callee_results[i]);
    // check that any reply ingredients with /same-as-ingredient connect up
    // the corresponding ingredient and product in the caller.
    if (has_property(reply_inst.ingredients[i], "same-as-ingredient")) {
      vector<string> tmp = property(reply_inst.ingredients[i], "same-as-ingredient");
      assert(tmp.size() == 1);
      int ingredient_index = to_int(tmp[0]);
      if (caller_instruction.products[i].value != caller_instruction.ingredients[ingredient_index].value)
        raise << "'same-as-ingredient' result " << caller_instruction.products[i].value << " must be location " << caller_instruction.ingredients[ingredient_index].value << '\n';
    }
    write_memory(caller_instruction.products[i], callee_results[i]);
  }
  break;  // instruction loop will increment caller's step_index
}

//: Products can include containers and exclusive containers, addresses and arrays.
:(scenario reply_container)
recipe main [
  3:point <- f 2:literal
]
recipe f [
  12:integer <- next-ingredient
  13:integer <- copy 35:literal
  reply 12:point
]
+run: instruction main/0
+run: result 0 is [2, 35]
+mem: storing 2 in location 3
+mem: storing 35 in location 4

//: In mu we'd like to assume that any instruction doesn't modify its
//: ingredients unless they're also products. The /same-as-ingredient inside
//: the recipe's 'reply' will help catch accidental misuse of such
//: 'ingredient-results' (sometimes called in-out parameters in other languages).
:(scenario reply_same_as_ingredient)
% Hide_warnings = true;
recipe main [
  1:address:integer <- new integer:type
  2:address:integer <- test1 1:address:integer  # call with different ingredient and product
]
recipe test1 [
  10:address:integer <- next-ingredient
  reply 10:address:integer/same-as-ingredient:0
]
+warn: 'same-as-ingredient' result 2 must be location 1

:(code)
string to_string(const vector<int>& in) {
  if (in.empty()) return "[]";
  ostringstream out;
  if (in.size() == 1) {
    out << in[0];
    return out.str();
  }
  out << "[";
  for (index_t i = 0; i < in.size(); ++i) {
    if (i > 0) out << ", ";
    out << in[i];
  }
  out << "]";
  return out.str();
}
