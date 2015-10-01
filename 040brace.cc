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
+after-brace: recipe main
+after-brace: jump 1:offset
+after-brace: copy ...

//: one-time setup
:(after "int main")
  Transform.push_back(transform_braces);

:(code)
void transform_braces(const recipe_ordinal r) {
  const int OPEN = 0, CLOSE = 1;
  // use signed integer for step index because we'll be doing arithmetic on it
  list<pair<int/*OPEN/CLOSE*/, /*step*/long long int> > braces;
  for (long long int index = 0; index < SIZE(Recipe[r].steps); ++index) {
    const instruction& inst = Recipe[r].steps.at(index);
    if (inst.label == "{") {
      trace("brace") << maybe(Recipe[r].name) << "push (open, " << index << ")" << end();
      braces.push_back(pair<int,long long int>(OPEN, index));
    }
    if (inst.label == "}") {
      trace("brace") << "push (close, " << index << ")" << end();
      braces.push_back(pair<int,long long int>(CLOSE, index));
    }
  }
  stack</*step*/long long int> open_braces;
  trace("after-brace") << "recipe " << Recipe[r].name << end();
  for (long long int index = 0; index < SIZE(Recipe[r].steps); ++index) {
    instruction& inst = Recipe[r].steps.at(index);
    if (inst.label == "{") {
      open_braces.push(index);
      continue;
    }
    if (inst.label == "}") {
      open_braces.pop();
      continue;
    }
    if (inst.is_label) continue;
    if (inst.operation != Recipe_ordinal["loop"]
         && inst.operation != Recipe_ordinal["loop-if"]
         && inst.operation != Recipe_ordinal["loop-unless"]
         && inst.operation != Recipe_ordinal["break"]
         && inst.operation != Recipe_ordinal["break-if"]
         && inst.operation != Recipe_ordinal["break-unless"]) {
      trace("after-brace") << inst.name << " ..." << end();
      continue;
    }
    // check for errors
    if (inst.name.find("-if") != string::npos || inst.name.find("-unless") != string::npos) {
      if (inst.ingredients.empty()) {
        raise << inst.name << " expects 1 or 2 ingredients, but got none\n" << end();
        continue;
      }
    }
    // update instruction operation
    if (inst.name.find("-if") != string::npos)
      inst.operation = Recipe_ordinal["jump-if"];
    else if (inst.name.find("-unless") != string::npos)
      inst.operation = Recipe_ordinal["jump-unless"];
    else
      inst.operation = Recipe_ordinal["jump"];
    // check for explicitly provided targets
    if (inst.name.find("-if") != string::npos || inst.name.find("-unless") != string::npos) {
      // conditional branches check arg 1
      if (SIZE(inst.ingredients) > 1 && is_literal(inst.ingredients.at(1))) {
        trace("after-brace") << "jump " << inst.ingredients.at(1).name << ":offset" << end();
        continue;
      }
    }
    else {
      // unconditional branches check arg 0
      if (!inst.ingredients.empty() && is_literal(inst.ingredients.at(0))) {
        trace("after-brace") << "jump " << inst.ingredients.at(0).name << ":offset" << end();
        continue;
      }
    }
    // if implicit, compute target
    reagent target;
    target.types.push_back(Type_ordinal["offset"]);
    target.set_value(0);
    if (open_braces.empty())
      raise << inst.name << " needs a '{' before\n" << end();
    else if (inst.name.find("loop") != string::npos)
      target.set_value(open_braces.top()-index);
    else  // break instruction
      target.set_value(matching_brace(open_braces.top(), braces, r) - index - 1);
    inst.ingredients.push_back(target);
    // log computed target
    if (inst.name.find("-if") != string::npos)
      trace("after-brace") << "jump-if " << inst.ingredients.at(0).name << ", " << no_scientific(target.value) << ":offset" << end();
    else if (inst.name.find("-unless") != string::npos)
      trace("after-brace") << "jump-unless " << inst.ingredients.at(0).name << ", " << no_scientific(target.value) << ":offset" << end();
    else
      trace("after-brace") << "jump " << no_scientific(target.value) << ":offset" << end();
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
  raise << maybe(Recipe[r].name) << "unbalanced '{'\n" << end();
  return SIZE(Recipe[r].steps);  // exit current routine
}

// temporarily suppress run
void transform(string form) {
  load(form);
  transform_all();
}

//: Make sure these pseudo recipes get consistent numbers in all tests, even
//: though they aren't implemented.

:(before "End Primitive Recipe Declarations")
BREAK,
BREAK_IF,
BREAK_UNLESS,
LOOP,
LOOP_IF,
LOOP_UNLESS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["break"] = BREAK;
Recipe_ordinal["break-if"] = BREAK_IF;
Recipe_ordinal["break-unless"] = BREAK_UNLESS;
Recipe_ordinal["loop"] = LOOP;
Recipe_ordinal["loop-if"] = LOOP_IF;
Recipe_ordinal["loop-unless"] = LOOP_UNLESS;

:(scenario loop)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    3:number <- copy 0
    loop
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump -2:offset

:(scenario break_empty_block)
recipe main [
  1:number <- copy 0
  {
    break
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: jump 0:offset

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
+after-brace: recipe main
+after-brace: copy ...
+after-brace: jump 0:offset
+after-brace: jump 0:offset

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
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump 1:offset
+after-brace: copy ...
+after-brace: jump 0:offset

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
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump-if 2, 1:offset
+after-brace: copy ...
+after-brace: jump 0:offset

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
+after-brace: jump 4:offset

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
+after-brace: jump 3:offset

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
+after-brace: jump 2:offset

:(scenario break_label)
% Hide_warnings = true;
recipe main [
  1:number <- copy 0
  {
    break +foo:offset
  }
]
+after-brace: jump +foo:offset

:(scenario break_unless)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    break-unless 2:number
    3:number <- copy 0
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump-unless 2, 1:offset
+after-brace: copy ...

:(scenario loop_unless)
recipe main [
  1:number <- copy 0
  2:number <- copy 0
  {
    loop-unless 2:number
    3:number <- copy 0
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump-unless 2, -1:offset
+after-brace: copy ...

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
+after-brace: recipe main
+after-brace: jump-if 4, -5:offset

:(scenario loop_label)
recipe main [
  1:number <- copy 0
  +foo
  2:number <- copy 0
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...

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

:(scenario break_outside_braces_warns)
% Hide_warnings = true;
recipe main [
  break
]
+warn: break needs a '{' before

:(scenario break_conditional_without_ingredient_warns)
% Hide_warnings = true;
recipe main [
  {
    break-if
  }
]
+warn: break-if expects 1 or 2 ingredients, but got none
