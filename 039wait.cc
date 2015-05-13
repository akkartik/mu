//: Routines can be put in a 'waiting' state, from which it will be ready to
//: run again when a specific memory location changes its value. This is mu's
//: basic technique for orchestrating the order in which different routines
//: operate.

:(scenario wait_for_location)
recipe f1 [
  1:number <- copy 0:literal
  start-running f2:recipe
  wait-for-location 1:number
  # now wait for f2 to run and modify location 1 before using its value
  2:number <- copy 1:number
]
recipe f2 [
  1:number <- copy 34:literal
]
# if we got the synchronization wrong we'd be storing 0 in location 2
+mem: storing 34 in location 2

//: define the new state that all routines can be in

:(before "End routine States")
WAITING,
:(before "End routine Fields")
// only if state == WAITING
index_t waiting_on_location;
int old_value_of_waiting_location;
:(before "End routine Constructor")
waiting_on_location = old_value_of_waiting_location = 0;

//: primitive recipe to put routines in that state

:(before "End Primitive Recipe Declarations")
WAIT_FOR_LOCATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["wait-for-location"] = WAIT_FOR_LOCATION;
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_LOCATION: {
  reagent loc = canonize(current_instruction().ingredients.at(0));
  Current_routine->state = WAITING;
  Current_routine->waiting_on_location = loc.value;
  Current_routine->old_value_of_waiting_location = Memory[loc.value];
  trace("run") << "waiting for location " << loc.value << " to change from " << Memory[loc.value];
//?   trace("schedule") << Current_routine->id << ": waiting for location " << loc.value << " to change from " << Memory[loc.value]; //? 2
  break;
}

//: scheduler tweak to get routines out of that state

:(before "End Scheduler State Transitions")
for (index_t i = 0; i < Routines.size(); ++i) {
//?   trace("schedule") << "wake up loop 1: routine " << Routines.at(i)->id << " has state " << Routines.at(i)->state; //? 1
  if (Routines.at(i)->state != WAITING) continue;
//?   trace("schedule") << "waiting on location: " << Routines.at(i)->waiting_on_location; //? 1
//?   if (Routines.at(i)->waiting_on_location) //? 2
//?     trace("schedule") << "checking routine " << Routines.at(i)->id << " waiting on location " //? 2
//?       << Routines.at(i)->waiting_on_location << ": " << Memory[Routines.at(i)->waiting_on_location] << " vs " << Routines.at(i)->old_value_of_waiting_location; //? 2
  if (Routines.at(i)->waiting_on_location &&
      Memory[Routines.at(i)->waiting_on_location] != Routines.at(i)->old_value_of_waiting_location) {
    trace("schedule") << "waking up routine\n";
    Routines.at(i)->state = RUNNING;
    Routines.at(i)->waiting_on_location = Routines.at(i)->old_value_of_waiting_location = 0;
  }
}

//: also allow waiting on a routine to stop running

:(scenario wait_for_routine)
recipe f1 [
  1:number <- copy 0:literal
  12:number/routine <- start-running f2:recipe
  wait-for-routine 12:number/routine
  # now wait for f2 to run and modify location 1 before using its value
  3:number <- copy 1:number
]
recipe f2 [
  1:number <- copy 34:literal
]
+schedule: f1
+run: waiting for routine 2
+schedule: f2
+schedule: waking up routine 1
+schedule: f1
# if we got the synchronization wrong we'd be storing 0 in location 3
+mem: storing 34 in location 3

:(before "End routine Fields")
// only if state == WAITING
index_t waiting_on_routine;
:(before "End routine Constructor")
waiting_on_routine = 0;

:(before "End Primitive Recipe Declarations")
WAIT_FOR_ROUTINE,
:(before "End Primitive Recipe Numbers")
Recipe_number["wait-for-routine"] = WAIT_FOR_ROUTINE;
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_ROUTINE: {
  Current_routine->state = WAITING;
  assert(ingredients.at(0).size() == 1);  // scalar
  Current_routine->waiting_on_routine = ingredients.at(0).at(0);
  trace("run") << "waiting for routine " << ingredients.at(0).at(0);
  break;
}

:(before "End Scheduler State Transitions")
// Wake up any routines waiting for other routines to go to sleep.
// Important: this must come after the scheduler loop above giving routines
// waiting for locations to change a chance to wake up.
for (index_t i = 0; i < Routines.size(); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  if (!Routines.at(i)->waiting_on_routine) continue;
  index_t id = Routines.at(i)->waiting_on_routine;
  assert(id != Routines.at(i)->id);
  for (index_t j = 0; j < Routines.size(); ++j) {
    if (Routines.at(j)->id == id && Routines.at(j)->state != RUNNING) {
      trace("schedule") << "waking up routine " << Routines.at(i)->id;
      Routines.at(i)->state = RUNNING;
      Routines.at(i)->waiting_on_routine = 0;
    }
  }
}

:(before "End Primitive Recipe Declarations")
SWITCH,
:(before "End Primitive Recipe Numbers")
Recipe_number["switch"] = SWITCH;
:(before "End Primitive Recipe Implementations")
case SWITCH: {
  index_t id = some_other_running_routine();
  if (id) {
    assert(id != Current_routine->id);
//?     cerr << "waiting on " << id << " from " << Current_routine->id << '\n'; //? 1
    Current_routine->state = WAITING;
    Current_routine->waiting_on_routine = id;
  }
  break;
}

:(code)
index_t some_other_running_routine() {
  for (index_t i = 0; i < Routines.size(); ++i) {
    if (i == Current_routine_index) continue;
    assert(Routines.at(i) != Current_routine);
    assert(Routines.at(i)->id != Current_routine->id);
    if (Routines.at(i)->state == RUNNING)
      return Routines.at(i)->id;
  }
  return 0;
}
