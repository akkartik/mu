//: Jump primitives

:(scenario jump_can_skip_instructions)
def main [
  jump 1:offset
  1:number <- copy 1
]
+run: jump {1: "offset"}
-run: {1: "number"} <- copy {1: "literal"}
-mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
JUMP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump", JUMP);
:(before "End Primitive Recipe Checks")
case JUMP: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'jump' requires exactly one ingredient, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'jump' should be a label or offset, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP: {
  assert(current_instruction().ingredients.at(0).initialized);
  current_step_index() += ingredients.at(0).at(0)+1;
  trace(9998, "run") << "jumping to instruction " << current_step_index() << end();
  continue;  // skip rest of this instruction
}

//: special type to designate jump targets
:(before "End Mu Types Initialization")
put(Type_ordinal, "offset", 0);

:(scenario jump_backward)
def main [
  jump 1:offset  # 0 -+
  jump 3:offset  #    |   +-+ 1
                 #   \/  /\ |
  jump -2:offset #  2 +-->+ |
]                #         \/ 3
+run: jump {1: "offset"}
+run: jump {-2: "offset"}
+run: jump {3: "offset"}

:(before "End Primitive Recipe Declarations")
JUMP_IF,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump-if", JUMP_IF);
:(before "End Primitive Recipe Checks")
case JUMP_IF: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'jump-if' requires exactly two ingredients, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'jump-if' requires a boolean for its first ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "'jump-if' requires a label or offset for its second ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  // End JUMP_IF Checks
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP_IF: {
  assert(current_instruction().ingredients.at(1).initialized);
  if (!ingredients.at(0).at(0)) {
    trace(9998, "run") << "jump-if fell through" << end();
    break;
  }
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(9998, "run") << "jumping to instruction " << current_step_index() << end();
  continue;  // skip rest of this instruction
}

:(scenario jump_if)
def main [
  jump-if 999, 1:offset
  123:number <- copy 1
]
+run: jump-if {999: "literal"}, {1: "offset"}
+run: jumping to instruction 2
-run: {1: "number"} <- copy {1: "literal"}
-mem: storing 1 in location 123

:(scenario jump_if_fallthrough)
def main [
  jump-if 0, 1:offset
  123:number <- copy 1
]
+run: jump-if {0: "literal"}, {1: "offset"}
+run: jump-if fell through
+run: {123: "number"} <- copy {1: "literal"}
+mem: storing 1 in location 123

:(before "End Primitive Recipe Declarations")
JUMP_UNLESS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump-unless", JUMP_UNLESS);
:(before "End Primitive Recipe Checks")
case JUMP_UNLESS: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'jump-unless' requires exactly two ingredients, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'jump-unless' requires a boolean for its first ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "'jump-unless' requires a label or offset for its second ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  // End JUMP_UNLESS Checks
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP_UNLESS: {
  assert(current_instruction().ingredients.at(1).initialized);
  if (ingredients.at(0).at(0)) {
    trace(9998, "run") << "jump-unless fell through" << end();
    break;
  }
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(9998, "run") << "jumping to instruction " << current_step_index() << end();
  continue;  // skip rest of this instruction
}

:(scenario jump_unless)
def main [
  jump-unless 0, 1:offset
  123:number <- copy 1
]
+run: jump-unless {0: "literal"}, {1: "offset"}
+run: jumping to instruction 2
-run: {123: "number"} <- copy {1: "literal"}
-mem: storing 1 in location 123

:(scenario jump_unless_fallthrough)
def main [
  jump-unless 999, 1:offset
  123:number <- copy 1
]
+run: jump-unless {999: "literal"}, {1: "offset"}
+run: jump-unless fell through
+run: {123: "number"} <- copy {1: "literal"}
+mem: storing 1 in location 123
