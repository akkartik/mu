
:(before "End Globals")
map<index_t, call_stack> Continuation;
index_t Next_continuation_id = 0;
:(before "End Setup")
Continuation.clear();
Next_continuation_id = 0;

:(before "End Mu Types Initialization")
type_number continuation = Type_number["continuation"] = Next_type_number++;
Type[continuation].name = "continuation";

:(before "End Primitive Recipe Declarations")
CURRENT_CONTINUATION,
:(before "End Primitive Recipe Numbers")
Recipe_number["current-continuation"] = CURRENT_CONTINUATION;
:(before "End Primitive Recipe Implementations")
case CURRENT_CONTINUATION: {
  Continuation[Next_continuation_id] = Current_routine->calls;  // deep copy because calls have no pointers
  products.resize(1);
  products.at(0).push_back(Next_continuation_id);
  ++Next_continuation_id;
  break;
}

:(before "End Primitive Recipe Declarations")
CONTINUE_FROM,
:(before "End Primitive Recipe Numbers")
Recipe_number["continue-from"] = CONTINUE_FROM;
:(before "End Primitive Recipe Implementations")
case CONTINUE_FROM: {
  assert(ingredients.at(0).size() == 1);  // scalar
  index_t c = ingredients.at(0).at(0);
  Current_routine->calls = Continuation[c];  // deep copy because calls have no pointers
  // refresh instruction_counter to next instruction after current-continuation
  instruction_counter = current_step_index()+1;
  continue;  // skip the rest of this instruction
}

:(scenario continuation)
# simulate a loop using continuations
recipe main [
  1:number <- copy 0:literal
  2:continuation <- current-continuation
  {
#?     $print 1:number
    3:boolean <- greater-or-equal 1:number, 3:literal
    break-if 3:boolean
    1:number <- add 1:number, 1:literal
    continue-from 2:continuation  # loop
  }
]
+mem: storing 1 in location 1
+mem: storing 2 in location 1
+mem: storing 3 in location 1
-mem: storing 4 in location 1

:(scenario continuation_inside_caller)
recipe main [
  1:number <- copy 0:literal
  2:continuation <- loop-body
  {
    3:boolean <- greater-or-equal 1:number, 3:literal
    break-if 3:boolean
    continue-from 2:continuation  # loop
  }
]

recipe loop-body [
  4:continuation <- current-continuation
  1:number <- add 1:number, 1:literal
]
+mem: storing 1 in location 1
+mem: storing 2 in location 1
+mem: storing 3 in location 1
-mem: storing 4 in location 1
