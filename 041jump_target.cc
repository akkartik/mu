//: Support jumps to special labels called 'targets'. Targets must be in the
//: same recipe as the jump, and must be unique in that recipe. Targets always
//: start with a '+'.
//:
//: We'll also treat 'break' and 'loop' as jumps. The choice of name is
//: just documentation about intent; use 'break' to indicate you're exiting
//: one or more loop nests, and 'loop' to indicate you're skipping to the next
//: iteration of some containing loop nest.

:(scenario jump_to_label)
recipe main [
  jump +target:label
  1:number <- copy 0
  +target
]
-mem: storing 0 in location 1

:(before "End Mu Types Initialization")
put(Type_ordinal, "label", 0);

:(before "End Instruction Modifying Transforms")
Transform.push_back(transform_labels);  // idempotent

:(code)
void transform_labels(const recipe_ordinal r) {
  map<string, long long int> offset;
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    const instruction& inst = get(Recipe, r).steps.at(i);
    if (!inst.label.empty() && inst.label.at(0) == '+') {
      if (!contains_key(offset, inst.label)) {
        put(offset, inst.label, i);
      }
      else {
        raise_error << maybe(get(Recipe, r).name) << "duplicate label '" << inst.label << "'" << end();
        // have all jumps skip some random but noticeable and deterministic amount of code
        put(offset, inst.label, 9999);
      }
    }
  }
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.name == "jump") {
      replace_offset(inst.ingredients.at(0), offset, i, r);
    }
    if (inst.name == "jump-if" || inst.name == "jump-unless") {
      replace_offset(inst.ingredients.at(1), offset, i, r);
    }
    if ((inst.name == "loop" || inst.name == "break")
        && SIZE(inst.ingredients) == 1) {
      replace_offset(inst.ingredients.at(0), offset, i, r);
    }
    if ((inst.name == "loop-if" || inst.name == "loop-unless"
            || inst.name == "break-if" || inst.name == "break-unless")
        && SIZE(inst.ingredients) == 2) {
      replace_offset(inst.ingredients.at(1), offset, i, r);
    }
  }
}

:(code)
void replace_offset(reagent& x, /*const*/ map<string, long long int>& offset, const long long int current_offset, const recipe_ordinal r) {
  if (!is_literal(x)) {
    raise_error << maybe(get(Recipe, r).name) << "jump target must be offset or label but is " << x.original_string << '\n' << end();
    x.set_value(0);  // no jump by default
    return;
  }
  if (x.initialized) return;
  if (is_integer(x.name)) return;  // non-labels will be handled like other number operands
  if (!is_jump_target(x.name)) {
    raise_error << maybe(get(Recipe, r).name) << "can't jump to label " << x.name << '\n' << end();
    x.set_value(0);  // no jump by default
    return;
  }
  if (!contains_key(offset, x.name)) {
    raise_error << maybe(get(Recipe, r).name) << "can't find label " << x.name << '\n' << end();
    x.set_value(0);  // no jump by default
    return;
  }
  x.set_value(get(offset, x.name) - current_offset);
}

bool is_jump_target(string label) {
  return label.at(0) == '+';
}

:(scenario break_to_label)
recipe main [
  {
    {
      break +target:label
      1:number <- copy 0
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario jump_if_to_label)
recipe main [
  {
    {
      jump-if 1, +target:label
      1:number <- copy 0
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario loop_unless_to_label)
recipe main [
  {
    {
      loop-unless 0, +target:label  # loop/break with a label don't care about braces
      1:number <- copy 0
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario jump_runs_code_after_label)
recipe main [
  # first a few lines of padding to exercise the offset computation
  1:number <- copy 0
  2:number <- copy 0
  3:number <- copy 0
  jump +target:label
  4:number <- copy 0
  +target
  5:number <- copy 0
]
+mem: storing 0 in location 5
-mem: storing 0 in location 4

:(scenario recipe_fails_on_duplicate_jump_target)
% Hide_errors = true;
recipe main [
  +label
  1:number <- copy 0
  +label
  2:number <- copy 0
]
+error: main: duplicate label '+label'

:(scenario jump_ignores_nontarget_label)
% Hide_errors = true;
recipe main [
  # first a few lines of padding to exercise the offset computation
  1:number <- copy 0
  2:number <- copy 0
  3:number <- copy 0
  jump $target:label
  4:number <- copy 0
  $target
  5:number <- copy 0
]
+error: main: can't jump to label $target
