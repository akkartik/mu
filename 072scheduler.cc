//: Run a second routine concurrently using 'start-running', without any
//: guarantees on how the operations in each are interleaved with each other.

:(scenario scheduler)
def f1 [
  start-running f2
  # wait for f2 to run
  {
    jump-unless 1:num, -1
  }
]
def f2 [
  1:num <- copy 1
]
+schedule: f1
+schedule: f2

//: first, add a deadline to run(routine)
:(before "End Globals")
int Scheduling_interval = 500;
:(before "End routine Fields")
int instructions_run_this_scheduling_slice;
:(before "End routine Constructor")
instructions_run_this_scheduling_slice = 0;
:(before "Running One Instruction")
 ++Current_routine->instructions_run_this_scheduling_slice;
:(replace{} "bool should_continue_running(const routine* current_routine)")
bool should_continue_running(const routine* current_routine) {
  assert(current_routine == Current_routine);  // argument passed in just to make caller readable above
  return Current_routine->state == RUNNING
      && Current_routine->instructions_run_this_scheduling_slice < Scheduling_interval;
}
:(after "stop_running_current_routine:")
// Reset instructions_run_this_scheduling_slice
Current_routine->instructions_run_this_scheduling_slice = 0;

//: now the rest of the scheduler is clean

:(before "struct routine")
enum routine_state {
  RUNNING,
  COMPLETED,
  // End routine States
};
:(before "End routine Fields")
enum routine_state state;
:(before "End routine Constructor")
state = RUNNING;

:(before "End Globals")
vector<routine*> Routines;
int Current_routine_index = 0;
:(before "End Setup")
Scheduling_interval = 500;
Routines.clear();
:(replace{} "void run(const recipe_ordinal r)")
void run(const recipe_ordinal r) {
  run(new routine(r));
}

:(code)
void run(routine* rr) {
  Routines.push_back(rr);
  Current_routine_index = 0, Current_routine = Routines.at(0);
  while (!all_routines_done()) {
    skip_to_next_routine();
    assert(Current_routine);
    assert(Current_routine->state == RUNNING);
    trace(9990, "schedule") << current_routine_label() << end();
    run_current_routine();
    // Scheduler State Transitions
    if (Current_routine->completed())
      Current_routine->state = COMPLETED;
    // End Scheduler State Transitions

    // Scheduler Cleanup
    // End Scheduler Cleanup
  }
  // End Run Routine
}

bool all_routines_done() {
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->state == RUNNING)
      return false;
  }
  return true;
}

// skip Current_routine_index past non-RUNNING routines
void skip_to_next_routine() {
  assert(!Routines.empty());
  assert(Current_routine_index < SIZE(Routines));
  for (int i = (Current_routine_index+1)%SIZE(Routines);  i != Current_routine_index;  i = (i+1)%SIZE(Routines)) {
    if (Routines.at(i)->state == RUNNING) {
      Current_routine_index = i;
      Current_routine = Routines.at(i);
      return;
    }
  }
}

string current_routine_label() {
  return routine_label(Current_routine);
}

string routine_label(routine* r) {
  ostringstream result;
  const call_stack& calls = r->calls;
  for (call_stack::const_iterator p = calls.begin();  p != calls.end();  ++p) {
    if (p != calls.begin()) result << '/';
    result << get(Recipe, p->running_recipe).name;
  }
  return result.str();
}

:(before "End Teardown")
for (int i = 0;  i < SIZE(Routines);  ++i)
  delete Routines.at(i);
Routines.clear();
Current_routine = NULL;

//: special case for the very first routine
:(replace{} "void run_main(int argc, char* argv[])")
void run_main(int argc, char* argv[]) {
  recipe_ordinal r = get(Recipe_ordinal, "main");
  assert(r);
  routine* main_routine = new routine(r);
  // pass in commandline args as ingredients to main
  // todo: test this
  Current_routine = main_routine;
  for (int i = 1;  i < argc;  ++i) {
    vector<double> arg;
    arg.push_back(new_mu_text(argv[i]));
    assert(get(Memory, arg.back()) == 0);
    put(Memory, arg.back(), 1);  // update refcount
    current_call().ingredient_atoms.push_back(arg);
  }
  run(main_routine);
}

