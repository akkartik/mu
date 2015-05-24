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
//: In mu, this is constructed out of three primitives:
//:   'reset-and-call' lays down a 'reset mark' on the call stack
//:   'current-delimited_continuation' copies the top of the stack until the reset mark
//:   'call-continuation' calls a delimited continuation like a normal recipe

//: todo: come up with a simpler, more obviously correct test
:(scenario delimited_continuation)
# too hacky to distinguish initial call from later calls by #ingredients?
recipe main [
#?   $start-tracing
  1:continuation, 2:number <- reset-and-call f:recipe  # initial call without ingredients
  2:number <- copy 5:literal
  {
    1:continuation, 2:number <- call-continuation 1:continuation, 2:number  # subsequent calls
    3:boolean <- greater-or-equal 2:number, 8:literal
    break-if 3:boolean
    loop
  }
]

recipe f [
  11:continuation, 12:number <- g
  reply 11:continuation, 12:number
]

# when constructing the continuation, just returns 0
# on subsequent calls of the continuation, increments the number passed in
recipe g [
  21:continuation <- current-delimited-continuation
  # calls of the continuation start from here
  22:number, 23:boolean/found? <- next-ingredient
  {
    break-if 23:boolean/found?
    reply 21:continuation, 0:literal
  }
  22:number <- add 22:number, 1:literal
  reply 21:continuation, 22:number
]
+mem: storing 0 in location 2
-mem: storing 4 in location 2
+mem: storing 5 in location 2
+mem: storing 6 in location 2
+mem: storing 7 in location 2
+mem: storing 8 in location 2
-mem: storing 9 in location 2

//: push a variable recipe on the call stack
//: todo: doesn't really belong in this layer

:(before "End Primitive Recipe Declarations")
CALL,
:(before "End Primitive Recipe Numbers")
Recipe_number["call"] = CALL;
:(before "End Primitive Recipe Implementations")
case CALL: {
  ++Callstack_depth;
  assert(Callstack_depth < 9000);  // 9998-101 plus cushion
  call callee(Recipe_number[current_instruction().ingredients.at(0).name]);
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    callee.ingredient_atoms.push_back(ingredients.at(i));
  }
  Current_routine->calls.push_front(callee);
  continue;  // not done with caller; don't increment current_step_index()
}

// 'reset-and-call' is like 'call' except it inserts a label to the call stack
// before performing the call
:(before "End call Fields")
bool is_reset;
:(before "End call Constructor")
is_reset = false;

//: like call, but mark the current call as a 'reset' call before pushing the next one on it

:(before "End Primitive Recipe Declarations")
RESET_AND_CALL,
:(before "End Primitive Recipe Numbers")
Recipe_number["reset-and-call"] = RESET_AND_CALL;
:(before "End Primitive Recipe Implementations")
case RESET_AND_CALL: {
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

//: create a copy of the slice of current call stack until a 'reset' call
//: todo: implement delimited continuations in mu's memory
:(before "End Globals")
map<long long int, call_stack> Delimited_continuation;
long long int Next_delimited_continuation_id = 0;
:(before "End Setup")
Delimited_continuation.clear();
Next_delimited_continuation_id = 0;

:(before "End Primitive Recipe Declarations")
CURRENT_DELIMITED_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["current-delimited-continuation"] = CURRENT_DELIMITED_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CURRENT_DELIMITED_CONTINUATION: {
  // copy the current call stack until the first reset call
  for (call_stack::iterator p = Current_routine->calls.begin(); p != Current_routine->calls.end(); ++p) {
//?     cerr << "copying " << Recipe[p->running_recipe].name << '\n'; //? 1
    if (p->is_reset) break;
    Delimited_continuation[Next_delimited_continuation_id].push_back(*p);  // deep copy because calls have no pointers
  }
  // make sure calling the copy doesn't spawn the same continuation again
  ++Delimited_continuation[Next_delimited_continuation_id].front().running_step_index;
  products.resize(1);
  products.at(0).push_back(Next_delimited_continuation_id);
  ++Next_delimited_continuation_id;
  trace("current-continuation") << "new continuation " << Next_continuation_id;
  break;
}

//: copy slice of calls back on to current call stack
:(before "End Primitive Recipe Declarations")
CALL_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["call-continuation"] = CALL_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CALL_CONTINUATION: {
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
