//: Run a second routine concurrently using fork, without any guarantees on
//: how the operations in each are interleaved with each other.

:(scenario scheduler)
recipe f1 [
  run f2:recipe
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
while (!Current_routine->completed() && ninstrs < time_slice)
:(after "Running One Instruction")
ninstrs++;

//: now the rest of the scheduler is clean

:(before "struct routine")
enum routine_state {
  RUNNING,
  COMPLETED,
  // End Routine States
};
:(before "End routine Fields")
enum routine_state state;
:(before "End routine Constructor")
state = RUNNING;

:(before "End Globals")
vector<routine*> Routines;
size_t Current_routine_index = 0;
size_t Scheduling_interval = 500;
:(before "End Setup")
Scheduling_interval = 500;
:(replace{} "void run(recipe_number r)")
void run(recipe_number r) {
  Routines.push_back(new routine(r));
  Current_routine_index = 0, Current_routine = Routines[0];
  while (!all_routines_done()) {
    assert(Current_routine);
    assert(Current_routine->state == RUNNING);
    trace("schedule") << current_recipe_name();
    run_current_routine(Scheduling_interval);
    if (Current_routine->completed())
      Current_routine->state = COMPLETED;
    // End Scheduler State Transitions
    skip_to_next_routine();
  }
}

:(code)
bool all_routines_done() {
  for (size_t i = 0; i < Routines.size(); ++i) {
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
  for (size_t i = (Current_routine_index+1)%Routines.size();  i != Current_routine_index;  i = (i+1)%Routines.size()) {
    if (Routines[i]->state == RUNNING) {
      Current_routine_index = i;
      Current_routine = Routines[i];
      return;
    }
  }
}

:(before "End Teardown")
for (size_t i = 0; i < Routines.size(); ++i)
  delete Routines[i];
Routines.clear();

:(before "End Primitive Recipe Declarations")
RUN,
:(before "End Primitive Recipe Numbers")
Recipe_number["run"] = RUN;
:(before "End Primitive Recipe Implementations")
case RUN: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  assert(!current_instruction().ingredients[0].initialized);
  Routines.push_back(new routine(Recipe_number[current_instruction().ingredients[0].name]));
  break;
}

:(scenario scheduler_interleaves_routines)
% Scheduling_interval = 1;
recipe f1 [
  run f2:recipe
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
