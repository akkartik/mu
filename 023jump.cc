//: Jump primitives

:(scenario jump_can_skip_instructions)
#? % Trace_stream->dump_layer = "all"; #? 1
recipe main [
  jump 1:offset
  1:number <- copy 1:literal
]
+run: jump 1:offset
-run: 1:number <- copy 1:literal
-mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
JUMP,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["jump"] = JUMP;
:(before "End Primitive Recipe Implementations")
case JUMP: {
  assert(current_instruction().ingredients.at(0).initialized);
  assert(SIZE(ingredients) == 1);
  assert(scalar(ingredients.at(0)));
  current_step_index() += ingredients.at(0).at(0)+1;
  trace(Primitive_recipe_depth, "run") << "jumping to instruction " << current_step_index();
  continue;  // skip rest of this instruction
}

//: special type to designate jump targets
:(before "End Mu Types Initialization")
Type_ordinal["offset"] = 0;

:(scenario jump_backward)
recipe main [
  jump 1:offset  # 0 -+
  jump 3:offset  #    |   +-+ 1
                 #   \/  /\ |
  jump -2:offset #  2 +-->+ |
]                #         \/ 3
+run: jump 1:offset
+run: jump -2:offset
+run: jump 3:offset

:(before "End Primitive Recipe Declarations")
JUMP_IF,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["jump-if"] = JUMP_IF;
:(before "End Primitive Recipe Implementations")
case JUMP_IF: {
  assert(current_instruction().ingredients.at(1).initialized);
  assert(SIZE(ingredients) == 2);
  assert(scalar(ingredients.at(0)));
  if (!ingredients.at(0).at(0)) {
    trace(Primitive_recipe_depth, "run") << "jump-if fell through";
    break;
  }
  assert(scalar(ingredients.at(1)));
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(Primitive_recipe_depth, "run") << "jumping to instruction " << current_step_index();
  continue;  // skip rest of this instruction
}

:(scenario jump_if)
recipe main [
  jump-if 999:literal, 1:offset
  123:number <- copy 1:literal
]
+run: jump-if 999:literal, 1:offset
+run: jumping to instruction 2
-run: 1:number <- copy 1:literal
-mem: storing 1 in location 123

:(scenario jump_if_fallthrough)
recipe main [
  jump-if 0:literal, 1:offset
  123:number <- copy 1:literal
]
+run: jump-if 0:literal, 1:offset
+run: jump-if fell through
+run: 123:number <- copy 1:literal
+mem: storing 1 in location 123

:(before "End Primitive Recipe Declarations")
JUMP_UNLESS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["jump-unless"] = JUMP_UNLESS;
:(before "End Primitive Recipe Implementations")
case JUMP_UNLESS: {
  assert(current_instruction().ingredients.at(1).initialized);
  assert(SIZE(ingredients) == 2);
  assert(scalar(ingredients.at(0)));
  if (ingredients.at(0).at(0)) {
    trace(Primitive_recipe_depth, "run") << "jump-unless fell through";
    break;
  }
  assert(scalar(ingredients.at(1)));
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(Primitive_recipe_depth, "run") << "jumping to instruction " << current_step_index();
  continue;  // skip rest of this instruction
}

:(scenario jump_unless)
recipe main [
  jump-unless 0:literal, 1:offset
  123:number <- copy 1:literal
]
+run: jump-unless 0:literal, 1:offset
+run: jumping to instruction 2
-run: 123:number <- copy 1:literal
-mem: storing 1 in location 123

:(scenario jump_unless_fallthrough)
recipe main [
  jump-unless 999:literal, 1:offset
  123:number <- copy 1:literal
]
+run: jump-unless 999:literal, 1:offset
+run: jump-unless fell through
+run: 123:number <- copy 1:literal
+mem: storing 1 in location 123
