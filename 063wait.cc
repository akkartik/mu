//: Routines can be put in a 'waiting' state, from which it will be ready to
//: run again when a specific memory location changes its value. This is mu's
//: basic technique for orchestrating the order in which different routines
//: operate.

:(scenario wait_for_location)
def f1 [
  1:number <- copy 0
  start-running f2
  2:location <- copy 1/unsafe
  wait-for-location 2:location
  # now wait for f2 to run and modify location 1 before using its value
  3:number <- copy 1:number
]
def f2 [
  1:number <- copy 34
]
# if we got the synchronization wrong we'd be storing 0 in location 3
+mem: storing 34 in location 3

//: define the new state that all routines can be in

:(before "End routine States")
WAITING,
:(before "End routine Fields")
// only if state == WAITING
int waiting_on_location;
int old_value_of_waiting_location;
:(before "End routine Constructor")
waiting_on_location = old_value_of_waiting_location = 0;

:(before "End Mu Test Teardown")
if (Passed && any_routines_waiting()) {
  Passed = false;
  raise << Current_scenario->name << ": deadlock!\n" << end();
  ++Num_failures;
}
:(before "End Test Teardown")
if (Passed && any_routines_with_error()) {
  Passed = false;
  raise << "some routines died with errors\n" << end();
  ++Num_failures;
}
:(code)
bool any_routines_waiting() {
  for (int i = 0; i < SIZE(Routines); ++i) {
    if (Routines.at(i)->state == WAITING)
      return true;
  }
  return false;
}

//: primitive recipe to put routines in that state

:(before "End Primitive Recipe Declarations")
WAIT_FOR_LOCATION,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "wait-for-location", WAIT_FOR_LOCATION);
:(before "End Primitive Recipe Checks")
case WAIT_FOR_LOCATION: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-location' requires exactly one ingredient, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_location(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'wait-for-location' requires a location ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_LOCATION: {
  int loc = ingredients.at(0).at(0);
  Current_routine->state = WAITING;
  Current_routine->waiting_on_location = loc;
  Current_routine->old_value_of_waiting_location = get_or_insert(Memory, loc);
  trace(9998, "run") << "waiting for location " << loc << " to change from " << no_scientific(get_or_insert(Memory, loc)) << end();
  break;
}

//: scheduler tweak to get routines out of that state

:(before "End Scheduler State Transitions")
for (int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  if (Routines.at(i)->waiting_on_location &&
      get_or_insert(Memory, Routines.at(i)->waiting_on_location) != Routines.at(i)->old_value_of_waiting_location) {
    trace(9999, "schedule") << "waking up routine\n" << end();
    Routines.at(i)->state = RUNNING;
    Routines.at(i)->waiting_on_location = Routines.at(i)->old_value_of_waiting_location = 0;
  }
}

//: primitive to help compute locations to wait for
//: only supports elements inside containers, no arrays or containers within
//: containers yet.

:(scenario get_location)
def main [
  12:number <- copy 34
  13:number <- copy 35
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
    raise << maybe(get(Recipe, r).name) << "'get-location' expects exactly 2 ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  if (!canonize_type(base)) break;
  if (!base.type || !base.type->value || !contains_key(Type, base.type->value) || get(Type, base.type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get-location' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'get-location' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  int offset_value = 0;
  if (is_integer(offset.name)) {  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type).elements)) {
      raise << maybe(get(Recipe, r).name) << "invalid offset " << offset_value << " for " << get(Type, base_type).name << '\n' << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  if (inst.products.empty()) break;
  if (!is_mu_location(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'get-location " << base.original_string << ", " << offset.original_string << "' should write to type location but " << inst.products.at(0).name << " has type " << names_to_string_without_quotes(inst.products.at(0).type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET_LOCATION: {
  reagent base = current_instruction().ingredients.at(0);
  canonize(base);
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type).elements)) break;  // copied from Check above
  int result = base_address;
  for (int i = 0; i < offset; ++i)
    result += size_of(element_type(base, i));
  trace(9998, "run") << "address to copy is " << result << end();
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(code)
bool is_mu_location(reagent x) {
  if (!canonize_type(x)) return false;
  if (!x.type) return false;
  if (x.type->right) return false;
  return x.type->value == get(Type_ordinal, "location");
}

:(scenario get_location_out_of_bounds)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-location 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for point-number

:(scenario get_location_out_of_bounds_2)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-location 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for point-number

:(scenario get_location_product_type_mismatch)
% Hide_errors = true;
container boolbool [
  x:boolean
  y:boolean
]
def main [
  12:boolean <- copy 1
  13:boolean <- copy 0
  15:boolean <- get-location 12:boolbool, 1:offset
]
+error: main: 'get-location 12:boolbool, 1:offset' should write to type location but 15 has type boolean

:(scenario get_location_indirect)
# 'get-location' can read from container address
def main [
  1:number <- copy 2
  2:number <- copy 34
  3:number <- copy 35
  4:location <- get-location 1:address:point/lookup, 0:offset
]
+mem: storing 2 in location 4

:(scenario get_location_indirect2)
def main [
  1:number <- copy 2
  2:number <- copy 34
  3:number <- copy 35
  4:address:number <- copy 5/unsafe
  4:address:location/lookup <- get-location 1:address:point/lookup, 0:offset
]
+mem: storing 2 in location 5

//: also allow waiting on a routine to stop running

:(scenario wait_for_routine)
def f1 [
  1:number <- copy 0
  12:number/routine <- start-running f2
  wait-for-routine 12:number/routine
  # now wait for f2 to run and modify location 1 before using its value
  3:number <- copy 1:number
]
def f2 [
  1:number <- copy 34
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
    raise << maybe(get(Recipe, r).name) << "'wait-for-routine' requires exactly one ingredient, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'wait-for-routine' should be a routine id generated by 'start-running', but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_ROUTINE: {
  if (ingredients.at(0).at(0) == Current_routine->id) {
    raise << maybe(current_recipe_name()) << "routine can't wait for itself! " << to_original_string(current_instruction()) << '\n' << end();
    break;
  }
  Current_routine->state = WAITING;
  Current_routine->waiting_on_routine = ingredients.at(0).at(0);
  trace(9998, "run") << "waiting for routine " << ingredients.at(0).at(0) << end();
  break;
}

:(before "End Scheduler State Transitions")
// Wake up any routines waiting for other routines to go to sleep.
// Important: this must come after the scheduler loop above giving routines
// waiting for locations to change a chance to wake up.
for (int i = 0; i < SIZE(Routines); ++i) {
  if (Routines.at(i)->state != WAITING) continue;
  if (!Routines.at(i)->waiting_on_routine) continue;
  int id = Routines.at(i)->waiting_on_routine;
  assert(id != Routines.at(i)->id);  // routine can't wait on itself
  for (int j = 0; j < SIZE(Routines); ++j) {
    if (Routines.at(j)->id == id && Routines.at(j)->state != RUNNING) {
      trace(9999, "schedule") << "waking up routine " << Routines.at(i)->id << end();
      Routines.at(i)->state = RUNNING;
      Routines.at(i)->waiting_on_routine = 0;
    }
  }
}

:(before "End Primitive Recipe Declarations")
SWITCH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "switch", SWITCH);
:(before "End Primitive Recipe Checks")
case SWITCH: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SWITCH: {
  int id = some_other_running_routine();
  if (id) {
    assert(id != Current_routine->id);
    Current_routine->state = WAITING;
    Current_routine->waiting_on_routine = id;
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
