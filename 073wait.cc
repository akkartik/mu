//: Routines can be put in a 'waiting' state, from which it will be ready to
//: run again when a specific memory location changes its value. This is mu's
//: basic technique for orchestrating the order in which different routines
//: operate.

:(scenario wait_for_location)
def f1 [
  10:num <- copy 34
  start-running f2
  20:location <- copy 10/unsafe
  wait-for-reset-then-set 20:location
  # wait for f2 to run and reset location 1
  30:num <- copy 10:num
]
def f2 [
  10:location <- copy 0/unsafe
]
+schedule: f1
+run: waiting for location 10 to reset
+schedule: f2
+schedule: waking up routine 1
+schedule: f1
+mem: storing 1 in location 30

//: define the new state that all routines can be in

:(before "End routine States")
WAITING,
:(before "End routine Fields")
// only if state == WAITING
int waiting_on_location;
:(before "End routine Constructor")
waiting_on_location = 0;

:(before "End Mu Test Teardown")
if (Passed && any_routines_waiting()) {
  Passed = false;
  raise << Current_scenario->name << ": deadlock!\n" << end();
}
:(before "End Run Routine")
if (any_routines_waiting()) {
  raise << "deadlock!\n" << end();
  dump_waiting_routines();
}
:(before "End Test Teardown")
if (Passed && any_routines_with_error()) {
  Passed = false;
  raise << "some routines died with errors\n" << end();
}
:(code)
bool any_routines_waiting() {
  for (int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->state == WAITING)
      return true;
  }
  return false;
}
void dump_waiting_routines() {
  for (int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->state == WAITING)
      cerr << i << ": " << routine_label(Routines.at(i)) << '\n';
  }
}

//: Primitive recipe to put routines in that state.
//: This primitive is also known elsewhere as compare-and-set (CAS). Used to
//: build locks.

:(before "End Primitive Recipe Declarations")
WAIT_FOR_RESET_THEN_SET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "wait-for-reset-then-set", WAIT_FOR_RESET_THEN_SET);
:(before "End Primitive Recipe Checks")
case WAIT_FOR_RESET_THEN_SET: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-reset-then-set' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_location(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-reset-then-set' requires a location ingredient, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_RESET_THEN_SET: {
  int loc = static_cast<int>(ingredients.at(0).at(0));
  trace(9998, "run") << "wait: *" << loc << " = " << get_or_insert(Memory, loc) << end();
  if (get_or_insert(Memory, loc) == 0) {
    trace(9998, "run") << "location " << loc << " is already 0; setting" << end();
    put(Memory, loc, 1);
    break;
  }
  trace(9998, "run") << "waiting for location " << loc << " to reset" << end();
  Current_routine->state = WAITING;
  Current_routine->waiting_on_location = loc;
  break;
}

