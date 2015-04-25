//: Jump primitives

:(before "End Primitive Recipe Declarations")
JUMP,
:(before "End Primitive Recipe Numbers")
Recipe_number["jump"] = JUMP;
:(before "End Primitive Recipe Implementations")
case JUMP: {
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].value;
  current_step_index() += current_instruction().ingredients[0].value;
  trace("run") << "jumping to instruction " << current_step_index()+1;
  break;
}

:(scenario jump_can_skip_instructions)
recipe main [
  jump 1:offset
  1:integer <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 0 is 1
-run: instruction main/1
-mem: storing 1 in location 1

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
  vector<int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 0 is " << arg0[0];
  if (!arg0[0]) {
    trace("run") << "jump-if fell through";
    break;
  }
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  current_step_index() += current_instruction().ingredients[1].value;
  trace("run") << "jumping to instruction " << current_step_index()+1;
  break;
}

:(scenario jump_if)
recipe main [
  jump-if 999:literal 1:offset
  1:integer <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 1 is 1
+run: jumping to instruction 2
-run: instruction main/1
-mem: storing 1 in location 1

:(scenario jump_if_fallthrough)
recipe main [
  jump-if 0:literal 1:offset
  123:integer <- copy 1:literal
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
  vector<int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  trace("run") << "ingredient 0 is " << arg0[0];
  if (arg0[0]) {
    trace("run") << "jump-unless fell through";
    break;
  }
  trace("run") << "ingredient 1 is " << current_instruction().ingredients[1].name;
  current_step_index() += current_instruction().ingredients[1].value;
  trace("run") << "jumping to instruction " << current_step_index()+1;
  break;
}

:(scenario jump_unless)
recipe main [
  jump-unless 0:literal 1:offset
  1:integer <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 1 is 1
+run: jumping to instruction 2
-run: instruction main/1
-mem: storing 1 in location 1

:(scenario jump_unless_fallthrough)
recipe main [
  jump-unless 999:literal 1:offset
  123:integer <- copy 1:literal
]
+run: instruction main/0
+run: ingredient 0 is 999
+run: jump-unless fell through
+run: instruction main/1
+mem: storing 1 in location 123
