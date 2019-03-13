//: Jump primitives

void test_jump_can_skip_instructions() {
  run(
      "def main [\n"
      "  jump 1:offset\n"
      "  1:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump {1: \"offset\"}\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: {1: \"number\"} <- copy {1: \"literal\"}");
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 1 in location 1");
}

:(before "End Primitive Recipe Declarations")
JUMP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump", JUMP);
:(before "End Primitive Recipe Checks")
case JUMP: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' should get exactly one ingredient\n" << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '" << to_original_string(inst) << "' should be a label or offset, but '" << inst.ingredients.at(0).name << "' has type '" << names_to_string_without_quotes(inst.ingredients.at(0).type) << "'\n" << end();
    break;
  }
  if (!inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'jump' instructions write no products\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP: {
  assert(current_instruction().ingredients.at(0).initialized);
  current_step_index() += ingredients.at(0).at(0)+1;
  trace(Callstack_depth+1, "run") << "jumping to instruction " << current_step_index() << end();
  // skip rest of this instruction
  write_products = false;
  fall_through_to_next_instruction = false;
  break;
}

//: special type to designate jump targets
:(before "End Mu Types Initialization")
put(Type_ordinal, "offset", 0);

:(code)
void test_jump_backward() {
  run(
      "def main [\n"
      "  jump 1:offset\n"  // 0 -+
      "  jump 3:offset\n"  //    |   +-+ 1
                           //   \/  /\ |
      "  jump -2:offset\n" //  2 +-->+ |
      "]\n"                //         \/ 3
  );
  CHECK_TRACE_CONTENTS(
      "run: jump {1: \"offset\"}\n"
      "run: jump {-2: \"offset\"}\n"
      "run: jump {3: \"offset\"}\n"
  );
}

void test_jump_takes_no_products() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num <- jump 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: 'jump' instructions write no products\n"
  );
}

:(before "End Primitive Recipe Declarations")
JUMP_IF,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump-if", JUMP_IF);
:(before "End Primitive Recipe Checks")
case JUMP_IF: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' should get exactly two ingredients\n" << end();
    break;
  }
  if (!is_mu_address(inst.ingredients.at(0)) && !is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' requires a boolean for its first ingredient, but '" << inst.ingredients.at(0).name << "' has type '" << names_to_string_without_quotes(inst.ingredients.at(0).type) << "'\n" << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' requires a label or offset for its second ingredient, but '" << inst.ingredients.at(1).name << "' has type '" << names_to_string_without_quotes(inst.ingredients.at(1).type) << "'\n" << end();
    break;
  }
  if (!inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'jump-if' instructions write no products\n" << end();
    break;
  }
  // End JUMP_IF Checks
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP_IF: {
  assert(current_instruction().ingredients.at(1).initialized);
  if (!scalar_ingredient(ingredients, 0)) {
    trace(Callstack_depth+1, "run") << "jump-if fell through" << end();
    break;
  }
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(Callstack_depth+1, "run") << "jumping to instruction " << current_step_index() << end();
  // skip rest of this instruction
  write_products = false;
  fall_through_to_next_instruction = false;
  break;
}

:(code)
void test_jump_if() {
  run(
      "def main [\n"
      "  jump-if 999, 1:offset\n"
      "  123:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump-if {999: \"literal\"}, {1: \"offset\"}\n"
      "run: jumping to instruction 2\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: {123: \"number\"} <- copy {1: \"literal\"}");
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 1 in location 123");
}

void test_jump_if_fallthrough() {
  run(
      "def main [\n"
      "  jump-if 0, 1:offset\n"
      "  123:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump-if {0: \"literal\"}, {1: \"offset\"}\n"
      "run: jump-if fell through\n"
      "run: {123: \"number\"} <- copy {1: \"literal\"}\n"
      "mem: storing 1 in location 123\n"
  );
}

void test_jump_if_on_address() {
  run(
      "def main [\n"
      "  10:num/alloc-id, 11:num <- copy 0, 999\n"
      "  jump-if 10:&:number, 1:offset\n"
      "  123:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump-if {10: (\"address\" \"number\")}, {1: \"offset\"}\n"
      "run: jumping to instruction 3\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: {123: \"number\"} <- copy {1: \"literal\"}");
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 1 in location 123");
}

:(before "End Primitive Recipe Declarations")
JUMP_UNLESS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "jump-unless", JUMP_UNLESS);
:(before "End Primitive Recipe Checks")
case JUMP_UNLESS: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' should get exactly two ingredients\n" << end();
    break;
  }
  if (!is_mu_address(inst.ingredients.at(0)) && !is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' requires a boolean for its first ingredient, but '" << inst.ingredients.at(0).name << "' has type '" << names_to_string_without_quotes(inst.ingredients.at(0).type) << "'\n" << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "'" << to_original_string(inst) << "' requires a label or offset for its second ingredient, but '" << inst.ingredients.at(1).name << "' has type '" << names_to_string_without_quotes(inst.ingredients.at(1).type) << "'\n" << end();
    break;
  }
  if (!inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'jump' instructions write no products\n" << end();
    break;
  }
  // End JUMP_UNLESS Checks
  break;
}
:(before "End Primitive Recipe Implementations")
case JUMP_UNLESS: {
  assert(current_instruction().ingredients.at(1).initialized);
  if (scalar_ingredient(ingredients, 0)) {
    trace(Callstack_depth+1, "run") << "jump-unless fell through" << end();
    break;
  }
  current_step_index() += ingredients.at(1).at(0)+1;
  trace(Callstack_depth+1, "run") << "jumping to instruction " << current_step_index() << end();
  // skip rest of this instruction
  write_products = false;
  fall_through_to_next_instruction = false;
  break;
}

:(code)
void test_jump_unless() {
  run(
      "def main [\n"
      "  jump-unless 0, 1:offset\n"
      "  123:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump-unless {0: \"literal\"}, {1: \"offset\"}\n"
      "run: jumping to instruction 2\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: {123: \"number\"} <- copy {1: \"literal\"}");
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 1 in location 123");
}

void test_jump_unless_fallthrough() {
  run(
      "def main [\n"
      "  jump-unless 999, 1:offset\n"
      "  123:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: jump-unless {999: \"literal\"}, {1: \"offset\"}\n"
      "run: jump-unless fell through\n"
      "run: {123: \"number\"} <- copy {1: \"literal\"}\n"
      "mem: storing 1 in location 123\n"
  );
}
