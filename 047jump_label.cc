//: Support jumps to labels.
//: We'll also treat 'break' and 'continue' as jumps. The choice of name is
//: just documentation about intent.

:(scenario jump_to_label)
recipe main [
  jump +target:offset
  1:number <- copy 0:literal
  +target
]
-mem: storing 0 in location 1

:(after "int main")
  Transform.push_back(transform_labels);

:(code)
void transform_labels(const recipe_number r) {
  map<string, index_t> offset;
  for (index_t i = 0; i < Recipe[r].steps.size(); ++i) {
    const instruction& inst = Recipe[r].steps.at(i);
    if (!inst.label.empty()) offset[inst.label] = i;
  }
  for (index_t i = 0; i < Recipe[r].steps.size(); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    if (inst.operation == Recipe_number["jump"]) {
//?       cerr << inst.to_string() << '\n'; //? 1
      replace_offset(inst.ingredients.at(0), offset, i, r);
    }
    if (inst.operation == Recipe_number["jump-if"] || inst.operation == Recipe_number["jump-unless"]) {
      replace_offset(inst.ingredients.at(1), offset, i, r);
    }
    if ((inst.operation == Recipe_number["loop"] || inst.operation == Recipe_number["break"])
        && inst.ingredients.size() == 1) {
      replace_offset(inst.ingredients.at(0), offset, i, r);
    }
    if ((inst.operation == Recipe_number["loop-if"] || inst.operation == Recipe_number["loop-unless"]
            || inst.operation == Recipe_number["break-if"] || inst.operation == Recipe_number["break-unless"])
        && inst.ingredients.size() == 2) {
      replace_offset(inst.ingredients.at(1), offset, i, r);
    }
  }
}

:(code)
void replace_offset(reagent& x, /*const*/ map<string, index_t>& offset, const index_t current_offset, const recipe_number r) {
//?   cerr << "AAA " << x.to_string() << '\n'; //? 1
  assert(isa_literal(x));
//?   cerr << "BBB " << x.to_string() << '\n'; //? 1
  assert(!x.initialized);
//?   cerr << "CCC " << x.to_string() << '\n'; //? 1
  if (is_number(x.name)) return;  // non-labels will be handled like other number operands
//?   cerr << "DDD " << x.to_string() << '\n'; //? 1
  if (offset.find(x.name) == offset.end())
    raise << "can't find label " << x.name << " in routine " << Recipe[r].name << '\n';
  x.set_value(offset[x.name]-current_offset);
}

:(scenario break_to_label)
recipe main [
#?   $print [aaa]
  {
    {
      break +target:offset
      1:number <- copy 0:literal
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario jump_if_to_label)
recipe main [
  {
    {
      jump-if 1:literal, +target:offset
      1:number <- copy 0:literal
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario loop_unless_to_label)
recipe main [
  {
    {
      loop-unless 0:literal, +target:offset  # loop/break with a label don't care about braces
      1:number <- copy 0:literal
    }
  }
  +target
]
-mem: storing 0 in location 1

:(scenario jump_runs_code_after_label)
recipe main [
  # first a few lines of padding to exercise the offset computation
  1:number <- copy 0:literal
  2:number <- copy 0:literal
  3:number <- copy 0:literal
  jump +target:offset
  4:number <- copy 0:literal
  +target
  5:number <- copy 0:literal
]
+mem: storing 0 in location 5
-mem: storing 0 in location 4