//:: To schedule new routines to run, call 'start-running'.

//: 'start-running' will return a unique id for the routine that was created.
//: routine id is a number, but don't do any arithmetic on it
:(before "End routine Fields")
int id;
:(before "End Globals")
int Next_routine_id = 1;
:(before "End Setup")
Next_routine_id = 1;
:(before "End routine Constructor")
id = Next_routine_id;
++Next_routine_id;

//: routines save the routine that spawned them
:(before "End routine Fields")
// todo: really should be routine_id, but that's less efficient.
int parent_index;  // only < 0 if there's no parent_index
:(before "End routine Constructor")
parent_index = -1;

:(before "End Primitive Recipe Declarations")
START_RUNNING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "start-running", START_RUNNING);
:(before "End Primitive Recipe Checks")
case START_RUNNING: {
  if (inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'start-running' requires at least one ingredient: the recipe to start running\n" << end();
    break;
  }
  if (!is_mu_recipe(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'start-running' should be a recipe, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case START_RUNNING: {
  routine* new_routine = new routine(ingredients.at(0).at(0));
  new_routine->parent_index = Current_routine_index;
  // populate ingredients
  for (int i = 1;  i < SIZE(current_instruction().ingredients);  ++i) {
    new_routine->calls.front().ingredient_atoms.push_back(ingredients.at(i));
    reagent/*copy*/ ingredient = current_instruction().ingredients.at(i);
    canonize_type(ingredient);
    new_routine->calls.front().ingredients.push_back(ingredient);
    // End Populate start-running Ingredient
  }
  Routines.push_back(new_routine);
  products.resize(1);
  products.at(0).push_back(new_routine->id);
  break;
}

:(scenario scheduler_runs_single_routine)
% Scheduling_interval = 1;
def f1 [
  1:num <- copy 0
  2:num <- copy 0
]
+schedule: f1
+run: {1: "number"} <- copy {0: "literal"}
+schedule: f1
+run: {2: "number"} <- copy {0: "literal"}

:(scenario scheduler_interleaves_routines)
% Scheduling_interval = 1;
def f1 [
  start-running f2
  1:num <- copy 0
  2:num <- copy 0
]
def f2 [
  3:num <- copy 0
  4:num <- copy 0
]
+schedule: f1
+run: start-running {f2: "recipe-literal"}
+schedule: f2
+run: {3: "number"} <- copy {0: "literal"}
+schedule: f1
+run: {1: "number"} <- copy {0: "literal"}
+schedule: f2
+run: {4: "number"} <- copy {0: "literal"}
+schedule: f1
+run: {2: "number"} <- copy {0: "literal"}

:(scenario start_running_takes_ingredients)
def f1 [
  start-running f2, 3
  # wait for f2 to run
  {
    jump-unless 1:num, -1
  }
]
def f2 [
  1:num <- next-ingredient
  2:num <- add 1:num, 1
]
+mem: storing 4 in location 2

//: type-checking for 'start-running'

:(scenario start_running_checks_types)
% Hide_errors = true;
def f1 [
  start-running f2, 3
]
def f2 n:&:num [
]
+error: f1: ingredient 0 has the wrong type at 'start-running f2, 3'

// 'start-running' only uses the ingredients of the callee, not its products
:(before "End is_indirect_call_with_ingredients Special-cases")
if (r == START_RUNNING) return true;

//: more complex: refcounting management when starting up new routines

:(scenario start_running_immediately_updates_refcounts_of_ingredients)
% Scheduling_interval = 1;
def main [
  local-scope
  create-new-routine
  # padding to make sure we run new-routine before returning
  dummy:num <- copy 0
  dummy:num <- copy 0
]
def create-new-routine [
  local-scope
  n:&:num <- new number:type
  *n <- copy 34
  start-running new-routine, n
  # refcount of n decremented
]
def new-routine n:&:num [
  local-scope
  load-ingredients
  1:num/raw <- copy *n
]
# check that n wasn't reclaimed when create-new-routine returned
+mem: storing 34 in location 1

//: to support the previous scenario we'll increment refcounts for all call
//: ingredients right at call time, and stop incrementing refcounts inside
//: next-ingredient
:(before "End Populate Call Ingredient")
increment_any_refcounts(ingredient, ingredients.at(i));
:(before "End Populate start-running Ingredient")
increment_any_refcounts(ingredient, ingredients.at(i));
:(before "End should_update_refcounts_in_write_memory Special-cases For Primitives")
if (inst.operation == NEXT_INGREDIENT || inst.operation == NEXT_INGREDIENT_WITHOUT_TYPECHECKING) {
  if (space_index(inst.products.at(0)) > 0) return true;
  if (has_property(inst.products.at(0), "raw")) return true;
  return false;
}

// ensure this works with indirect calls using 'call' as well
:(scenario start_running_immediately_updates_refcounts_of_ingredients_of_indirect_calls)
% Scheduling_interval = 1;
def main [
  local-scope
  n:&:num <- new number:type
  *n <- copy 34
  call f1, n
  1:num/raw <- copy *n
]
def f1 n:&:num [
  local-scope
  load-ingredients
]
# check that n wasn't reclaimed when f1 returned
+mem: storing 34 in location 1

:(scenario next_ingredient_never_leaks_refcounts)
def create-space n:&:num -> default-space:space [
  default-space <- new location:type, 2
  load-ingredients
]
def use-space [
  local-scope
  0:space/names:create-space <- next-ingredient
  n:&:num/space:1 <- next-ingredient  # should decrement refcount
  *n/space:1 <- copy 34
  n2:num <- add *n/space:1, 1
  reply n2
]
def main [
  local-scope
  n:&:num <- copy 12000/unsafe  # pretend allocation with a known address
  *n <- copy 23
  space:space <- create-space n
  n2:&:num <- copy 13000/unsafe
  n3:num <- use-space space, n2
]
+run: {n: ("address" "number"), "space": "1"} <- next-ingredient
+mem: decrementing refcount of 12000: 2 -> 1
+run: {n: ("address" "number"), "space": "1", "lookup": ()} <- copy {34: "literal"}

//: back to testing 'start-running'

:(scenario start_running_returns_routine_id)
def f1 [
  1:num <- start-running f2
]
def f2 [
  12:num <- copy 44
]
+mem: storing 2 in location 1

//: this scenario will require some careful setup in escaped C++
//: (straining our tangle capabilities to near-breaking point)
:(scenario scheduler_skips_completed_routines)
% recipe_ordinal f1 = load("recipe f1 [\n1:num <- copy 0\n]\n").front();
% recipe_ordinal f2 = load("recipe f2 [\n2:num <- copy 0\n]\n").front();
% Routines.push_back(new routine(f1));  // f1 meant to run
% Routines.push_back(new routine(f2));
% Routines.back()->state = COMPLETED;  // f2 not meant to run
# must have at least one routine without escaping
def f3 [
  3:num <- copy 0
]
# by interleaving '+' lines with '-' lines, we allow f1 and f3 to run in any order
+schedule: f1
+mem: storing 0 in location 1
-schedule: f2
-mem: storing 0 in location 2
+schedule: f3
+mem: storing 0 in location 3

:(scenario scheduler_starts_at_middle_of_routines)
% Routines.push_back(new routine(COPY));
% Routines.back()->state = COMPLETED;
def f1 [
  1:num <- copy 0
  2:num <- copy 0
]
+schedule: f1
-run: idle

//:: Errors in a routine cause it to terminate.

:(scenario scheduler_terminates_routines_after_errors)
% Hide_errors = true;
% Scheduling_interval = 2;
def f1 [
  start-running f2
  1:num <- copy 0
  2:num <- copy 0
]
def f2 [
  # divide by 0 twice
  3:num <- divide-with-remainder 4, 0
  4:num <- divide-with-remainder 4, 0
]
# f2 should stop after first divide by 0
+error: f2: divide by zero in '3:num <- divide-with-remainder 4, 0'
-error: f2: divide by zero in '4:num <- divide-with-remainder 4, 0'

:(after "operator<<(ostream& os, unused end)")
  if (Trace_stream && Trace_stream->curr_label == "error" && Current_routine) {
    Current_routine->state = COMPLETED;
  }

//:: Routines are marked completed when their parent completes.

:(scenario scheduler_kills_orphans)
def main [
  start-running f1
  # f1 never actually runs because its parent completes without waiting for it
]
def f1 [
  1:num <- copy 0
]
-schedule: f1

:(before "End Scheduler Cleanup")
for (int i = 0;  i < SIZE(Routines);  ++i) {
  if (Routines.at(i)->state == COMPLETED) continue;
  if (Routines.at(i)->parent_index < 0) continue;  // root thread
  // structured concurrency: http://250bpm.com/blog:71
  if (has_completed_parent(i)) {
    Routines.at(i)->state = COMPLETED;
  }
}

:(code)
bool has_completed_parent(int routine_index) {
  for (int j = routine_index;  j >= 0;  j = Routines.at(j)->parent_index) {
    if (Routines.at(j)->state == COMPLETED)
      return true;
  }
  return false;
}

//:: 'routine-state' can tell if a given routine id is running

:(scenario routine_state_test)
% Scheduling_interval = 2;
def f1 [
  1:num/child-id <- start-running f2
  12:num <- copy 0  # race condition since we don't care about location 12
  # thanks to Scheduling_interval, f2's one instruction runs in between here and completes
  2:num/state <- routine-state 1:num/child-id
]
def f2 [
  12:num <- copy 0
  # trying to run a second instruction marks routine as completed
]
# recipe f2 should be in state COMPLETED
+mem: storing 1 in location 2

:(before "End Primitive Recipe Declarations")
ROUTINE_STATE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "routine-state", ROUTINE_STATE);
:(before "End Primitive Recipe Checks")
case ROUTINE_STATE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'routine-state' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'routine-state' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ROUTINE_STATE: {
  int id = ingredients.at(0).at(0);
  int result = -1;
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->id == id) {
      result = Routines.at(i)->state;
      break;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

//:: miscellaneous helpers

:(before "End Primitive Recipe Declarations")
STOP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "stop", STOP);
:(before "End Primitive Recipe Checks")
case STOP: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'stop' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'stop' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case STOP: {
  int id = ingredients.at(0).at(0);
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->id == id) {
      Routines.at(i)->state = COMPLETED;
      break;
    }
  }
  break;
}

