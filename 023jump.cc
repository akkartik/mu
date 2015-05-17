//: Jump primitives

:(scenario jump_can_skip_instructions)
recipe main [
  jump 1:offset
  1:number <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 0 is 1
-run: instruction main/1
-mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
JUMP,
:(before "End Primitive Recipe Numbers")
Recipe_number["jump"] = JUMP;
:(before "End Primitive Recipe Implementations")
case JUMP: {
  assert(current_instruction().ingredients.at(0).initialized);
  assert(ingredients.size() == 1);
  assert(ingredients.at(0).size() == 1);  // scalar
  instruction_counter += ingredients.at(0).at(0);
  trace("run") << "jumping to instruction " << instruction_counter+1;
  break;
}

//: special type to designate jump targets
:(before "End Mu Types Initialization")
Type_number["offset"] = 0;

:(scenario jump_backward)
recipe main [
  jump 1:offset  # 0 -+
  jump 1:offset  #    |   +-+ 1
                 #   \/  /\ |
  jump -2:offset #  2 +-->+ |
]                #         \/ 3
+run: instruction main/0
+run: instruction main/2
+run: instruction main/1

:(before "End Primitive Recipe Declarations")
JUMP_IF,
:(before "End Primitive Recipe Numbers")
Recipe_number["jump-if"] = JUMP_IF;
:(before "End Primitive Recipe Implementations")
case JUMP_IF: {
  assert(current_instruction().ingredients.at(1).initialized);
  assert(ingredients.size() == 2);
  assert(ingredients.at(0).size() == 1);  // scalar
  if (!ingredients.at(0).at(0)) {
    trace("run") << "jump-if fell through";
    break;
  }
  assert(ingredients.at(1).size() == 1);  // scalar
  instruction_counter += ingredients.at(1).at(0);
  trace("run") << "jumping to instruction " << instruction_counter+1;
  break;
}

:(scenario jump_if)
recipe main [
  jump-if 999:literal, 1:offset
  1:number <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 1 is 1
+run: jumping to instruction 2
-run: instruction main/1
-mem: storing 1 in location 1

:(scenario jump_if_fallthrough)
recipe main [
  jump-if 0:literal, 1:offset
  123:number <- copy 1:literal
]
+run: instruction main/0
+run: jump-if fell through
+run: instruction main/1
+mem: storing 1 in location 123

:(before "End Primitive Recipe Declarations")
JUMP_UNLESS,
:(before "End Primitive Recipe Numbers")
Recipe_number["jump-unless"] = JUMP_UNLESS;
:(before "End Primitive Recipe Implementations")
case JUMP_UNLESS: {
  assert(current_instruction().ingredients.at(1).initialized);
  assert(ingredients.size() == 2);
  assert(ingredients.at(0).size() == 1);  // scalar
  if (ingredients.at(0).at(0)) {
    trace("run") << "jump-unless fell through";
    break;
  }
  assert(ingredients.at(1).size() == 1);  // scalar
  instruction_counter += ingredients.at(1).at(0);
  trace("run") << "jumping to instruction " << instruction_counter+1;
  break;
}

:(scenario jump_unless)
recipe main [
  jump-unless 0:literal, 1:offset
  1:number <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 1 is 1
+run: jumping to instruction 2
-run: instruction main/1
-mem: storing 1 in location 1

:(scenario jump_unless_fallthrough)
recipe main [
  jump-unless 999:literal, 1:offset
  123:number <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 0 is 999
+run: jump-unless fell through
+run: instruction main/1
+mem: storing 1 in location 123
