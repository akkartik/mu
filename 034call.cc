//: So far the recipes we define can't run each other. Let's fix that.

:(scenario calling_recipe)
recipe main [
  f
]
recipe f [
  3:number <- add 2, 2
]
+mem: storing 4 in location 3

:(scenario return_on_fallthrough)
recipe main [
  f
  1:number <- copy 0
  2:number <- copy 0
  3:number <- copy 0
]
recipe f [
  4:number <- copy 0
  5:number <- copy 0
]
+run: f
# running f
+run: 4:number <- copy 0
+run: 5:number <- copy 0
# back out to main
+run: 1:number <- copy 0
+run: 2:number <- copy 0
+run: 3:number <- copy 0

:(before "struct routine {")
// Everytime a recipe runs another, we interrupt it and start running the new
// recipe. When that finishes, we continue this one where we left off.
// This requires maintaining a 'stack' of interrupted recipes or 'calls'.
struct call {
  recipe_ordinal running_recipe;
  long long int running_step_index;
  // End call Fields
  call(recipe_ordinal r) {
    running_recipe = r;
    running_step_index = 0;
    // End call Constructor
  }
  ~call() {
    // End call Destructor
  }
};
typedef list<call> call_stack;

:(replace{} "struct routine")
struct routine {
  call_stack calls;
  // End routine Fields
  routine(recipe_ordinal r);
  bool completed() const;
  const vector<instruction>& steps() const;
};
:(code)
routine::routine(recipe_ordinal r) {
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace(9999, "trace") << "new routine; incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  calls.push_front(call(r));
  // End routine Constructor
}

:(code)
inline call& current_call() {
  return Current_routine->calls.front();
}

//:: now update routine's helpers

:(replace{} "inline long long int& current_step_index()")
inline long long int& current_step_index() {
  assert(!Current_routine->calls.empty());
  return current_call().running_step_index;
}
:(replace{} "inline const string& current_recipe_name()")
inline const string& current_recipe_name() {
  assert(!Current_routine->calls.empty());
  return get(Recipe, current_call().running_recipe).name;
}
:(replace{} "inline const instruction& current_instruction()")
inline const instruction& current_instruction() {
  assert(!Current_routine->calls.empty());
  return to_instruction(current_call());
}
:(code)
inline const instruction& to_instruction(const call& call) {
  return get(Recipe, call.running_recipe).steps.at(call.running_step_index);
}

:(after "Defined Recipe Checks")
// not a primitive; check that it's present in the book of recipes
if (!contains_key(Recipe, inst.operation)) {
  raise_error << maybe(get(Recipe, r).name) << "undefined operation in '" << inst.to_string() << "'\n" << end();
  break;
}
:(replace{} "default:" following "End Primitive Recipe Implementations")
default: {
  const instruction& call_instruction = current_instruction();
  if (Recipe.find(current_instruction().operation) == Recipe.end()) {  // duplicate from Checks
    // stop running this instruction immediately
    ++current_step_index();
    continue;
  }
  // not a primitive; look up the book of recipes
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace(9999, "trace") << "incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  Current_routine->calls.push_front(call(current_instruction().operation));
  finish_call_housekeeping(call_instruction, ingredients);
  continue;  // not done with caller; don't increment step_index of caller
}
:(code)
void finish_call_housekeeping(const instruction& call_instruction, const vector<vector<double> >& ingredients) {
  // End Call Housekeeping
}

:(scenario calling_undefined_recipe_fails)
% Hide_errors = true;
recipe main [
  foo
]
+error: main: undefined operation in 'foo '

:(scenario calling_undefined_recipe_handles_missing_result)
% Hide_errors = true;
recipe main [
  x:number <- foo
]
+error: main: undefined operation in 'x:number <- foo '

//:: finally, we need to fix the termination conditions for the run loop

:(replace{} "inline bool routine::completed() const")
inline bool routine::completed() const {
  return calls.empty();
}

inline const vector<instruction>& routine::steps() const {
  assert(!calls.empty());
  return get(Recipe, calls.front().running_recipe).steps;
}

:(before "Running One Instruction")
// when we reach the end of one call, we may reach the end of the one below
// it, and the one below that, and so on
while (current_step_index() >= SIZE(Current_routine->steps())) {
  // Falling Through End Of Recipe
  if (Trace_stream) {
    trace(9999, "trace") << "fall-through: exiting " << current_recipe_name() << "; decrementing callstack depth from " << Trace_stream->callstack_depth << end();
    --Trace_stream->callstack_depth;
    assert(Trace_stream->callstack_depth >= 0);
  }
  Current_routine->calls.pop_front();
  if (Current_routine->calls.empty()) return;
  // Complete Call Fallthrough
  // todo: fail if no products returned
  ++current_step_index();
}