:(before "End Primitive Recipe Declarations")
_DUMP_ROUTINES,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$dump-routines", _DUMP_ROUTINES);
:(before "End Primitive Recipe Checks")
case _DUMP_ROUTINES: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _DUMP_ROUTINES: {
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    cerr << i << ": " << Routines.at(i)->id << ' ' << Routines.at(i)->state << ' ' << Routines.at(i)->parent_index << '\n';
  }
  break;
}

//: support for stopping routines after some number of cycles

:(scenario routine_discontinues_past_limit)
% Scheduling_interval = 2;
def f1 [
  1:num/child-id <- start-running f2
  limit-time 1:num/child-id, 10
  # padding loop just to make sure f2 has time to completed
  2:num <- copy 20
  2:num <- subtract 2:num, 1
  jump-if 2:num, -2:offset
]
def f2 [
  jump -1:offset  # run forever
  $print [should never get here], 10/newline
]
# f2 terminates
+schedule: discontinuing routine 2

:(before "End routine States")
DISCONTINUED,
:(before "End Scheduler State Transitions")
if (Current_routine->limit >= 0) {
  if (Current_routine->limit <= Scheduling_interval) {
    trace(9999, "schedule") << "discontinuing routine " << Current_routine->id << end();
    Current_routine->state = DISCONTINUED;
    Current_routine->limit = 0;
  }
  else {
    Current_routine->limit -= Scheduling_interval;
  }
}

