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
type_number continuation = Type_number["continuation"] = Next_type_number++;
Type[continuation].name = "continuation";

:(before "End Primitive Recipe Declarations")
CURRENT_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["current-continuation"] = CURRENT_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CURRENT_CONTINUATION: {
  // copy the current call stack
  Continuation[Next_continuation_id] = Current_routine->calls;  // deep copy because calls have no pointers
  // make sure calling the copy doesn't spawn the same continuation again
  ++Continuation[Next_continuation_id].front().running_step_index;
  products.resize(1);
  products.at(0).push_back(Next_continuation_id);
  ++Next_continuation_id;
  trace("current-continuation") << "new continuation " << Next_continuation_id;
  break;
}

:(before "End Primitive Recipe Declarations")
CONTINUE_FROM,
:(before "End Primitive Recipe Numbers")
Recipe_number["continue-from"] = CONTINUE_FROM;
:(before "End Primitive Recipe Implementations")
case CONTINUE_FROM: {
  assert(scalar(ingredients.at(0)));
  long long int c = ingredients.at(0).at(0);
  Current_routine->calls = Continuation[c];  // deep copy because calls have no pointers
  // refresh instruction_counter to next instruction after current-continuation
  instruction_counter = current_step_index()+1;
  continue;  // skip the rest of this instruction
}

:(scenario continuation)
# simulate a loop using continuations
recipe main [
  1:number <- copy 0:literal
  2:continuation <- current-continuation
  {
#?     $print 1:number
    3:boolean <- greater-or-equal 1:number, 3:literal
    break-if 3:boolean
    1:number <- add 1:number, 1:literal
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
  1:number <- copy 0:literal
  2:continuation <- loop-body
  {
    3:boolean <- greater-or-equal 1:number, 3:literal
    break-if 3:boolean
    continue-from 2:continuation  # loop
  }
]

recipe loop-body [
  4:continuation <- current-continuation
  1:number <- add 1:number, 1:literal
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
  1:continuation <- create-delimited-continuation f:recipe 12:literal  # 12 is an argument to f
  2:number <- copy 5:literal
  {
    2:number <- call-delimited-continuation 1:continuation, 2:number  # 2 is an argument to g, the 'top' of the continuation
    3:boolean <- greater-or-equal 2:number, 8:literal
    break-if 3:boolean
    loop
  }
]

recipe f [
  11:number <- g
  reply 11:number
]

recipe g [
  reply-delimited-continuation
  # calls of the continuation start from here
  22:number <- next-ingredient
  22:number <- add 22:number, 1:literal
  reply 22:number
]
+run: 2:number <- copy 5:literal
+mem: storing 5 in location 2
+run: 2:number <- call-delimited-continuation 1:continuation, 2:number
+mem: storing 6 in location 2
+run: 2:number <- call-delimited-continuation 1:continuation, 2:number
+mem: storing 7 in location 2
+run: 2:number <- call-delimited-continuation 1:continuation, 2:number
+mem: storing 8 in location 2
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
Recipe_number["create-delimited-continuation"] = CREATE_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CREATE_DELIMITED_CONTINUATION: {
  Current_routine->calls.front().is_reset = true;
  ++Callstack_depth;
  assert(Callstack_depth < 9000);  // 9998-101 plus cushion
  call callee(Recipe_number[current_instruction().ingredients.at(0).name]);
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    callee.ingredient_atoms.push_back(ingredients.at(i));
  }
  Current_routine->calls.push_front(callee);
  continue;  // not done with caller; don't increment current_step_index()
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
Recipe_number["reply-delimited-continuation"] = REPLY_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case REPLY_DELIMITED_CONTINUATION: {
  // manual prototype containing '::'
  call_stack::iterator find_reset(call_stack& c);
  // copy the current call stack until the most recent 'reset' call
  call_stack::iterator reset = find_reset(Current_routine->calls);
  assert(reset != Current_routine->calls.end());
  Delimited_continuation[Next_delimited_continuation_id] = call_stack(Current_routine->calls.begin(), reset);
  while (Current_routine->calls.begin() != reset) Current_routine->calls.pop_front();
  // return it as the result of the 'reset' call
  products.resize(1);
  products.at(0).push_back(Next_delimited_continuation_id);
  ++Next_delimited_continuation_id;
  // refresh instruction_counter to caller's step_index
  instruction_counter = current_step_index();
  break;
}

:(code)
call_stack::iterator find_reset(call_stack& c) {
  for (call_stack::iterator p = c.begin(); p != c.end(); ++p)
    if (p->is_reset) return p;
  return c.end();
}

//: copy slice of calls back on to current call stack
:(before "End Primitive Recipe Declarations")
CALL_DELIMITED_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["call-delimited-continuation"] = CALL_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CALL_DELIMITED_CONTINUATION: {
  ++Callstack_depth;
  assert(Callstack_depth < 9000);  // 9998-101 plus cushion
  assert(scalar(ingredients.at(0)));
  assert(Delimited_continuation.find(ingredients.at(0).at(0)) != Delimited_continuation.end());
  const call_stack& new_calls = Delimited_continuation[ingredients.at(0).at(0)];
  for (call_stack::const_reverse_iterator p = new_calls.rbegin(); p != new_calls.rend(); ++p) {
//?     cerr << "copying back " << Recipe[p->running_recipe].name << '\n'; //? 1
    Current_routine->calls.push_front(*p);
  }
  for (long long int i = /*skip continuation*/1; i < SIZE(ingredients); ++i) {
//?     cerr << "copying ingredient " << i << ": " << ingredients.at(i).at(0) << '\n'; //? 1
    Current_routine->calls.front().ingredient_atoms.push_back(ingredients.at(i));
  }
  continue;  // not done with caller; don't increment current_step_index()
}
