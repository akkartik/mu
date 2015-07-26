//: Run a second routine concurrently using 'start-running', without any
//: guarantees on how the operations in each are interleaved with each other.

:(scenario scheduler)
recipe f1 [
  start-running f2:recipe
  # wait for f2 to run
  {
    jump-unless 1:number, -1:literal
  }
]
recipe f2 [
  1:number <- copy 1:literal
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
  Routines.push_back(new routine(r));
  Current_routine_index = 0, Current_routine = Routines.at(0);
  while (!all_routines_done()) {
    skip_to_next_routine();
    assert(Current_routine);
    assert(Current_routine->state == RUNNING);
    trace("schedule") << current_routine_label() << end();
    run_current_routine(Scheduling_interval);
    // Scheduler State Transitions
    if (Current_routine->completed())
      Current_routine->state = COMPLETED;
    // End Scheduler State Transitions

    // Scheduler Cleanup
    // End Scheduler Cleanup
  }
}

:(code)
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
  call_stack calls = Current_routine->calls;
  for (call_stack::iterator p = calls.begin(); p != calls.end(); ++p) {
    if (p != calls.begin()) result << '/';
    result << Recipe[p->running_recipe].name;
  }
  return result.str();
}

:(before "End Teardown")
for (long long int i = 0; i < SIZE(Routines); ++i)
  delete Routines.at(i);
Routines.clear();

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
Recipe_ordinal["start-running"] = START_RUNNING;
:(before "End Primitive Recipe Implementations")
case START_RUNNING: {
  routine* new_routine = new routine(ingredients.at(0).at(0));
  new_routine->parent_index = Current_routine_index;
  // populate ingredients
  for (long long int i = 1; i < SIZE(current_instruction().ingredients); ++i)
    new_routine->calls.front().ingredient_atoms.push_back(ingredients.at(i));
  Routines.push_back(new_routine);
  products.resize(1);
  products.at(0).push_back(new_routine->id);
  break;
}

:(scenario scheduler_runs_single_routine)
% Scheduling_interval = 1;
recipe f1 [
  1:number <- copy 0:literal
  2:number <- copy 0:literal
]
+schedule: f1
+run: 1:number <- copy 0:literal
+schedule: f1
+run: 2:number <- copy 0:literal

:(scenario scheduler_interleaves_routines)
% Scheduling_interval = 1;
recipe f1 [
  start-running f2:recipe
  1:number <- copy 0:literal
  2:number <- copy 0:literal
]
recipe f2 [
  3:number <- copy 0:literal
  4:number <- copy 0:literal
]
+schedule: f1
+run: start-running f2:recipe
+schedule: f2
+run: 3:number <- copy 0:literal
+schedule: f1
+run: 1:number <- copy 0:literal
+schedule: f2
+run: 4:number <- copy 0:literal
+schedule: f1
+run: 2:number <- copy 0:literal

:(scenario start_running_takes_args)
recipe f1 [
  start-running f2:recipe, 3:literal
  # wait for f2 to run
  {
    jump-unless 1:number, -1:literal
  }
]
recipe f2 [
  1:number <- next-ingredient
  2:number <- add 1:number, 1:literal
]
+mem: storing 4 in location 2

:(scenario start_running_returns_routine_id)
recipe f1 [
  1:number <- start-running f2:recipe
]
recipe f2 [
  12:number <- copy 44:literal
]
+mem: storing 2 in location 1

//: this scenario will require some careful setup in escaped C++
//: (straining our tangle capabilities to near-breaking point)
:(scenario scheduler_skips_completed_routines)
% recipe_ordinal f1 = load("recipe f1 [\n1:number <- copy 0:literal\n]").front();
% recipe_ordinal f2 = load("recipe f2 [\n2:number <- copy 0:literal\n]").front();
% Routines.push_back(new routine(f1));  // f1 meant to run
% Routines.push_back(new routine(f2));
% Routines.back()->state = COMPLETED;  // f2 not meant to run
#? % Trace_stream->dump_layer = "all";
# must have at least one routine without escaping
recipe f3 [
  3:number <- copy 0:literal
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
  1:number <- copy 0:literal
  2:number <- copy 0:literal
]
+schedule: f1
-run: idle

//:: Routines are marked completed when their parent completes.

:(scenario scheduler_kills_orphans)
recipe main [
  start-running f1:recipe
  # f1 never actually runs because its parent completes without waiting for it
]
recipe f1 [
  1:number <- copy 0:literal
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
  1:number/child-id <- start-running f2:recipe
  12:number <- copy 0:literal  # race condition since we don't care about location 12
  # thanks to Scheduling_interval, f2's one instruction runs in between here and completes
  2:number/state <- routine-state 1:number/child-id
]
recipe f2 [
  12:number <- copy 0:literal
  # trying to run a second instruction marks routine as completed
]
# recipe f2 should be in state COMPLETED
+mem: storing 1 in location 2

:(before "End Primitive Recipe Declarations")
ROUTINE_STATE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["routine-state"] = ROUTINE_STATE;
:(before "End Primitive Recipe Implementations")
case ROUTINE_STATE: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'routine-state' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": first ingredient of 'routine-state' should be a routine id generated by 'start-running', but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
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
Recipe_ordinal["restart"] = RESTART;
:(before "End Primitive Recipe Implementations")
case RESTART: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'restart' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": first ingredient of 'restart' should be a routine id generated by 'start-running', but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
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
Recipe_ordinal["stop"] = STOP;
:(before "End Primitive Recipe Implementations")
case STOP: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'stop' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": first ingredient of 'stop' should be a routine id generated by 'start-running', but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
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
Recipe_ordinal["$dump-routines"] = _DUMP_ROUTINES;
:(before "End Primitive Recipe Implementations")
case _DUMP_ROUTINES: {
  for (long long int i = 0; i < SIZE(Routines); ++i) {
    cerr << i << ": " << Routines.at(i)->id << ' ' << Routines.at(i)->state << ' ' << Routines.at(i)->parent_index << '\n';
  }
  break;
}
