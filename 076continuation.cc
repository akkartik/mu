//: Continuations are a powerful primitive for constructing advanced kinds of
//: control *policies* like back-tracking.
//:
//: In Mu, continuations are first-class and delimited, and are constructed
//: out of two primitives:
//:
//:  * 'call-with-continuation-mark' marks the top of the call stack and then
//:    calls the provided recipe.
//:  * 'return-continuation-until-mark' copies the top of the stack
//:    until the mark, and returns it as the result of
//:    'call-with-continuation-mark' (which might be a distant ancestor on the
//:    call stack; intervening calls don't return)
//:
//: The resulting slice of the stack can now be called just like a regular
//: recipe.
//:
//: See the example programs continuation*.mu to get a sense for the
//: possibilities.
//:
//: Refinements:
//:  * You can call a single continuation multiple times, and it will preserve
//:    the state of its local variables at each stack frame between calls.
//:    The stack frames of a continuation are not destroyed until the
//:    continuation goes out of scope. See continuation2.mu.
//:  * 'return-continuation-until-mark' doesn't consume the mark, so you can
//:    return multiple continuations based on a single mark. In combination
//:    with the fact that 'return-continuation-until-mark' can return from
//:    regular calls, just as long as there was an earlier call to
//:    'call-with-continuation-mark', this gives us a way to create resumable
//:    recipes. See continuation3.mu.
//:  * 'return-continuation-until-mark' can take ingredients to return just
//:    like other 'return' instructions. It just implicitly also returns a
//:    continuation as the first result. See continuation4.mu.
//:  * Conversely, you can pass ingredients to a continuation when calling it,
//:    to make it available to products of 'return-continuation-until-mark'.
//:    See continuation5.mu.
//:
//: Inspired by James and Sabry, "Yield: Mainstream delimited continuations",
//: Workshop on the Theory and Practice of Delimited Continuations, 2011.
//: https://www.cs.indiana.edu/~sabry/papers/yield.pdf
//:
//: Caveats:
//:  * At the moment we can't statically type-check continuations. So we raise
//:    runtime errors for a call that doesn't return a continuation when the
//:    caller expects, or one that returns a continuation when the caller
//:    doesn't expect it. This shouldn't cause memory corruption, though.
//:    There should still be no way to lookup addresses that aren't allocated.

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
    2:number <- call 1:continuation, 2:number  # jump to 'return-continuation-until-mark' below
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
  22:number <- return-continuation-until-mark
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
:(before "End Types")
struct delimited_continuation {
  call_stack frames;
  int nrefs;
  delimited_continuation(call_stack::iterator begin, call_stack::iterator end) :frames(call_stack(begin, end)), nrefs(0) {}
};
:(before "End Globals")
map<long long int, delimited_continuation> Delimited_continuation;
long long int Next_delimited_continuation_id = 1;  // 0 is null just like an address
:(before "End Reset")
Delimited_continuation.clear();
Next_delimited_continuation_id = 1;

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
  trace("run") << "creating continuation " << Next_delimited_continuation_id << end();
  put(Delimited_continuation, Next_delimited_continuation_id, delimited_continuation(Current_routine->calls.begin(), base));
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
  // return any other ingredients passed in
  copy(ingredients.begin(), ingredients.end(), inserter(products, products.end()));
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
if (is_mu_continuation(current_instruction().ingredients.at(0))) {
  // copy multiple calls on to current call stack
  assert(scalar(ingredients.at(0)));
  trace("run") << "calling continuation " << ingredients.at(0).at(0) << end();
  if (!contains_key(Delimited_continuation, ingredients.at(0).at(0)))
    raise << maybe(current_recipe_name()) << "no such delimited continuation " << current_instruction().ingredients.at(0).original_string << '\n' << end();
  const call_stack& new_frames = get(Delimited_continuation, ingredients.at(0).at(0)).frames;
  for (call_stack::const_reverse_iterator p = new_frames.rbegin(); p != new_frames.rend(); ++p) {
    Current_routine->calls.push_front(*p);
    // ensure that the presence of a continuation keeps its stack frames from being reclaimed
    increment_refcount(Current_routine->calls.front().default_space);
  }
  if (Trace_stream) {
    Trace_stream->callstack_depth += SIZE(new_frames);
    trace("trace") << "calling delimited continuation; growing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  // no call housekeeping; continuations don't support next-ingredient
  copy(/*drop continuation*/++ingredients.begin(), ingredients.end(), inserter(products, products.begin()));
  break;  // record results of resuming 'return-continuation-until-mark' instruction
}

:(scenario continuations_can_return_values)
def main [
  local-scope
  k:continuation, 1:num/raw <- call-with-continuation-mark f
]
def f [
  local-scope
  g
]
def g [
  local-scope
  return-continuation-until-mark 34
  stash [continuation called]
]
# entering main
+mem: new alloc: 1000
+run: {k: "continuation"}, {1: "number", "raw": ()} <- call-with-continuation-mark {f: "recipe-literal"}
# entering f
+mem: new alloc: 1004
# entering g
+mem: new alloc: 1007
# return control to main
+run: return-continuation-until-mark {34: "literal"}
# no allocs abandoned yet
+mem: storing 34 in location 1
# end of main
# make sure no memory leaks..
+mem: trying to reclaim local k:continuation
+mem: automatically abandoning 1007
+mem: automatically abandoning 1004
+mem: automatically abandoning 1000
# ..even though we never called the continuation
-app: continuation called

//: Ensure that the presence of a continuation keeps its stack frames from being reclaimed.

:(scenario continuations_preserve_local_scopes)
def main [
  local-scope
  k:continuation <- call-with-continuation-mark f
  call k
  return 34
]
def f [
  local-scope
  g
]
def g [
  local-scope
  return-continuation-until-mark
  add 1, 1
]
# entering main
+mem: new alloc: 1000
+run: {k: "continuation"} <- call-with-continuation-mark {f: "recipe-literal"}
# entering f
+mem: new alloc: 1004
# entering g
+mem: new alloc: 1007
# return control to main
+run: return-continuation-until-mark
# no allocs abandoned yet
# finish running main
+run: call {k: "continuation"}
+run: add {1: "literal"}, {1: "literal"}
+run: return {34: "literal"}
# now k is reclaimed
+mem: trying to reclaim local k:continuation
# at this point all allocs in the continuation are abandoned
+mem: automatically abandoning 1007
+mem: automatically abandoning 1004
# finally the alloc for main is abandoned
+mem: automatically abandoning 1000

:(before "End Increment Refcounts(canonized_x)")
if (is_mu_continuation(canonized_x)) {
  int continuation_id = data.at(0);
  if (continuation_id == 0) return;
  if (!contains_key(Delimited_continuation, continuation_id)) {
    raise << maybe(current_recipe_name()) << "missing delimited continuation: " << canonized_x.name << '\n';
    return;
  }
  delimited_continuation& curr = get(Delimited_continuation, continuation_id);
  trace("run") << "incrementing refcount of continuation " << continuation_id << ": " << curr.nrefs << " -> " << 1+curr.nrefs << end();
  ++curr.nrefs;
  return;
}

:(before "End Decrement Refcounts(canonized_x)")
if (is_mu_continuation(canonized_x)) {
  int continuation_id = get_or_insert(Memory, canonized_x.value);
  if (continuation_id == 0) return;
  delimited_continuation& curr = get(Delimited_continuation, continuation_id);
  assert(curr.nrefs > 0);
  --curr.nrefs;
  trace("run") << "decrementing refcount of continuation " << continuation_id << ": " << 1+curr.nrefs << " -> " << curr.nrefs << end();
  if (curr.nrefs > 0) return;
  trace("run") << "reclaiming continuation " << continuation_id << end();
  // temporarily push the stack frames for the continuation to the call stack before reclaiming their spaces
  // (because reclaim_default_space() relies on the default-space being reclaimed being at the top of the stack)
  for (call_stack::const_iterator p = curr.frames.begin(); p != curr.frames.end(); ++p) {
    Current_routine->calls.push_front(*p);
    reclaim_default_space();
    Current_routine->calls.pop_front();
  }
  Delimited_continuation.erase(continuation_id);
  return;
}

:(scenario continuations_can_be_copied)
def main [
  local-scope
  k:continuation <- call-with-continuation-mark f
  k2:continuation <- copy k
  # reclaiming k and k2 shouldn't delete f's local scope twice
]
def f [
  local-scope
  load-ingredients
  return-continuation-until-mark
  return 0
]
$error: 0

:(code)
bool is_mu_continuation(reagent/*copy*/ x) {
  canonize_type(x);
  return x.type && x.type->atom && x.type->value == get(Type_ordinal, "continuation");
}

// helper for debugging
void dump(const int continuation_id) {
  if (!contains_key(Delimited_continuation, continuation_id)) {
    raise << "missing delimited continuation: " << continuation_id << '\n' << end();
    return;
  }
  delimited_continuation& curr = get(Delimited_continuation, continuation_id);
  dump(curr.frames);
}
