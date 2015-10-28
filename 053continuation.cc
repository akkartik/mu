//: Continuations are a powerful primitive for constructing advanced kinds of
//: control *policies* like back-tracking. They're usually provided using a
//: primitive called 'call-cc': http://en.wikipedia.org/wiki/Call-with-current-continuation)
//: But in mu 'call-cc' is constructed out of a combination of two primitives:
//:   'current-continuation', which returns a continuation, and
//:   'continue-from', which takes a continuation to switch to.

//: todo: implement continuations in mu's memory
:(before "End Globals")
map<long long int, call_stack> Continuation;
long long int Next_continuation_id = 0;
:(before "End Setup")
Continuation.clear();
Next_continuation_id = 0;

:(before "End Mu Types Initialization")
type_ordinal continuation = Type_ordinal["continuation"] = Next_type_ordinal++;
Type[continuation].name = "continuation";

:(before "End Primitive Recipe Declarations")
CURRENT_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["current-continuation"] = CURRENT_CONTINUATION;
:(before "End Primitive Recipe Checks")
case CURRENT_CONTINUATION: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CURRENT_CONTINUATION: {
  // copy the current call stack
  Continuation[Next_continuation_id] = Current_routine->calls;  // deep copy because calls have no pointers
  // make sure calling the copy doesn't spawn the same continuation again
  ++Continuation[Next_continuation_id].front().running_step_index;
  products.resize(1);
  products.at(0).push_back(Next_continuation_id);
  ++Next_continuation_id;
  trace("current-continuation") << "new continuation " << Next_continuation_id << end();
  break;
}

