//: So far the recipes we define can't run each other. Let's fix that.

:(scenario calling_recipe)
recipe main [
  f
]
recipe f [
  3:number <- add 2:literal, 2:literal
]
+mem: storing 4 in location 3

:(scenario return_on_fallthrough)
recipe main [
  f
  1:number <- copy 34:literal
  2:number <- copy 34:literal
  3:number <- copy 34:literal
]
recipe f [
  4:number <- copy 34:literal
  5:number <- copy 34:literal
]
+run: instruction main/0
+run: instruction f/0
+run: instruction f/1
+run: instruction main/1
+run: instruction main/2
+run: instruction main/3

:(before "struct routine {")
// Everytime a recipe runs another, we interrupt it and start running the new
// recipe. When that finishes, we continue this one where we left off.
// This requires maintaining a 'stack' of interrupted recipes or 'calls'.
struct call {
  recipe_number running_recipe;
  long long int running_step_index;
  // End call Fields
  call(recipe_number r) :running_recipe(r), running_step_index(0) {}
};
typedef list<call> call_stack;

:(replace{} "struct routine")
struct routine {
  call_stack calls;
  // End routine Fields
  routine(recipe_number r);
  bool completed() const;
  const vector<instruction>& steps() const;
};
:(code)
routine::routine(recipe_number r) {
  calls.push_front(call(r));
  // End routine Constructor
}

//:: now update routine's helpers

:(replace{} "inline long long int& current_step_index()")
inline long long int& current_step_index() {
  assert(!Current_routine->calls.empty());
  return Current_routine->calls.front().running_step_index;
}
:(replace{} "inline const string& current_recipe_name()")
inline const string& current_recipe_name() {
  assert(!Current_routine->calls.empty());
  return Recipe[Current_routine->calls.front().running_recipe].name;
}
:(replace{} "inline const instruction& current_instruction()")
inline const instruction& current_instruction() {
  assert(!Current_routine->calls.empty());
  return Recipe[Current_routine->calls.front().running_recipe].steps.at(Current_routine->calls.front().running_step_index);
}

:(replace{} "default:" following "End Primitive Recipe Implementations")
default: {
  // not a primitive; try to look up the book of recipes
  if (Recipe.find(current_instruction().operation) == Recipe.end()) {
    raise << "undefined operation " << current_instruction().operation << ": " << current_instruction().to_string() << '\n';
    break;
  }
  Current_routine->calls.push_front(call(current_instruction().operation));
  continue;  // not done with caller; don't increment current_step_index()
}

//:: finally, we need to fix the termination conditions for the run loop

:(replace{} "inline bool routine::completed() const")
inline bool routine::completed() const {
  return calls.empty();
}

inline const vector<instruction>& routine::steps() const {
  assert(!calls.empty());
  return Recipe[calls.front().running_recipe].steps;
}

:(before "Running One Instruction")
// when we reach the end of one call, we may reach the end of the one below
// it, and the one below that, and so on
while (current_step_index() >= SIZE(Current_routine->steps())) {
  Current_routine->calls.pop_front();
  if (Current_routine->calls.empty()) return;
  // todo: no results returned warning
  ++current_step_index();
}

:(before "End Includes")
#include <stack>
using std::stack;
