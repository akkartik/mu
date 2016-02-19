//: Run a second routine concurrently using 'start-running', without any
//: guarantees on how the operations in each are interleaved with each other.

:(scenario scheduler)
recipe f1 [
  start-running f2
  # wait for f2 to run
  {
    jump-unless 1:number, -1
  }
]
recipe f2 [
  1:number <- copy 1
]
+schedule: f1
+schedule: f2

//: first, add a deadline to run(routine)
//: these changes are ugly and brittle; just close your nose and get through the next few lines
:(replace "void run_current_routine()")
void run_current_routine(long long int time_slice)
:(replace "while (!Current_routine->completed())" following "void run_current_routine(long long int time_slice)")
long long int ninstrs = 0;
while (Current_routine->state == RUNNING && ninstrs < time_slice)
:(after "Running One Instruction")
ninstrs++;

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
long long int Current_routine_index = 0;
long long int Scheduling_interval = 500;
:(before "End Setup")
Scheduling_interval = 500;
Routines.clear();
:(replace{} "void run(recipe_ordinal r)")
void run(recipe_ordinal r) {
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
    run_current_routine(Scheduling_interval);
    // Scheduler State Transitions
    if (Current_routine->completed())
      Current_routine->state = COMPLETED;
    // End Scheduler State Transitions

    // Scheduler Cleanup
    // End Scheduler Cleanup
  }
}

bool all_routines_done() {
  for (long long int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->state == RUNNING) {
      return false;
    }
  }
  return true;
}

// skip Current_routine_index past non-RUNNING routines
void skip_to_next_routine() {
  assert(!Routines.empty());
  assert(Current_routine_index < SIZE(Routines));
  for (long long int i = (Current_routine_index+1)%SIZE(Routines);  i != Current_routine_index;  i = (i+1)%SIZE(Routines)) {
    if (Routines.at(i)->state == RUNNING) {
      Current_routine_index = i;
      Current_routine = Routines.at(i);
      return;
    }
  }
}

string current_routine_label() {
  ostringstream result;
  const call_stack& calls = Current_routine->calls;
  for (call_stack::const_iterator p = calls.begin(); p != calls.end(); ++p) {
    if (p != calls.begin()) result << '/';
    result << get(Recipe, p->running_recipe).name;
  }
  return result.str();
}

:(before "End Teardown")
for (long long int i = 0; i < SIZE(Routines); ++i)
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
  for (long long int i = 1; i < argc; ++i) {
    vector<double> arg;
    arg.push_back(new_mu_string(argv[i]));
    current_call().ingredient_atoms.push_back(arg);
  }
  run(main_routine);
}

//:: To schedule new routines to run, call 'start-running'.

//: 'start-running' will return a unique id for the routine that was created.
//: routine id is a number, but don't do any arithmetic on it
:(before "End routine Fields")
long long int id;
:(before "End Globals")
long long int Next_routine_id = 1;
:(before "End Setup")
Next_routine_id = 1;
:(before "End routine Constructor")
id = Next_routine_id;
Next_routine_id++;

//: routines save the routine that spawned them
:(before "End routine Fields")
// todo: really should be routine_id, but that's less efficient.
long long int parent_index;  // only < 0 if there's no parent_index
:(before "End routine Constructor")
parent_index = -1;

