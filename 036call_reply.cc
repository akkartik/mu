//: Calls can also generate products, using 'reply'.

:(scenario reply)
recipe main [
  1:number, 2:number <- f 34
]
recipe f [
  12:number <- next-ingredient
  13:number <- add 1, 12:number
  reply 12:number, 13:number
]
+mem: storing 34 in location 1
+mem: storing 35 in location 2

:(before "End Primitive Recipe Declarations")
REPLY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "reply", REPLY);
:(before "End Primitive Recipe Checks")
case REPLY: {
  break;  // checks will be performed by a transform below
}
:(before "End Primitive Recipe Implementations")
case REPLY: {
  // Starting Reply
  if (Trace_stream) {
    trace(9999, "trace") << "reply: decrementing callstack depth from " << Trace_stream->callstack_depth << end();
    --Trace_stream->callstack_depth;
    if (Trace_stream->callstack_depth < 0) {
      Current_routine->calls.clear();
      goto stop_running_current_routine;
    }
  }
  Current_routine->calls.pop_front();
  // just in case 'main' returns a value, drop it for now
  if (Current_routine->calls.empty()) goto stop_running_current_routine;
  const instruction& caller_instruction = current_instruction();
  for (long long int i = 0; i < SIZE(caller_instruction.products); ++i)
    trace(9998, "run") << "result " << i << " is " << to_string(ingredients.at(i)) << end();

  // make reply products available to caller
  copy(ingredients.begin(), ingredients.end(), inserter(products, products.begin()));
  // End Reply
  break;  // continue to process rest of *caller* instruction
}

//: Products can include containers and exclusive containers, addresses and arrays.
:(scenario reply_container)
recipe main [
  3:point <- f 2
]
recipe f [
  12:number <- next-ingredient
  13:number <- copy 35
  reply 12:point/raw
]
+run: result 0 is [2, 35]
+mem: storing 2 in location 3
+mem: storing 35 in location 4

//: Types in reply instructions are checked ahead of time.

:(before "End Checks")
Transform.push_back(check_types_of_reply_instructions);
:(code)
void check_types_of_reply_instructions(recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- check types of reply instructions in recipe " << caller.name << end();
  for (long long int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& caller_instruction = caller.steps.at(i);
    if (caller_instruction.is_label) continue;
    if (caller_instruction.products.empty()) continue;
    if (caller_instruction.operation < MAX_PRIMITIVE_RECIPES) continue;
    const recipe& callee = get(Recipe, caller_instruction.operation);
    for (long long int i = 0; i < SIZE(callee.steps); ++i) {
      const instruction& reply_inst = callee.steps.at(i);
      if (reply_inst.operation != REPLY) continue;
      // check types with the caller
      if (SIZE(caller_instruction.products) > SIZE(reply_inst.ingredients)) {
        raise_error << maybe(caller.name) << "too few values replied from " << callee.name << '\n' << end();
        break;
      }
      for (long long int i = 0; i < SIZE(caller_instruction.products); ++i) {
        reagent lhs = reply_inst.ingredients.at(i);
        canonize_type(lhs);
        reagent rhs = caller_instruction.products.at(i);
        canonize_type(rhs);
        if (!types_coercible(rhs, lhs)) {
          raise_error << maybe(callee.name) << "reply ingredient " << lhs.original_string << " can't be saved in " << rhs.original_string << '\n' << end();
          raise_error << to_string(lhs.type) << " vs " << to_string(rhs.type) << '\n' << end();
          goto finish_reply_check;
        }
      }
      // check that any reply ingredients with /same-as-ingredient connect up
      // the corresponding ingredient and product in the caller.
      for (long long int i = 0; i < SIZE(caller_instruction.products); ++i) {
        if (has_property(reply_inst.ingredients.at(i), "same-as-ingredient")) {
          string_tree* tmp = property(reply_inst.ingredients.at(i), "same-as-ingredient");
          if (!tmp || tmp->right) {
            raise_error << maybe(caller.name) << "'same-as-ingredient' metadata should take exactly one value in " << to_string(reply_inst) << '\n' << end();
            goto finish_reply_check;
          }
          long long int ingredient_index = to_integer(tmp->value);
          if (ingredient_index >= SIZE(caller_instruction.ingredients)) {
            raise_error << maybe(caller.name) << "too few ingredients in '" << to_string(caller_instruction) << "'\n" << end();
            goto finish_reply_check;
          }
          if (!is_dummy(caller_instruction.products.at(i)) && !is_literal(caller_instruction.ingredients.at(ingredient_index)) && caller_instruction.products.at(i).name != caller_instruction.ingredients.at(ingredient_index).name) {
            raise_error << maybe(caller.name) << "'" << to_string(caller_instruction) << "' should write to " << caller_instruction.ingredients.at(ingredient_index).original_string << " rather than " << caller_instruction.products.at(i).original_string << '\n' << end();
          }
        }
      }
      finish_reply_check:;
    }
  }
}

