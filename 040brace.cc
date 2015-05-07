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
    1:integer <- copy 0:literal
  }
]
+after-brace: recipe main
+after-brace: jump 1:offset
+after-brace: copy ...

//: one-time setup
:(after "int main")
  Transform.push_back(transform_braces);

:(code)
void transform_braces(const recipe_number r) {
//?   cout << "AAA transform_braces\n"; //? 1
//?   exit(0); //? 1
  const int OPEN = 0, CLOSE = 1;
  list<pair<int/*OPEN/CLOSE*/, /*step*/index_t> > braces;
  for (index_t index = 0; index < Recipe[r].steps.size(); ++index) {
    const instruction& inst = Recipe[r].steps.at(index);
    if (inst.label == "{") {
      trace("brace") << r << ": push (open, " << index << ")";
      braces.push_back(pair<int,index_t>(OPEN, index));
    }
    if (inst.label == "}") {
      trace("brace") << "push (close, " << index << ")";
      braces.push_back(pair<int,index_t>(CLOSE, index));
    }
  }
  stack</*step*/index_t> open_braces;
  trace("after-brace") << "recipe " << Recipe[r].name;
  for (index_t index = 0; index < Recipe[r].steps.size(); ++index) {
    instruction& inst = Recipe[r].steps.at(index);
//?     cout << "AAA " << inst.name << ": " << inst.operation << '\n'; //? 1
    if (inst.label == "{") open_braces.push(index);
    else if (inst.label == "}") open_braces.pop();
    else if (inst.is_label)
      ;  // do nothing
    else if (inst.operation == Recipe_number["loop"]) {
      inst.operation = Recipe_number["jump"];
      if (inst.ingredients.size() > 0 && isa_literal(inst.ingredients.at(0))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(0).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(open_braces.top()-index);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump " << ing.value << ":offset";
        trace("after-brace") << index << ": " << ing.to_string();
        trace("after-brace") << index << ": " << Recipe[r].steps.at(index).ingredients.at(0).to_string();
      }
    }
    else if (inst.operation == Recipe_number["break"]) {
      inst.operation = Recipe_number["jump"];
      if (inst.ingredients.size() > 0 && isa_literal(inst.ingredients.at(0))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(0).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(matching_brace(open_braces.top(), braces) - index - 1);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump " << ing.value << ":offset";
      }
    }
    else if (inst.operation == Recipe_number["loop-if"]) {
      inst.operation = Recipe_number["jump-if"];
      if (inst.ingredients.size() > 1 && isa_literal(inst.ingredients.at(1))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(1).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(open_braces.top()-index);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump-if " << inst.ingredients.at(0).name << ", " << ing.value << ":offset";
      }
    }
    else if (inst.operation == Recipe_number["break-if"]) {
      inst.operation = Recipe_number["jump-if"];
      if (inst.ingredients.size() > 1 && isa_literal(inst.ingredients.at(1))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(1).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(matching_brace(open_braces.top(), braces) - index - 1);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump-if " << inst.ingredients.at(0).name << ", " << ing.value << ":offset";
      }
    }
    else if (inst.operation == Recipe_number["loop-unless"]) {
      inst.operation = Recipe_number["jump-unless"];
      if (inst.ingredients.size() > 1 && isa_literal(inst.ingredients.at(1))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(1).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(open_braces.top()-index);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump-unless " << inst.ingredients.at(0).name << ", " << ing.value << ":offset";
      }
    }
    else if (inst.operation == Recipe_number["break-unless"]) {
//?       cout << "AAA break-unless\n"; //? 1
      inst.operation = Recipe_number["jump-unless"];
      if (inst.ingredients.size() > 1 && isa_literal(inst.ingredients.at(1))) {
        // explicit target; a later phase will handle it
        trace("after-brace") << "jump " << inst.ingredients.at(1).name << ":offset";
      }
      else {
        reagent ing;
        ing.set_value(matching_brace(open_braces.top(), braces) - index - 1);
        ing.types.push_back(Type_number["offset"]);
        inst.ingredients.push_back(ing);
        trace("after-brace") << "jump-unless " << inst.ingredients.at(0).name << ", " << ing.value << ":offset";
      }
    }
    else {
      trace("after-brace") << inst.name << " ...";
    }
  }
}

