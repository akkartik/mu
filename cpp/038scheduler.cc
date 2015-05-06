//: Run a second routine concurrently using fork, without any guarantees on
//: how the operations in each are interleaved with each other.

:(scenario scheduler)
recipe f1 [
  start-running f2:recipe
  1:integer <- copy 3:literal
]
recipe f2 [
  2:integer <- copy 4:literal
]
+schedule: f1
+schedule: f2

//: first, add a deadline to run(routine)
//: these changes are ugly and brittle; just close your nose and get through the next few lines
:(replace "void run_current_routine()")
void run_current_routine(size_t time_slice)
:(replace "while (!Current_routine->completed())" following "void run_current_routine(size_t time_slice)")
size_t ninstrs = 0;
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
index_t Current_routine_index = 0;
size_t Scheduling_interval = 500;
:(before "End Setup")
Scheduling_interval = 500;
:(replace{} "void run(recipe_number r)")
void run(recipe_number r) {
  Routines.push_back(new routine(r));
  Current_routine_index = 0, Current_routine = Routines[0];
  while (!all_routines_done()) {
    skip_to_next_routine();
//?     cout << "scheduler: " << Current_routine_index << '\n'; //? 1
    assert(Current_routine);
    assert(Current_routine->state == RUNNING);
    trace("schedule") << current_recipe_name();
    run_current_routine(Scheduling_interval);
    if (Current_routine->completed())
      Current_routine->state = COMPLETED;
    // End Scheduler State Transitions
  }
//?   cout << "done with run\n"; //? 1
}

:(code)
bool all_routines_done() {
  for (index_t i = 0; i < Routines.size(); ++i) {
//?     cout << "routine " << i << ' ' << Routines[i]->state << '\n'; //? 1
    if (Routines[i]->state == RUNNING) {
      return false;
    }
  }
  return true;
}

// skip Current_routine_index past non-RUNNING routines
void skip_to_next_routine() {
  assert(!Routines.empty());
  assert(Current_routine_index < Routines.size());
  for (index_t i = (Current_routine_index+1)%Routines.size();  i != Current_routine_index;  i = (i+1)%Routines.size()) {
    if (Routines[i]->state == RUNNING) {
//?       cout << "switching to " << i << '\n'; //? 1
      Current_routine_index = i;
      Current_routine = Routines[i];
      return;
    }
  }
//?   cout << "all done\n"; //? 1
}

:(before "End Teardown")
for (index_t i = 0; i < Routines.size(); ++i)
  delete Routines[i];
Routines.clear();

//:: To schedule new routines to run, call 'start-scheduling'.

//: 'start-scheduling' will return a unique id for the routine that was
//: created.
:(before "End routine Fields")
index_t id;
:(before "End Globals")
index_t Next_routine_id = 1;
:(before "End Setup")
Next_routine_id = 1;
:(before "End routine Constructor")
id = Next_routine_id;
Next_routine_id++;

:(before "End Primitive Recipe Declarations")
START_RUNNING,
:(before "End Primitive Recipe Numbers")
Recipe_number["start-running"] = START_RUNNING;
:(before "End Primitive Recipe Implementations")
case START_RUNNING: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  assert(!current_instruction().ingredients[0].initialized);
  routine* new_routine = new routine(Recipe_number[current_instruction().ingredients[0].name]);
  Routines.push_back(new_routine);
  if (!current_instruction().products.empty()) {
    vector<long long int> result;
    result.push_back(new_routine->id);
    write_memory(current_instruction().products[0], result);
  }
  break;
}

:(scenario scheduler_runs_single_routine)
% Scheduling_interval = 1;
recipe f1 [
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
]
+schedule: f1
+run: instruction f1/0
+schedule: f1
+run: instruction f1/1

:(scenario scheduler_interleaves_routines)
% Scheduling_interval = 1;
recipe f1 [
  start-running f2:recipe
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
]
recipe f2 [
  3:integer <- copy 4:literal
  4:integer <- copy 4:literal
]
+schedule: f1
+run: instruction f1/0
+schedule: f2
+run: instruction f2/0
+schedule: f1
+run: instruction f1/1
+schedule: f2
+run: instruction f2/1
+schedule: f1
+run: instruction f1/2

:(scenario start_running_returns_routine_id)
% Scheduling_interval = 1;
recipe f1 [
  1:integer <- start-running f2:recipe
]
recipe f2 [
  12:integer <- copy 44:literal
]
+mem: storing 2 in location 1

:(scenario scheduler_skips_completed_routines)
# this scenario will require some careful setup in escaped C++
# (straining our tangle capabilities to near-breaking point)
% recipe_number f1 = load("recipe f1 [\n1:integer <- copy 0:literal\n]").front();
% recipe_number f2 = load("recipe f2 [\n2:integer <- copy 0:literal\n]").front();
% Routines.push_back(new routine(f1));  // f1 meant to run
% Routines.push_back(new routine(f2));
% Routines.back()->state = COMPLETED;  // f2 not meant to run
#? % Trace_stream->dump_layer = "all";
# must have at least one routine without escaping
recipe f3 [
  3:integer <- copy 0:literal
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
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
]
+schedule: f1
-run: idle