//: Counterpart to unlock a lock.
:(before "End Primitive Recipe Declarations")
RESET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "reset", RESET);
:(before "End Primitive Recipe Checks")
case RESET: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'reset' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_location(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'reset' requires a location ingredient, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RESET: {
  int loc = static_cast<int>(ingredients.at(0).at(0));
  put(Memory, loc, 0);
  trace(9998, "run") << "reset: *" << loc << " = " << get_or_insert(Memory, loc) << end();
  break;
}

//: scheduler tweak to get routines out of that state

:(before "End Scheduler State Transitions")
for (int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  int loc = Routines.at(i)->waiting_on_location;
  if (loc && get_or_insert(Memory, loc) == 0) {
    trace(9999, "schedule") << "waking up routine " << Routines.at(i)->id << end();
    put(Memory, loc, 1);
    Routines.at(i)->state = RUNNING;
    Routines.at(i)->waiting_on_location = 0;
  }
}

//: Primitive to help compute locations to wait on.
//: Only supports elements immediately inside containers; no arrays or
//: containers within containers yet.

:(scenario get_location)
def main [
  12:num <- copy 34
  13:num <- copy 35
  15:location <- get-location 12:point, 1:offset
]
+mem: storing 13 in location 15

:(before "End Primitive Recipe Declarations")
GET_LOCATION,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "get-location", GET_LOCATION);
:(before "End Primitive Recipe Checks")
case GET_LOCATION: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'get-location' expects exactly 2 ingredients in '" << inst.original_string << "'\n" << end();
    break;
  }
  reagent/*copy*/ base = inst.ingredients.at(0);
  if (!canonize_type(base)) break;
  if (!base.type) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get-location' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  const type_tree* base_root_type = base.type->atom ? base.type : base.type->left;
  if (!base_root_type->atom || base_root_type->value == 0 || !contains_key(Type, base_root_type->value) || get(Type, base_root_type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get-location' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  const reagent& offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'get-location' should have type 'offset', but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  int offset_value = 0;
  if (is_integer(offset.name)) {  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type).elements)) {
      raise << maybe(get(Recipe, r).name) << "invalid offset " << offset_value << " for '" << get(Type, base_type).name << "'\n" << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  if (inst.products.empty()) break;
  if (!is_mu_location(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'get-location " << base.original_string << ", " << offset.original_string << "' should write to type location but '" << inst.products.at(0).name << "' has type '" << names_to_string_without_quotes(inst.products.at(0).type) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET_LOCATION: {
  reagent/*copy*/ base = current_instruction().ingredients.at(0);
  canonize(base);
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  const type_tree* base_root_type = root_type(base.type);
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_root_type->value).elements)) break;  // copied from Check above
  int result = base_address;
  for (int i = 0; i < offset; ++i)
    result += size_of(element_type(base.type, i));
  trace(9998, "run") << "address to copy is " << result << end();
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(code)
bool is_mu_location(reagent/*copy*/ x) {
  if (!canonize_type(x)) return false;
  if (!x.type) return false;
  if (x.type->right) return false;
  return x.type->value == get(Type_ordinal, "location");
}

:(scenario get_location_out_of_bounds)
% Hide_errors = true;
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  get-location 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for 'point-number'

:(scenario get_location_out_of_bounds_2)
% Hide_errors = true;
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  get-location 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for 'point-number'

:(scenario get_location_product_type_mismatch)
% Hide_errors = true;
container boolbool [
  x:bool
  y:bool
]
def main [
  12:bool <- copy 1
  13:bool <- copy 0
  15:bool <- get-location 12:boolbool, 1:offset
]
+error: main: 'get-location 12:boolbool, 1:offset' should write to type location but '15' has type 'boolean'

:(scenario get_location_indirect)
# 'get-location' can read from container address
def main [
  1:num <- copy 10
  # 10 reserved for refcount
  11:num <- copy 34
  12:num <- copy 35
  4:location <- get-location 1:&:point/lookup, 0:offset
]
+mem: storing 11 in location 4

:(scenario get_location_indirect_2)
def main [
  1:num <- copy 10
  # 10 reserved for refcount
  11:num <- copy 34
  12:num <- copy 35
  4:&:num <- copy 20/unsafe
  4:&:location/lookup <- get-location 1:&:point/lookup, 0:offset
]
+mem: storing 11 in location 21

//: allow waiting on a routine to complete

:(scenario wait_for_routine)
def f1 [
  # add a few routines to run
  1:num/routine <- start-running f2
  2:num/routine <- start-running f3
  wait-for-routine 1:num/routine
  # now wait for f2 to *complete* and modify location 13 before using its value
  20:num <- copy 13:num
]
def f2 [
  10:num <- copy 0  # just padding
  switch  # simulate a block; routine f1 shouldn't restart at this point
  13:num <- copy 34
]
def f3 [
  # padding routine just to help simulate the block in f2 using 'switch'
  11:num <- copy 0
  12:num <- copy 0
]
+schedule: f1
+run: waiting for routine 2
+schedule: f2
+schedule: f3
+schedule: f2
+schedule: waking up routine 1
+schedule: f1
# if we got the synchronization wrong we'd be storing 0 in location 20
+mem: storing 34 in location 20

:(before "End routine Fields")
// only if state == WAITING
int waiting_on_routine;
:(before "End routine Constructor")
waiting_on_routine = 0;