int matching_brace(index_t index, const list<pair<int, index_t> >& braces) {
  int stacksize = 0;
  for (list<pair<int, index_t> >::const_iterator p = braces.begin(); p != braces.end(); ++p) {
    if (p->second < index) continue;
    stacksize += (p->first ? 1 : -1);
    if (stacksize == 0) return p->second;
  }
  assert(false);
  return -1;
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
Recipe_number["break"] = BREAK;
Recipe_number["break-if"] = BREAK_IF;
Recipe_number["break-unless"] = BREAK_UNLESS;
Recipe_number["loop"] = LOOP;
Recipe_number["loop-if"] = LOOP_IF;
Recipe_number["loop-unless"] = LOOP_UNLESS;

:(scenario loop)
recipe main [
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
  {
    3:integer <- copy 0:literal
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
  1:integer <- copy 0:literal
  {
    break
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: jump 0:offset

:(scenario break_cascading)
recipe main [
  1:integer <- copy 0:literal
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

:(scenario break_cascading2)
recipe main [
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
  {
    break
    3:integer <- copy 0:literal
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
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
  {
    break-if 2:integer
    3:integer <- copy 0:literal
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
  1:integer <- copy 0:literal
  {
    2:integer <- copy 0:literal
    break
    {
      3:integer <- copy 0:literal
    }
    4:integer <- copy 0:literal
  }
]
+after-brace: jump 4:offset

:(scenario break_nested_degenerate)
recipe main [
  1:integer <- copy 0:literal
  {
    2:integer <- copy 0:literal
    break
    {
    }
    4:integer <- copy 0:literal
  }
]
+after-brace: jump 3:offset

:(scenario break_nested_degenerate2)
recipe main [
  1:integer <- copy 0:literal
  {
    2:integer <- copy 0:literal
    break
    {
    }
  }
]
+after-brace: jump 2:offset

:(scenario break_label)
recipe main [
  1:integer <- copy 0:literal
  {
    break +foo:offset
  }
]
+after-brace: jump +foo:offset

:(scenario break_unless)
recipe main [
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
  {
    break-unless 2:integer
    3:integer <- copy 0:literal
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump-unless 2, 1:offset
+after-brace: copy ...

:(scenario loop_unless)
recipe main [
  1:integer <- copy 0:literal
  2:integer <- copy 0:literal
  {
    loop-unless 2:integer
    3:integer <- copy 0:literal
  }
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...
+after-brace: jump-unless 2, -1:offset
+after-brace: copy ...

:(scenario loop_nested)
recipe main [
  1:integer <- copy 0:literal
  {
    2:integer <- copy 0:literal
    {
      3:integer <- copy 0:literal
    }
    loop-if 4:boolean
    5:integer <- copy 0:literal
  }
]
+after-brace: recipe main
+after-brace: jump-if 4, -5:offset

:(scenario loop_label)
recipe main [
  1:integer <- copy 0:literal
  +foo
  2:integer <- copy 0:literal
]
+after-brace: recipe main
+after-brace: copy ...
+after-brace: copy ...

//: test how things actually run
:(scenarios run)
:(scenario brace_conversion_and_run)
#? % Trace_stream->dump_layer = "run";
recipe test-factorial [
  1:integer <- copy 5:literal
  2:integer <- copy 1:literal
  {
    3:boolean <- equal 1:integer 1:literal
    break-if 3:boolean
#    $print 1:integer
    2:integer <- multiply 2:integer, 1:integer
    1:integer <- subtract 1:integer, 1:literal
    loop
  }
  4:integer <- copy 2:integer  # trigger a read
]
+mem: location 2 is 120
