//: Routines can be put in a 'waiting' state, from which it will be ready to
//: run again when a specific memory location changes its value. This is mu's
//: basic technique for orchestrating the order in which different routines
//: operate.

:(scenario "stalled_routine")
recipe f1 [
  1:integer <- copy 0:literal
  run f2:recipe
  wait-for-location 1:integer
  # now wait for f2 to run and modify location 1 before using its value
  2:integer <- copy 1:integer
]
recipe f2 [
  1:integer <- copy 34:literal
]
# if we got the synchronization wrong we'd be storing 0 in location 2
+mem: storing 34 in location 2

//: define the new state that all routines can be in

:(before "End routine States")
WAITING,
:(before "End routine Fields")
// only if state == WAITING
size_t waiting_on_location;
int old_value_of_wating_location;
:(before "End routine Constructor")
waiting_on_location = old_value_of_wating_location = 0;

//: primitive recipe to put routines in that state

:(before "End Primitive Recipe Declarations")
WAIT_FOR_LOCATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["wait-for-location"] = WAIT_FOR_LOCATION;
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_LOCATION: {
  reagent loc = canonize(current_instruction().ingredients[0]);
  Current_routine->state = WAITING;
  Current_routine->waiting_on_location = loc.value;
  Current_routine->old_value_of_wating_location = Memory[loc.value];
  trace("run") << "waiting for " << loc.value << " to change from " << Memory[loc.value];
  break;
}

//: scheduler tweak to get routines out of that state

:(before "End Scheduler State Transitions")
for (size_t i = 0; i < Routines.size(); ++i) {
  if (Routines[i]->state != WAITING) continue;
  if (Memory[Routines[i]->waiting_on_location] != Routines[i]->old_value_of_wating_location) {
    trace("schedule") << "waking up routine\n";
    Routines[i]->state = RUNNING;
    Routines[i]->waiting_on_location = Routines[i]->old_value_of_wating_location = 0;
  }
}