:(before "End Primitive Recipe Declarations")
WAIT_FOR_ROUTINE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "wait-for-routine", WAIT_FOR_ROUTINE);
:(before "End Primitive Recipe Checks")
case WAIT_FOR_ROUTINE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-routine' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'wait-for-routine' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_ROUTINE: {
  if (ingredients.at(0).at(0) == Current_routine->id) {
    raise << maybe(current_recipe_name()) << "routine can't wait for itself! '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  Current_routine->state = WAITING;
  Current_routine->waiting_on_routine = ingredients.at(0).at(0);
  trace(9998, "run") << "waiting for routine " << ingredients.at(0).at(0) << end();
//?   cerr << Current_routine->id << ": waiting for routine " << ingredients.at(0).at(0) << '\n';
  break;
}

:(before "End Scheduler State Transitions")
// Wake up any routines waiting for other routines to complete.
// Important: this must come after the scheduler loop above giving routines
// waiting for locations to change a chance to wake up.
for (int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  routine* waiter = Routines.at(i);
  if (!waiter->waiting_on_routine) continue;
  int id = waiter->waiting_on_routine;
  assert(id != waiter->id);  // routine can't wait on itself
  for (int j = 0; j < SIZE(Routines); ++j) {
    const routine* waitee = Routines.at(j);
    if (waitee->id == id && waitee->state != RUNNING && waitee->state != WAITING) {
      // routine is COMPLETED or DISCONTINUED
      trace(9999, "schedule") << "waking up routine " << waiter->id << end();
//?       cerr << id << " is now done (" << waitee->state << "); waking up waiting routine " << waiter->id << '\n';
      waiter->state = RUNNING;
      waiter->waiting_on_routine = 0;
    }
  }
}

//:: helpers for manipulating routines in tests
//:
//: Managing arbitrary scenarios requires the ability to:
//:   a) stop the current routine (`switch`)
//:   b) restart a routine (`restart`)
//:   c) tell when a routine is blocked
//:
//: A routine is blocked either if it's waiting or if it explicitly signals
//: that it's blocked (even as it periodically wakes up and polls for some
//: event).
//:
//: Signalling blockedness might well be a huge hack. But Mu doesn't have Unix
//: signals to avoid polling with, because signals are also pretty hacky.

:(before "End routine Fields")
bool blocked;
:(before "End routine Constructor")
blocked = false;