:(scenario reply_type_mismatch)
% Hide_errors = true;
recipe main [
  3:number <- f 2
]
recipe f [
  12:number <- next-ingredient
  13:number <- copy 35
  14:point <- copy 12:point/raw
  reply 14:point
]
+error: f: reply ingredient 14:point can't be saved in 3:number

//: In mu we'd like to assume that any instruction doesn't modify its
//: ingredients unless they're also products. The /same-as-ingredient inside
//: the recipe's 'reply' will help catch accidental misuse of such
//: 'ingredient-products' (sometimes called in-out parameters in other languages).

:(scenario reply_same_as_ingredient)
% Hide_errors = true;
recipe main [
  1:number <- copy 0
  2:number <- test1 1:number  # call with different ingredient and product
]
recipe test1 [
  10:number <- next-ingredient
  reply 10:number/same-as-ingredient:0
]
+error: main: '2:number <- test1 1:number' should write to 1:number rather than 2:number

:(scenario reply_same_as_ingredient_dummy)
recipe main [
  1:number <- copy 0
  _ <- test1 1:number  # call with different ingredient and product
]
recipe test1 [
  10:number <- next-ingredient
  reply 10:number/same-as-ingredient:0
]
$error: 0

:(code)
string to_string(const vector<double>& in) {
  if (in.empty()) return "[]";
  ostringstream out;
  if (SIZE(in) == 1) {
    out << no_scientific(in.at(0));
    return out.str();
  }
  out << "[";
  for (long long int i = 0; i < SIZE(in); ++i) {
    if (i > 0) out << ", ";
    out << no_scientific(in.at(i));
  }
  out << "]";
  return out.str();
}

//: Conditional reply.

:(scenario reply_if)
recipe main [
  1:number <- test1
]
recipe test1 [
  reply-if 0, 34
  reply 35
]
+mem: storing 35 in location 1

:(scenario reply_if_2)
recipe main [
  1:number <- test1
]
recipe test1 [
  reply-if 1, 34
  reply 35
]
+mem: storing 34 in location 1

:(before "End Rewrite Instruction(curr, recipe result)")
// rewrite `reply-if a, b, c, ...` to
//   ```
//   jump-unless a, 1:offset
//   reply b, c, ...
//   ```
if (curr.name == "reply-if") {
  if (curr.products.empty()) {
    curr.operation = get(Recipe_ordinal, "jump-unless");
    curr.name = "jump-unless";
    vector<reagent> results;
    copy(++curr.ingredients.begin(), curr.ingredients.end(), inserter(results, results.end()));
    curr.ingredients.resize(1);
    curr.ingredients.push_back(reagent("1:offset"));
    result.steps.push_back(curr);
    curr.clear();
    curr.operation = get(Recipe_ordinal, "reply");
    curr.name = "reply";
    curr.ingredients.swap(results);
  }
  else {
    raise_error << "'reply-if' never yields any products\n" << end();
  }
}
// rewrite `reply-unless a, b, c, ...` to
//   ```
//   jump-if a, 1:offset
//   reply b, c, ...
//   ```
if (curr.name == "reply-unless") {
  if (curr.products.empty()) {
    curr.operation = get(Recipe_ordinal, "jump-if");
    curr.name = "jump-if";
    vector<reagent> results;
    copy(++curr.ingredients.begin(), curr.ingredients.end(), inserter(results, results.end()));
    curr.ingredients.resize(1);
    curr.ingredients.push_back(reagent("1:offset"));
    result.steps.push_back(curr);
    curr.clear();
    curr.operation = get(Recipe_ordinal, "reply");
    curr.name = "reply";
    curr.ingredients.swap(results);
  }
  else {
    raise_error << "'reply-unless' never yields any products\n" << end();
  }
}
