//: Calls can also generate products, using 'reply' or 'return'.

:(scenario return)
def main [
  1:number, 2:number <- f 34
]
def f [
  12:number <- next-ingredient
  13:number <- add 1, 12:number
  reply 12:number, 13:number
]
+mem: storing 34 in location 1
+mem: storing 35 in location 2

:(before "End Primitive Recipe Declarations")
RETURN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "return", RETURN);
put(Recipe_ordinal, "reply", RETURN);  // synonym while teaching
:(before "End Primitive Recipe Checks")
case RETURN: {
  break;  // checks will be performed by a transform below
}
:(before "End Primitive Recipe Implementations")
case RETURN: {
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
  for (int i = 0; i < SIZE(caller_instruction.products); ++i)
    trace(9998, "run") << "result " << i << " is " << to_string(ingredients.at(i)) << end();

  // make reply products available to caller
  copy(ingredients.begin(), ingredients.end(), inserter(products, products.begin()));
  // End Reply
  break;  // continue to process rest of *caller* instruction
}

//: Types in reply instructions are checked ahead of time.

:(before "End Checks")
Transform.push_back(check_types_of_reply_instructions);
:(code)
void check_types_of_reply_instructions(recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- check types of reply instructions in recipe " << caller.name << end();
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& caller_instruction = caller.steps.at(i);
    if (caller_instruction.is_label) continue;
    if (caller_instruction.products.empty()) continue;
    if (caller_instruction.operation < MAX_PRIMITIVE_RECIPES) continue;
    const recipe& callee = get(Recipe, caller_instruction.operation);
    for (int i = 0; i < SIZE(callee.steps); ++i) {
      const instruction& reply_inst = callee.steps.at(i);
      if (reply_inst.operation != RETURN) continue;
      // check types with the caller
      if (SIZE(caller_instruction.products) > SIZE(reply_inst.ingredients)) {
        raise << maybe(caller.name) << "too few values replied from " << callee.name << '\n' << end();
        break;
      }
      for (int i = 0; i < SIZE(caller_instruction.products); ++i) {
        reagent lhs = reply_inst.ingredients.at(i);
        reagent rhs = caller_instruction.products.at(i);
        // End Check RETURN Copy(lhs, rhs)
        if (!types_coercible(rhs, lhs)) {
          raise << maybe(callee.name) << reply_inst.name << " ingredient " << lhs.original_string << " can't be saved in " << rhs.original_string << '\n' << end();
          raise << to_string(lhs.type) << " vs " << to_string(rhs.type) << '\n' << end();
          goto finish_reply_check;
        }
      }
      // check that any reply ingredients with /same-as-ingredient connect up
      // the corresponding ingredient and product in the caller.
      for (int i = 0; i < SIZE(caller_instruction.products); ++i) {
        if (has_property(reply_inst.ingredients.at(i), "same-as-ingredient")) {
          string_tree* tmp = property(reply_inst.ingredients.at(i), "same-as-ingredient");
          if (!tmp || tmp->right) {
            raise << maybe(caller.name) << "'same-as-ingredient' metadata should take exactly one value in " << to_original_string(reply_inst) << '\n' << end();
            goto finish_reply_check;
          }
          int ingredient_index = to_integer(tmp->value);
          if (ingredient_index >= SIZE(caller_instruction.ingredients)) {
            raise << maybe(caller.name) << "too few ingredients in '" << to_original_string(caller_instruction) << "'\n" << end();
            goto finish_reply_check;
          }
          if (!is_dummy(caller_instruction.products.at(i)) && !is_literal(caller_instruction.ingredients.at(ingredient_index)) && caller_instruction.products.at(i).name != caller_instruction.ingredients.at(ingredient_index).name) {
            raise << maybe(caller.name) << "'" << to_original_string(caller_instruction) << "' should write to " << caller_instruction.ingredients.at(ingredient_index).original_string << " rather than " << caller_instruction.products.at(i).original_string << '\n' << end();
          }
        }
      }
      finish_reply_check:;
    }
  }
}

:(scenario return_type_mismatch)
% Hide_errors = true;
def main [
  3:number <- f 2
]
def f [
  12:number <- next-ingredient
  13:number <- copy 35
  14:point <- copy 12:point/raw
  return 14:point
]
+error: f: return ingredient 14:point can't be saved in 3:number

//: In mu we'd like to assume that any instruction doesn't modify its
//: ingredients unless they're also products. The /same-as-ingredient inside
//: the recipe's 'reply' will help catch accidental misuse of such
//: 'ingredient-products' (sometimes called in-out parameters in other languages).

:(scenario return_same_as_ingredient)
% Hide_errors = true;
def main [
  1:number <- copy 0
  2:number <- test1 1:number  # call with different ingredient and product
]
def test1 [
  10:number <- next-ingredient
  return 10:number/same-as-ingredient:0
]
+error: main: '2:number <- test1 1:number' should write to 1:number rather than 2:number

:(scenario return_same_as_ingredient_dummy)
def main [
  1:number <- copy 0
  _ <- test1 1:number  # call with different ingredient and product
]
def test1 [
  10:number <- next-ingredient
  return 10:number/same-as-ingredient:0
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
  for (int i = 0; i < SIZE(in); ++i) {
    if (i > 0) out << ", ";
    out << no_scientific(in.at(i));
  }
  out << "]";
  return out.str();
}