:(before "End Primitive Recipe Declarations")
CURRENT_ROUTINE_IS_BLOCKED,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "current-routine-is-blocked", CURRENT_ROUTINE_IS_BLOCKED);
:(before "End Primitive Recipe Checks")
case CURRENT_ROUTINE_IS_BLOCKED: {
  if (!inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'current-routine-is-blocked' should have no ingredients, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CURRENT_ROUTINE_IS_BLOCKED: {
  Current_routine->blocked = true;
  break;
}

:(before "End Primitive Recipe Declarations")
CURRENT_ROUTINE_IS_UNBLOCKED,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "current-routine-is-unblocked", CURRENT_ROUTINE_IS_UNBLOCKED);
:(before "End Primitive Recipe Checks")
case CURRENT_ROUTINE_IS_UNBLOCKED: {
  if (!inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'current-routine-is-unblocked' should have no ingredients, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CURRENT_ROUTINE_IS_UNBLOCKED: {
  Current_routine->blocked = false;
  break;
}

//: also allow waiting on a routine to block
//: (just for tests; use wait_for_routine above wherever possible)

:(scenario wait_for_routine_to_block)
def f1 [
  1:num/routine <- start-running f2
  wait-for-routine-to-block 1:num/routine
  # now wait for f2 to run and modify location 10 before using its value
  11:num <- copy 10:num
]
def f2 [
  10:num <- copy 34
]
+schedule: f1
+run: waiting for routine 2 to block
+schedule: f2
+schedule: waking up routine 1 because routine 2 is blocked
+schedule: f1
# if we got the synchronization wrong we'd be storing 0 in location 11
+mem: storing 34 in location 11

:(before "End routine Fields")
// only if state == WAITING
int waiting_on_routine_to_block;
:(before "End routine Constructor")
waiting_on_routine_to_block = 0;

:(before "End Primitive Recipe Declarations")
WAIT_FOR_ROUTINE_TO_BLOCK,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "wait-for-routine-to-block", WAIT_FOR_ROUTINE_TO_BLOCK);
:(before "End Primitive Recipe Checks")
case WAIT_FOR_ROUTINE_TO_BLOCK: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-routine-to-block' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'wait-for-routine-to-block' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_ROUTINE_TO_BLOCK: {
  if (ingredients.at(0).at(0) == Current_routine->id) {
    raise << maybe(current_recipe_name()) << "routine can't wait for itself! '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  Current_routine->state = WAITING;
  Current_routine->waiting_on_routine_to_block = ingredients.at(0).at(0);
  trace(9998, "run") << "waiting for routine " << ingredients.at(0).at(0) << " to block" << end();
  break;
}

:(before "End Scheduler State Transitions")
// Wake up any routines waiting for other routines to stop running.
for (int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  routine* waiter = Routines.at(i);
  if (!waiter->waiting_on_routine_to_block) continue;
  int id = waiter->waiting_on_routine_to_block;
  assert(id != waiter->id);  // routine can't wait on itself
  for (int j = 0; j < SIZE(Routines); ++j) {
    const routine* waitee = Routines.at(j);
    if (waitee->id != id) continue;
    if (waitee->state != RUNNING || waitee->blocked) {
      trace(9999, "schedule") << "waking up routine " << waiter->id << " because routine " << waitee->id << " is blocked" << end();
      waiter->state = RUNNING;
      waiter->waiting_on_routine_to_block = 0;
    }
  }
}

//: yield voluntarily to let some other routine run

:(before "End Primitive Recipe Declarations")
SWITCH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "switch", SWITCH);
:(before "End Primitive Recipe Checks")
case SWITCH: {
  break;
}
//: pick another RUNNING routine at random and wait for it to get a chance
//: there might be a better implementation than this
:(before "End Primitive Recipe Implementations")
case SWITCH: {
  int id = some_other_running_routine();
  if (id) {
    assert(id != Current_routine->id);
    Current_routine->state = WAITING;
    Current_routine->waiting_on_routine_to_block = id;
  }
  break;
}
:(code)
int some_other_running_routine() {
  for (int i = 0; i < SIZE(Routines); ++i) {
    if (i == Current_routine_index) continue;
    assert(Routines.at(i) != Current_routine);
    assert(Routines.at(i)->id != Current_routine->id);
    if (Routines.at(i)->state == RUNNING)
      return Routines.at(i)->id;
  }
  return 0;
}

//: helper for restarting blocking routines in tests

:(before "End Primitive Recipe Declarations")
RESTART,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "restart", RESTART);
:(before "End Primitive Recipe Checks")
case RESTART: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'restart' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'restart' should be a routine id generated by 'start-running', but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RESTART: {
  int id = ingredients.at(0).at(0);
  for (int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->id == id) {
      if (Routines.at(i)->state == WAITING)
        Routines.at(i)->state = RUNNING;
      Routines.at(i)->blocked = false;
      break;
    }
  }
  break;
}

:(scenario cannot_restart_completed_routine)
% Scheduling_interval = 1;
def main [
  local-scope
  r:num/routine-id <- start-running f
  x:num <- copy 0  # wait for f to be scheduled
  # r is COMPLETED by this point
  restart r  # should have no effect
  x:num <- copy 0  # give f time to be scheduled (though it shouldn't be)
]
def f [
  1:num/raw <- copy 1
]
# shouldn't crash

:(scenario restart_blocked_routine)
% Scheduling_interval = 1;
def main [
  local-scope
  r:num/routine-id <- start-running f
  wait-for-routine-to-block r  # get past the block in f below
  restart r
  wait-for-routine-to-block r  # should run f to completion
]
# function with one block
def f [
  current-routine-is-blocked
  # 8 instructions of padding, many more than 'main' above
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
  1:num <- add 1:num, 1
]
# make sure all of f ran
+mem: storing 8 in location 1