:(before "End Primitive Recipe Declarations")
CONTINUE_FROM,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["continue-from"] = CONTINUE_FROM;
:(before "End Primitive Recipe Checks")
case CONTINUE_FROM: {
  if (!is_mu_continuation(inst.ingredients.at(0))) {
    raise_error << maybe(Recipe[r].name) << "first ingredient of 'continue-from' should be a continuation generated by 'current-continuation', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CONTINUE_FROM: {
  long long int c = ingredients.at(0).at(0);
  if (Trace_stream) {
    Trace_stream->callstack_depth += SIZE(Continuation[c]);
    trace("trace") << "continuation; growing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  Current_routine->calls = Continuation[c];  // deep copy; calls have no pointers
  continue;  // skip rest of this instruction
}

:(code)
bool is_mu_continuation(const reagent& x) {
  if (!x.type) return false;
  return x.type->value == Type_ordinal["continuation"];
}

:(scenario continuation)
# simulate a loop using continuations
recipe main [
  1:number <- copy 0
  2:continuation <- current-continuation
  {
    3:boolean <- greater-or-equal 1:number, 3
    break-if 3:boolean
    1:number <- add 1:number, 1
    continue-from 2:continuation  # loop
  }
]
+mem: storing 1 in location 1
+mem: storing 2 in location 1
+mem: storing 3 in location 1
-mem: storing 4 in location 1
# ensure every iteration doesn't copy the stack over and over
$current-continuation: 1

:(scenario continuation_inside_caller)
recipe main [
  1:number <- copy 0
  2:continuation <- loop-body
  {
    3:boolean <- greater-or-equal 1:number, 3
    break-if 3:boolean
    continue-from 2:continuation  # loop
  }
]

recipe loop-body [
  4:continuation <- current-continuation
  1:number <- add 1:number, 1
]
+mem: storing 1 in location 1
+mem: storing 2 in location 1
+mem: storing 3 in location 1
-mem: storing 4 in location 1

//:: A variant of continuations is the 'delimited' continuation that can be called like any other recipe.
//:
//: In mu, this is constructed out of two primitives:
//:
//:  * 'create-delimited-continuation' lays down a mark on the call
//:    stack and calls the provided function (it is sometimes called 'prompt')
//:  * 'reply-current-continuation' copies the top of the stack until the
//:    mark, and returns it as the response of create-delimited-continuation
//:    (which might be a distant ancestor on the call stack; intervening calls
//:    don't return)
//:
//: The resulting slice of the stack can now be called just like a regular
//: function.

:(scenario delimited_continuation)
recipe main [
  1:continuation <- create-delimited-continuation f:recipe 12  # 12 is an argument to f
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
  reply 12:number
]

recipe g [
  21:number <- next-ingredient
  rewind-ingredients
  reply-delimited-continuation
  # calls of the continuation start from here
  22:number <- next-ingredient
  23:number <- add 22:number, 1
  reply 23:number
]
# first call of 'g' executes the part before reply-delimited-continuation
+mem: storing 12 in location 21
+run: 2:number <- copy 5
+mem: storing 5 in location 2
# calls of the continuation execute the part after reply-delimited-continuation
+run: 2:number <- call 1:continuation, 2:number
+mem: storing 5 in location 22
+mem: storing 6 in location 2
+run: 2:number <- call 1:continuation, 2:number
+mem: storing 6 in location 22
+mem: storing 7 in location 2
+run: 2:number <- call 1:continuation, 2:number
+mem: storing 7 in location 22
+mem: storing 8 in location 2
# first call of 'g' does not execute the part after reply-delimited-continuation
-mem: storing 12 in location 22
# calls of the continuation don't execute the part before reply-delimited-continuation
-mem: storing 5 in location 21
-mem: storing 6 in location 21
-mem: storing 7 in location 21
# termination
-mem: storing 9 in location 2

//: 'create-delimited-continuation' is like 'call' except it adds a 'reset' mark to
//: the call stack

:(before "End call Fields")
bool is_reset;
:(before "End call Constructor")
is_reset = false;

//: like call, but mark the current call as a 'reset' call before pushing the next one on it

:(before "End Primitive Recipe Declarations")
CREATE_DELIMITED_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["create-delimited-continuation"] = CREATE_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Checks")
case CREATE_DELIMITED_CONTINUATION: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CREATE_DELIMITED_CONTINUATION: {
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace("trace") << "delimited continuation; incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  const instruction& caller_instruction = current_instruction();
  Current_routine->calls.front().is_reset = true;
  Current_routine->calls.push_front(call(Recipe_ordinal[current_instruction().ingredients.at(0).name]));
  ingredients.erase(ingredients.begin());  // drop the callee
  finish_call_housekeeping(caller_instruction, ingredients);
  continue;
}

//: save the slice of current call stack until the 'create-delimited-continuation'
//: call, and return it as the result.
//: todo: implement delimited continuations in mu's memory
:(before "End Globals")
map<long long int, call_stack> Delimited_continuation;
long long int Next_delimited_continuation_id = 0;
:(before "End Setup")
Delimited_continuation.clear();
Next_delimited_continuation_id = 0;

:(before "End Primitive Recipe Declarations")
REPLY_DELIMITED_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["reply-delimited-continuation"] = REPLY_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Checks")
case REPLY_DELIMITED_CONTINUATION: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REPLY_DELIMITED_CONTINUATION: {
  // first clear any existing ingredients, to isolate the creation of the
  // continuation from its calls
  Current_routine->calls.front().ingredient_atoms.clear();
  Current_routine->calls.front().next_ingredient_to_process = 0;
  // copy the current call stack until the most recent 'reset' call
  call_stack::iterator find_reset(call_stack& c);  // manual prototype containing '::'
  call_stack::iterator reset = find_reset(Current_routine->calls);
  if (reset == Current_routine->calls.end()) {
    raise_error << maybe(current_recipe_name()) << "couldn't find a 'reset' call to jump out to\n" << end();
    break;
  }
  Delimited_continuation[Next_delimited_continuation_id] = call_stack(Current_routine->calls.begin(), reset);
  while (Current_routine->calls.begin() != reset) {
    if (Trace_stream) {
      --Trace_stream->callstack_depth;
      assert(Trace_stream->callstack_depth >= 0);
    }
    Current_routine->calls.pop_front();
  }
  // return it as the result of the 'reset' call
  products.resize(1);
  products.at(0).push_back(Next_delimited_continuation_id);
  ++Next_delimited_continuation_id;
  break;  // continue to process rest of 'reset' call
}

:(code)
call_stack::iterator find_reset(call_stack& c) {
  for (call_stack::iterator p = c.begin(); p != c.end(); ++p)
    if (p->is_reset) return p;
  return c.end();
}

//: overload 'call' for continuations
:(after "Begin Call")
  if (!current_instruction().ingredients.at(0).properties.empty()
      && current_instruction().ingredients.at(0).properties.at(0).second
      && current_instruction().ingredients.at(0).properties.at(0).second->value == "continuation") {
    // copy multiple calls on to current call stack
    assert(scalar(ingredients.at(0)));
    if (Delimited_continuation.find(ingredients.at(0).at(0)) == Delimited_continuation.end()) {
      raise_error << maybe(current_recipe_name()) << "no such delimited continuation " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    }
    const call_stack& new_calls = Delimited_continuation[ingredients.at(0).at(0)];
    const call& caller = (SIZE(new_calls) > 1) ? *++new_calls.rbegin() : Current_routine->calls.front();
    for (call_stack::const_reverse_iterator p = new_calls.rbegin(); p != new_calls.rend(); ++p)
      Current_routine->calls.push_front(*p);
    if (Trace_stream) {
      Trace_stream->callstack_depth += SIZE(new_calls);
      trace("trace") << "calling delimited continuation; growing callstack depth to " << Trace_stream->callstack_depth << end();
      assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
    }
    ++current_step_index();  // skip past the reply-delimited-continuation
    ingredients.erase(ingredients.begin());  // drop the callee
    finish_call_housekeeping(to_instruction(caller), ingredients);
    continue;
  }

:(code)
const instruction& to_instruction(const call& c) {
  assert(Recipe.find(c.running_recipe) != Recipe.end());
  return Recipe[c.running_recipe].steps.at(c.running_step_index);
}

:(before "End is_mu_recipe Cases")
if (r.type && r.type->value == Type_ordinal["continuation"]) return true;
