//: Structured programming
//:
//: Our jump recipes are quite inconvenient to use, so mu provides a
//: lightweight tool called 'transform_braces' to work in a slightly more
//: convenient format with nested braces:
//:
//:   {
//:     some instructions
//:     {
//:       more instructions
//:     }
//:   }
//:
//: Braces are just labels, they require no special parsing. The pseudo
//: recipes 'loop' and 'break' jump to just after the enclosing '{' and '}'
//: respectively.
//:
//: Conditional and unconditional 'loop' and 'break' should give us 80% of the
//: benefits of the control-flow primitives we're used to in other languages,
//: like 'if', 'while', 'for', etc.

:(scenarios transform)
:(scenario brace_conversion)
recipe main [
  {
    break
    1:number <- copy 0
  }
]
+transform: --- transform braces for recipe main
+transform: jump 1:offset
+transform: copy ...

:(before "End Instruction Modifying Transforms")
Transform.push_back(transform_braces);  // idempotent

:(code)
void transform_braces(const recipe_ordinal r) {
  const int OPEN = 0, CLOSE = 1;
  // use signed integer for step index because we'll be doing arithmetic on it
  list<pair<int/*OPEN/CLOSE*/, /*step*/long long int> > braces;
  trace(9991, "transform") << "--- transform braces for recipe " << get(Recipe, r).name << end();
//?   cerr << "--- transform braces for recipe " << get(Recipe, r).name << '\n';
  for (long long int index = 0; index < SIZE(get(Recipe, r).steps); ++index) {
    const instruction& inst = get(Recipe, r).steps.at(index);
    if (inst.label == "{") {
      trace(9993, "transform") << maybe(get(Recipe, r).name) << "push (open, " << index << ")" << end();
      braces.push_back(pair<int,long long int>(OPEN, index));
    }
    if (inst.label == "}") {
      trace(9993, "transform") << "push (close, " << index << ")" << end();
      braces.push_back(pair<int,long long int>(CLOSE, index));
    }
  }
  stack</*step*/long long int> open_braces;
  for (long long int index = 0; index < SIZE(get(Recipe, r).steps); ++index) {
    instruction& inst = get(Recipe, r).steps.at(index);
    if (inst.label == "{") {
      open_braces.push(index);
      continue;
    }
    if (inst.label == "}") {
      if (open_braces.empty()) {
        raise_error << "missing '{' in " << get(Recipe, r).name << '\n' << end();
        return;
      }
      open_braces.pop();
      continue;
    }
    if (inst.is_label) continue;
    if (inst.old_name != "loop"
         && inst.old_name != "loop-if"
         && inst.old_name != "loop-unless"
         && inst.old_name != "break"
         && inst.old_name != "break-if"
         && inst.old_name != "break-unless") {
      trace(9992, "transform") << inst.old_name << " ..." << end();
      continue;
    }
    // check for errors
    if (inst.old_name.find("-if") != string::npos || inst.old_name.find("-unless") != string::npos) {
      if (inst.ingredients.empty()) {
        raise_error << inst.old_name << " expects 1 or 2 ingredients, but got none\n" << end();
        continue;
      }
    }
    // update instruction operation
    if (inst.old_name.find("-if") != string::npos) {
      inst.name = "jump-if";
      inst.operation = JUMP_IF;
    }
    else if (inst.old_name.find("-unless") != string::npos) {
      inst.name = "jump-unless";
      inst.operation = JUMP_UNLESS;
    }
    else {
      inst.name = "jump";
      inst.operation = JUMP;
    }
    // check for explicitly provided targets
    if (inst.old_name.find("-if") != string::npos || inst.old_name.find("-unless") != string::npos) {
      // conditional branches check arg 1
      if (SIZE(inst.ingredients) > 1 && is_literal(inst.ingredients.at(1))) {
        trace(9992, "transform") << inst.name << ' ' << inst.ingredients.at(1).name << ":offset" << end();
        continue;
      }
    }
    else {
      // unconditional branches check arg 0
      if (!inst.ingredients.empty() && is_literal(inst.ingredients.at(0))) {
        trace(9992, "transform") << "jump " << inst.ingredients.at(0).name << ":offset" << end();
        continue;
      }
    }
    // if implicit, compute target
    reagent target;
    target.type = new type_tree("offset", get(Type_ordinal, "offset"));
    target.set_value(0);
    if (open_braces.empty())
      raise_error << inst.old_name << " needs a '{' before\n" << end();
    else if (inst.old_name.find("loop") != string::npos)
      target.set_value(open_braces.top()-index);
    else  // break instruction
      target.set_value(matching_brace(open_braces.top(), braces, r) - index - 1);
    inst.ingredients.push_back(target);
    // log computed target
    if (inst.name == "jump")
      trace(9992, "transform") << "jump " << no_scientific(target.value) << ":offset" << end();
    else
      trace(9992, "transform") << inst.name << ' ' << inst.ingredients.at(0).name << ", " << no_scientific(target.value) << ":offset" << end();
  }
}

