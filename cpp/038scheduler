//: Run a second routine concurrently using fork, without any guarantees on
//: how the operations in each are interleaved with each other.

:(scenario run)
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
:(before "End Globals")
list<routine*> Running_routines, Completed_routines;
size_t Scheduling_interval = 500;
:(replace{} "void run(recipe_number r)")
void run(recipe_number r) {
  Running_routines.push_back(new routine(r));
  while (!Running_routines.empty()) {
    Current_routine = Running_routines.front();
    Running_routines.pop_front();
    trace("schedule") << current_recipe_name();
    run_current_routine(Scheduling_interval);
    if (Current_routine->calls.empty())
      Completed_routines.push_back(Current_routine);
    else
      Running_routines.push_back(Current_routine);
  }
}

:(before "End Teardown")
for (list<routine*>::iterator p = Running_routines.begin(); p != Running_routines.end(); ++p)
  delete *p;
Running_routines.clear();
for (list<routine*>::iterator p = Completed_routines.begin(); p != Completed_routines.end(); ++p)
  delete *p;
Completed_routines.clear();

:(before "End Primitive Recipe Declarations")
RUN,
:(before "End Primitive Recipe Numbers")
Recipe_number["run"] = RUN;
:(before "End Primitive Recipe Implementations")
case RUN: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  assert(!current_instruction().ingredients[0].initialized);
  Running_routines.push_back(new routine(Recipe_number[current_instruction().ingredients[0].name]));
  break;
}