:(before "End Primitive Recipe Declarations")
START_RUNNING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "start-running", START_RUNNING);
:(before "End Primitive Recipe Checks")
case START_RUNNING: {
  if (inst.ingredients.empty()) {
    raise_error << maybe(get(Recipe, r).name) << "'start-running' requires at least one ingredient: the recipe to start running\n" << end();
    break;
  }
  if (!is_mu_recipe(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'start-running' should be a recipe, but got " << to_string(inst.ingredients.at(0)) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case START_RUNNING: {
  routine* new_routine = new routine(ingredients.at(0).at(0));
  new_routine->parent_index = Current_routine_index;
  // populate ingredients
  for (long long int i = 1; i < SIZE(current_instruction().ingredients); ++i) {
    new_routine->calls.front().ingredient_atoms.push_back(ingredients.at(i));
    reagent ingredient = current_instruction().ingredients.at(i);
    canonize_type(ingredient);
    new_routine->calls.front().ingredients.push_back(ingredient);
  }
  Routines.push_back(new_routine);
  products.resize(1);
  products.at(0).push_back(new_routine->id);
  break;
}

:(scenario scheduler_runs_single_routine)
% Scheduling_interval = 1;
recipe f1 [
  1:number <- copy 0
  2:number <- copy 0
]
+schedule: f1
+run: 1:number <- copy 0
+schedule: f1
+run: 2:number <- copy 0

:(scenario scheduler_interleaves_routines)
% Scheduling_interval = 1;
recipe f1 [
  start-running f2
  1:number <- copy 0
  2:number <- copy 0
]
recipe f2 [
  3:number <- copy 0
  4:number <- copy 0
]
+schedule: f1
+run: start-running f2
+schedule: f2
+run: 3:number <- copy 0
+schedule: f1
+run: 1:number <- copy 0
+schedule: f2
+run: 4:number <- copy 0
+schedule: f1
+run: 2:number <- copy 0

:(scenario start_running_takes_ingredients)
recipe f1 [
  start-running f2, 3
  # wait for f2 to run
  {
    jump-unless 1:number, -1
  }
]
recipe f2 [
  1:number <- next-ingredient
  2:number <- add 1:number, 1
]
+mem: storing 4 in location 2

:(scenario start_running_returns_routine_id)
recipe f1 [
  1:number <- start-running f2
]
recipe f2 [
  12:number <- copy 44
]
+mem: storing 2 in location 1

//: this scenario will require some careful setup in escaped C++
//: (straining our tangle capabilities to near-breaking point)
:(scenario scheduler_skips_completed_routines)
% recipe_ordinal f1 = load("recipe f1 [\n1:number <- copy 0\n]\n").front();
% recipe_ordinal f2 = load("recipe f2 [\n2:number <- copy 0\n]\n").front();
% Routines.push_back(new routine(f1));  // f1 meant to run
% Routines.push_back(new routine(f2));
% Routines.back()->state = COMPLETED;  // f2 not meant to run
# must have at least one routine without escaping
recipe f3 [
  3:number <- copy 0
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
recipe f1 [
  1:number <- copy 0
  2:number <- copy 0
]
+schedule: f1
-run: idle

//:: Errors in a routine cause it to terminate.

:(scenario scheduler_terminates_routines_after_errors)
% Hide_errors = true;
% Scheduling_interval = 2;
recipe f1 [
  start-running f2
  1:number <- copy 0
  2:number <- copy 0
]
recipe f2 [
  # divide by 0 twice
  3:number <- divide-with-remainder 4, 0
  4:number <- divide-with-remainder 4, 0
]
# f2 should stop after first divide by 0
+error: f2: divide by zero in '3:number <- divide-with-remainder 4, 0'
-error: f2: divide by zero in '4:number <- divide-with-remainder 4, 0'

:(after "operator<<(ostream& os, unused end)")
  if (Trace_stream && Trace_stream->curr_label == "error" && Current_routine) {
    Current_routine->state = COMPLETED;
  }

//:: Routines are marked completed when their parent completes.

:(scenario scheduler_kills_orphans)
recipe main [
  start-running f1
  # f1 never actually runs because its parent completes without waiting for it
]
recipe f1 [
  1:number <- copy 0
]
-schedule: f1

:(before "End Scheduler Cleanup")
for (long long int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state == COMPLETED) continue;
  if (Routines.at(i)->parent_index < 0) continue;  // root thread
  if (has_completed_parent(i)) {
    Routines.at(i)->state = COMPLETED;
  }
}

:(code)
bool has_completed_parent(long long int routine_index) {
  for (long long int j = routine_index; j >= 0; j = Routines.at(j)->parent_index) {
    if (Routines.at(j)->state == COMPLETED)
      return true;
  }
  return false;
}

//:: 'routine-state' can tell if a given routine id is running

:(scenario routine_state_test)
% Scheduling_interval = 2;
recipe f1 [
  1:number/child-id <- start-running f2
  12:number <- copy 0  # race condition since we don't care about location 12
  # thanks to Scheduling_interval, f2's one instruction runs in between here and completes
  2:number/state <- routine-state 1:number/child-id
]
recipe f2 [
  12:number <- copy 0
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
    raise_error << maybe(get(Recipe, r).name) << "'routine-state' requires exactly one ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'routine-state' should be a routine id generated by 'start-running', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ROUTINE_STATE: {
  long long int id = ingredients.at(0).at(0);
  long long int result = -1;
  for (long long int i = 0; i < SIZE(Routines); ++i) {
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
RESTART,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "restart", RESTART);
:(before "End Primitive Recipe Checks")
case RESTART: {
  if (SIZE(inst.ingredients) != 1) {
    raise_error << maybe(get(Recipe, r).name) << "'restart' requires exactly one ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'restart' should be a routine id generated by 'start-running', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RESTART: {
  long long int id = ingredients.at(0).at(0);
  for (long long int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->id == id) {
      Routines.at(i)->state = RUNNING;
      break;
    }
  }
  break;
}

:(before "End Primitive Recipe Declarations")
STOP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "stop", STOP);
:(before "End Primitive Recipe Checks")
case STOP: {
  if (SIZE(inst.ingredients) != 1) {
    raise_error << maybe(get(Recipe, r).name) << "'stop' requires exactly one ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'stop' should be a routine id generated by 'start-running', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case STOP: {
  long long int id = ingredients.at(0).at(0);
  for (long long int i = 0; i < SIZE(Routines); ++i) {
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
  for (long long int i = 0; i < SIZE(Routines); ++i) {
    cerr << i << ": " << Routines.at(i)->id << ' ' << Routines.at(i)->state << ' ' << Routines.at(i)->parent_index << '\n';
  }
  break;
}

//: support for stopping routines after some number of cycles

:(scenario routine_discontinues_past_limit)
% Scheduling_interval = 2;
recipe f1 [
  1:number/child-id <- start-running f2
  limit-time 1:number/child-id, 10
  # padding loop just to make sure f2 has time to completed
  2:number <- copy 20
  2:number <- subtract 2:number, 1
  jump-if 2:number, -2:offset
]
recipe f2 [
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

:(before "End routine Fields")
long long int limit;
:(before "End routine Constructor")
limit = -1;  /* no limit */

:(before "End Primitive Recipe Declarations")
LIMIT_TIME,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "limit-time", LIMIT_TIME);
:(before "End Primitive Recipe Checks")
case LIMIT_TIME: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'limit-time' requires exactly two ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'limit-time' should be a routine id generated by 'start-running', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "second ingredient of 'limit-time' should be a number (of instructions to run for), but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case LIMIT_TIME: {
  long long int id = ingredients.at(0).at(0);
  for (long long int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->id == id) {
      Routines.at(i)->limit = ingredients.at(1).at(0);
      break;
    }
  }
  break;
}

//:: make sure that each routine gets a different alloc to start

:(scenario new_concurrent)
recipe f1 [
  start-running f2
  1:address:shared:number/raw <- new number:type
  # wait for f2 to complete
  {
    loop-unless 4:number/raw
  }
]
recipe f2 [
  2:address:shared:number/raw <- new number:type
  # hack: assumes scheduler implementation
  3:boolean/raw <- equal 1:address:shared:number/raw, 2:address:shared:number/raw
  # signal f2 complete
  4:number/raw <- copy 1
]
+mem: storing 0 in location 3