// returns a signed integer not just so that we can return -1 but also to
// enable future signed arithmetic
long long int matching_brace(long long int index, const list<pair<int, long long int> >& braces, recipe_ordinal r) {
  int stacksize = 0;
  for (list<pair<int, long long int> >::const_iterator p = braces.begin(); p != braces.end(); ++p) {
    if (p->second < index) continue;
    stacksize += (p->first ? 1 : -1);
    if (stacksize == 0) return p->second;
  }
  raise_error << maybe(get(Recipe, r).name) << "unbalanced '{'\n" << end();
  return SIZE(get(Recipe, r).steps);  // exit current routine
}

:(scenario loop)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    3:number <- copy 0
    loop
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...
+transform: copy ...
+transform: jump -2:offset

:(scenario break_empty_block)
recipe main [
  1:number <- copy 0
  {
    break
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: jump 0:offset

:(scenario break_cascading)
recipe main [
  1:number <- copy 0
  {
    break
  }
  {
    break
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: jump 0:offset
+transform: jump 0:offset

:(scenario break_cascading_2)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    break
    3:number <- copy 0
  }
  {
    break
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...
+transform: jump 1:offset
+transform: copy ...
+transform: jump 0:offset

:(scenario break_if)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    break-if 2:number
    3:number <- copy 0
  }
  {
    break
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...
+transform: jump-if 2, 1:offset
+transform: copy ...
+transform: jump 0:offset

:(scenario break_nested)
recipe main [
  1:number <- copy 0
  {
    2:number <- copy 0
    break
    {
      3:number <- copy 0
    }
    4:number <- copy 0
  }
]
+transform: jump 4:offset

:(scenario break_nested_degenerate)
recipe main [
  1:number <- copy 0
  {
    2:number <- copy 0
    break
    {
    }
    4:number <- copy 0
  }
]
+transform: jump 3:offset

:(scenario break_nested_degenerate_2)
recipe main [
  1:number <- copy 0
  {
    2:number <- copy 0
    break
    {
    }
  }
]
+transform: jump 2:offset

:(scenario break_label)
% Hide_errors = true;
recipe main [
  1:number <- copy 0
  {
    break +foo:offset
  }
]
+transform: jump +foo:offset

:(scenario break_unless)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    break-unless 2:number
    3:number <- copy 0
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...
+transform: jump-unless 2, 1:offset
+transform: copy ...

:(scenario loop_unless)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    loop-unless 2:number
    3:number <- copy 0
  }
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...
+transform: jump-unless 2, -1:offset
+transform: copy ...

:(scenario loop_nested)
recipe main [
  1:number <- copy 0
  {
    2:number <- copy 0
    {
      3:number <- copy 0
    }
    loop-if 4:boolean
    5:number <- copy 0
  }
]
+transform: --- transform braces for recipe main
+transform: jump-if 4, -5:offset

:(scenario loop_label)
recipe main [
  1:number <- copy 0
  +foo
  2:number <- copy 0
]
+transform: --- transform braces for recipe main
+transform: copy ...
+transform: copy ...

//: test how things actually run
:(scenarios run)
:(scenario brace_conversion_and_run)
recipe test-factorial [
  1:number <- copy 5
  2:number <- copy 1
  {
    3:boolean <- equal 1:number, 1
    break-if 3:boolean
#    $print 1:number
    2:number <- multiply 2:number, 1:number
    1:number <- subtract 1:number, 1
    loop
  }
  4:number <- copy 2:number  # trigger a read
]
+mem: location 2 is 120

:(scenario break_outside_braces_fails)
% Hide_errors = true;
recipe main [
  break
]
+error: break needs a '{' before

:(scenario break_conditional_without_ingredient_fails)
% Hide_errors = true;
recipe main [
  {
    break-if
  }
]
+error: break-if expects 1 or 2 ingredients, but got none

//: Make sure these pseudo recipes get consistent numbers in all tests, even
//: though they aren't implemented. Allows greater flexibility in ordering
//: transforms.

:(before "End Primitive Recipe Declarations")
BREAK,
BREAK_IF,
BREAK_UNLESS,
LOOP,
LOOP_IF,
LOOP_UNLESS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "break", BREAK);
put(Recipe_ordinal, "break-if", BREAK_IF);
put(Recipe_ordinal, "break-unless", BREAK_UNLESS);
put(Recipe_ordinal, "loop", LOOP);
put(Recipe_ordinal, "loop-if", LOOP_IF);
put(Recipe_ordinal, "loop-unless", LOOP_UNLESS);
:(before "End Primitive Recipe Checks")
case BREAK: break;
case BREAK_IF: break;
case BREAK_UNLESS: break;
case LOOP: break;
case LOOP_IF: break;
case LOOP_UNLESS: break;
