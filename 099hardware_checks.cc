//: Let's raise errors when students use real hardware in any recipes besides
//: 'main'. Part of the goal is to teach them testing hygiene and dependency
//: injection.
//:
//: This is easy to sidestep, it's for feedback rather than safety.

:(before "End Globals")
vector<type_tree*> Real_hardware_types;
:(before "Begin transform_all")
setup_real_hardware_types();
:(before "End transform_all")
teardown_real_hardware_types();
:(code)
void setup_real_hardware_types() {
  Real_hardware_types.push_back(parse_type("address:screen"));
  Real_hardware_types.push_back(parse_type("address:console"));
  Real_hardware_types.push_back(parse_type("address:resources"));
}
type_tree* parse_type(string s) {
  reagent x("x:"+s);
  type_tree* result = x.type;
  x.type = NULL;  // don't deallocate on return
  return result;
}
void teardown_real_hardware_types() {
  for (int i = 0;  i < SIZE(Real_hardware_types);  ++i)
    delete Real_hardware_types.at(i);
  Real_hardware_types.clear();
}

:(before "End Checks")
Transform.push_back(check_for_misuse_of_real_hardware);
:(code)
void check_for_misuse_of_real_hardware(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  if (caller.name == "main") return;
  if (starts_with(caller.name, "scenario_")) return;
  trace(101, "transform") << "--- check if recipe " << caller.name << " has any dependency-injection mistakes" << end();
  for (int index = 0;  index < SIZE(caller.steps);  ++index) {
    const instruction& inst = caller.steps.at(index);
    if (is_primitive(inst.operation)) continue;
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
      const reagent& ing = inst.ingredients.at(i);
      if (!is_literal(ing) || ing.name != "0") continue;
      const recipe& callee = get(Recipe, inst.operation);
      if (!callee.has_header) continue;
      if (i >= SIZE(callee.ingredients)) continue;
      const reagent& expected_ing = callee.ingredients.at(i);
      for (int j = 0;  j < SIZE(Real_hardware_types);  ++j) {
        if (*Real_hardware_types.at(j) == *expected_ing.type)
          raise << maybe(caller.name) << "'" << to_original_string(inst) << "': only 'main' can pass 0 into a " << to_string(expected_ing.type) << '\n' << end();
      }
    }
  }
}

:(scenarios transform)
:(scenario warn_on_using_real_screen_directly_in_non_main_recipe)
% Hide_errors = true;
def foo [
  print 0, 34
]
+error: foo: 'print 0, 34': only 'main' can pass 0 into a (address screen)
