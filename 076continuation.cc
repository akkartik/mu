//: Continuations are a powerful primitive for constructing advanced kinds of
//: control *policies* like back-tracking.
//:
//: In Mu, continuations are first-class and delimited, and are constructed
//: out of two primitives:
//:
//:  * 'call-with-continuation-mark' marks the top of the call stack and then
//:    calls the provided function.
//:  * 'return-continuation-until-mark' copies the top of the stack
//:    until the mark, and returns it as the result of
//:    call-with-continuation-mark (which might be a distant ancestor on the call
//:    stack; intervening calls don't return)
//:
//: The resulting slice of the stack can now be called just like a regular
//: function.

:(before "End Mu Types Initialization")
type_ordinal continuation = Type_ordinal["continuation"] = Next_type_ordinal++;
Type[continuation].name = "continuation";

//: A continuation can be called like a recipe.
:(before "End is_mu_recipe Atom Cases(r)")
if (r.type->name == "continuation") return true;

//: However, it can't be type-checked like most recipes. Pretend it's like a
//: header-less recipe.
:(after "Begin Reagent->Recipe(r, recipe_header)")
if (r.type->atom && r.type->name == "continuation") {
  result_header.has_header = false;
  return result_header;
}

:(scenario delimited_continuation)
recipe main [
  1:continuation <- call-with-continuation-mark f, 77  # 77 is an argument to f
  2:number <- copy 5
  {
    2:number <- call 1:continuation, 2:number  # 2 is an argument to g, the 'top' of the continuation
    3:boolean <- greater-or-equal 2:number, 8
    break-if 3:boolean
    loop
  }
]
recipe f [
  11:number <- next-ingredient
  12:number <- g 11:number
  return 12:number
]
recipe g [
  21:number <- next-ingredient
  rewind-ingredients
  return-continuation-until-mark
  # calls of the continuation start from here
  22:number <- next-ingredient
  23:number <- add 22:number, 1
  return 23:number
]
# first call of 'g' executes the part before return-continuation-until-mark
+mem: storing 77 in location 21
+run: {2: "number"} <- copy {5: "literal"}
+mem: storing 5 in location 2
# calls of the continuation execute the part after return-continuation-until-mark
+run: {2: "number"} <- call {1: "continuation"}, {2: "number"}
+mem: storing 5 in location 22
+mem: storing 6 in location 2
+run: {2: "number"} <- call {1: "continuation"}, {2: "number"}
+mem: storing 6 in location 22
+mem: storing 7 in location 2
+run: {2: "number"} <- call {1: "continuation"}, {2: "number"}
+mem: storing 7 in location 22
+mem: storing 8 in location 2
# first call of 'g' does not execute the part after return-continuation-until-mark
-mem: storing 77 in location 22
# calls of the continuation don't execute the part before return-continuation-until-mark
-mem: storing 5 in location 21
-mem: storing 6 in location 21
-mem: storing 7 in location 21
# termination
-mem: storing 9 in location 2

:(before "End call Fields")
bool is_base_of_continuation;
:(before "End call Constructor")
is_base_of_continuation = false;

:(before "End Primitive Recipe Declarations")
CALL_WITH_CONTINUATION_MARK,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["call-with-continuation-mark"] = CALL_WITH_CONTINUATION_MARK;
:(before "End Primitive Recipe Checks")
case CALL_WITH_CONTINUATION_MARK: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CALL_WITH_CONTINUATION_MARK: {
  // like call, but mark the current call as a 'base of continuation' call
  // before pushing the next one on it
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace("trace") << "delimited continuation; incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  const instruction& caller_instruction = current_instruction();
  Current_routine->calls.front().is_base_of_continuation = true;
  Current_routine->calls.push_front(call(Recipe_ordinal[current_instruction().ingredients.at(0).name]));
  ingredients.erase(ingredients.begin());  // drop the callee
  finish_call_housekeeping(caller_instruction, ingredients);
  continue;
}

//: save the slice of current call stack until the 'call-with-continuation-mark'
//: call, and return it as the result.
//: todo: implement delimited continuations in Mu's memory
:(before "End Globals")
map<long long int, call_stack> Delimited_continuation;
long long int Next_delimited_continuation_id = 0;
:(before "End Reset")
Delimited_continuation.clear();
Next_delimited_continuation_id = 0;

:(before "End Primitive Recipe Declarations")
RETURN_CONTINUATION_UNTIL_MARK,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["return-continuation-until-mark"] = RETURN_CONTINUATION_UNTIL_MARK;
:(before "End Primitive Recipe Checks")
case RETURN_CONTINUATION_UNTIL_MARK: {
  break;
}
:(before "End Primitive Recipe Implementations")
case RETURN_CONTINUATION_UNTIL_MARK: {
  // first clear any existing ingredients, to isolate the creation of the
  // continuation from its calls
  Current_routine->calls.front().ingredient_atoms.clear();
  Current_routine->calls.front().next_ingredient_to_process = 0;
  // copy the current call stack until the most recent marked call
  call_stack::iterator find_base_of_continuation(call_stack& c);  // manual prototype containing '::'
  call_stack::iterator base = find_base_of_continuation(Current_routine->calls);
  if (base == Current_routine->calls.end()) {
    raise << maybe(current_recipe_name()) << "couldn't find a 'call-with-continuation-mark' to return to\n" << end();
    raise << maybe(current_recipe_name()) << "call stack:\n" << end();
    for (call_stack::iterator p = Current_routine->calls.begin();  p != Current_routine->calls.end();  ++p)
      raise << maybe(current_recipe_name()) << "  " << get(Recipe, p->running_recipe).name << '\n' << end();
    break;
  }
  Delimited_continuation[Next_delimited_continuation_id] = call_stack(Current_routine->calls.begin(), base);
  while (Current_routine->calls.begin() != base) {
    if (Trace_stream) {
      --Trace_stream->callstack_depth;
      assert(Trace_stream->callstack_depth >= 0);
    }
    Current_routine->calls.pop_front();
  }
  // return it as the result of the marked call
  products.resize(1);
  products.at(0).push_back(Next_delimited_continuation_id);
  ++Next_delimited_continuation_id;
  break;  // continue to process rest of marked call
}

:(code)
call_stack::iterator find_base_of_continuation(call_stack& c) {
  for (call_stack::iterator p = c.begin(); p != c.end(); ++p)
    if (p->is_base_of_continuation) return p;
  return c.end();
}

//: overload 'call' for continuations
:(after "Begin Call")
if (current_instruction().ingredients.at(0).type->atom
    && current_instruction().ingredients.at(0).type->name == "continuation") {
  // copy multiple calls on to current call stack
  assert(scalar(ingredients.at(0)));
  if (Delimited_continuation.find(ingredients.at(0).at(0)) == Delimited_continuation.end())
    raise << maybe(current_recipe_name()) << "no such delimited continuation " << current_instruction().ingredients.at(0).original_string << '\n' << end();
  const call_stack& new_calls = Delimited_continuation[ingredients.at(0).at(0)];
  const call& caller = (SIZE(new_calls) > 1) ? *++new_calls.begin() : Current_routine->calls.front();
  for (call_stack::const_reverse_iterator p = new_calls.rbegin(); p != new_calls.rend(); ++p)
    Current_routine->calls.push_front(*p);
  if (Trace_stream) {
    Trace_stream->callstack_depth += SIZE(new_calls);
    trace("trace") << "calling delimited continuation; growing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  ++current_step_index();  // skip past the return-continuation-until-mark
  ingredients.erase(ingredients.begin());  // drop the callee
  finish_call_housekeeping(to_instruction(caller), ingredients);
  continue;
}