:(before "End Test Teardown")
if (Passed && any_routines_with_error())
  raise << "some routines died with errors\n" << end();
:(before "End Mu Test Teardown")
if (Passed && any_routines_with_error())
  raise << Current_scenario->name << ": some routines died with errors\n" << end();

:(code)
bool any_routines_with_error() {
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->state == DISCONTINUED)
      return true;
  }
  return false;
}

:(before "End routine Fields")
int limit;
:(before "End routine Constructor")
limit = -1;  /* no limit */

:(before "End Primitive Recipe Declarations")
LIMIT_TIME,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "limit-time", LIMIT_TIME);
:(before "End Primitive Recipe Checks")
case LIMIT_TIME: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'limit-time' requires exactly two ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'limit-time' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'limit-time' should be a number (of instructions to run for), but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case LIMIT_TIME: {
  int id = ingredients.at(0).at(0);
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->id == id) {
      Routines.at(i)->limit = ingredients.at(1).at(0);
      break;
    }
  }
  break;
}

:(before "End routine Fields")
int instructions_run;
:(before "End routine Constructor")
instructions_run = 0;
:(before "Reset instructions_run_this_scheduling_slice")
Current_routine->instructions_run += Current_routine->instructions_run_this_scheduling_slice;
:(before "End Primitive Recipe Declarations")
NUMBER_OF_INSTRUCTIONS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "number-of-instructions", NUMBER_OF_INSTRUCTIONS);
:(before "End Primitive Recipe Checks")
case NUMBER_OF_INSTRUCTIONS: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'number-of-instructions' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'number-of-instructions' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case NUMBER_OF_INSTRUCTIONS: {
  int id = ingredients.at(0).at(0);
  int result = -1;
  for (int i = 0;  i < SIZE(Routines);  ++i) {
    if (Routines.at(i)->id == id) {
      result = Routines.at(i)->instructions_run;
      break;
    }
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario number_of_instructions)
def f1 [
  10:num/child-id <- start-running f2
  {
    loop-unless 20:num
  }
  11:num <- number-of-instructions 10:num
]
def f2 [
  # 2 instructions worth of work
  1:num <- copy 34
  20:num <- copy 1
]
# f2 runs an extra instruction for the implicit return added by the
# fill_in_reply_ingredients transform
+mem: storing 3 in location 11

:(scenario number_of_instructions_across_multiple_scheduling_intervals)
% Scheduling_interval = 1;
def f1 [
  10:num/child-id <- start-running f2
  {
    loop-unless 20:num
  }
  11:num <- number-of-instructions 10:num
]
def f2 [
  # 4 instructions worth of work
  1:num <- copy 34
  2:num <- copy 1
  2:num <- copy 3
  20:num <- copy 1
]
# f2 runs an extra instruction for the implicit return added by the
# fill_in_reply_ingredients transform
+mem: storing 5 in location 11

//:: make sure that each routine gets a different alloc to start

:(scenario new_concurrent)
def f1 [
  start-running f2
  1:&:num/raw <- new number:type
  # wait for f2 to complete
  {
    loop-unless 4:num/raw
  }
]
def f2 [
  2:&:num/raw <- new number:type
  # hack: assumes scheduler implementation
  3:bool/raw <- equal 1:&:num/raw, 2:&:num/raw
  # signal f2 complete
  4:num/raw <- copy 1
]
+mem: storing 0 in location 3
