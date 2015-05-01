//: Some pseudo-primitives to support writing tests in mu.
//: When we throw out the C layer these will require more work.

:(scenario run)
#? % Trace_stream->dump_layer = "all";
recipe main [
  run [
    1:integer <- copy 13:literal
  ]
]
+mem: storing 13 in location 1

:(before "End Globals")
size_t Num_temporary_recipes = 0;
:(before "End Setup")
Num_temporary_recipes = 0;

:(before "End Primitive Recipe Declarations")
RUN,
:(before "End Primitive Recipe Numbers")
Recipe_number["run"] = RUN;
:(before "End Primitive Recipe Implementations")
case RUN: {
//?   cout << "recipe " << current_instruction().ingredients[0].name << '\n'; //? 1
  ostringstream tmp;
  tmp << "recipe tmp" << Num_temporary_recipes++ << " [ " << current_instruction().ingredients[0].name << " ]";
  vector<recipe_number> tmp_recipe = load(tmp.str());
  transform_all();
//?   cout << tmp_recipe[0] << ' ' << Recipe_number["main"] << '\n'; //? 1
  Current_routine->calls.push(call(tmp_recipe[0]));
  continue;  // not done with caller; don't increment current_step_index()
}

:(scenario run_multiple)
recipe main [
  run [
    1:integer <- copy 13:literal
  ]
  run [
    2:integer <- copy 13:literal
  ]
]
+mem: storing 13 in location 1
+mem: storing 13 in location 2
