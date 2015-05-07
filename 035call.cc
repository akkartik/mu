//: So far the recipes we define can't run each other. Let's fix that.

:(scenario calling_recipe)
recipe main [
  f
]
recipe f [
  3:integer <- add 2:literal, 2:literal
]
+mem: storing 4 in location 3

:(scenario return_on_fallthrough)
recipe main [
  f
  1:integer <- copy 34:literal
  2:integer <- copy 34:literal
  3:integer <- copy 34:literal
]
recipe f [
  4:integer <- copy 34:literal
  5:integer <- copy 34:literal
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
  index_t running_step_index;
  // End call Fields
  call(recipe_number r) :running_recipe(r), running_step_index(0) {}
};
typedef stack<call> call_stack;

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
  calls.push(call(r));
  // End routine Constructor
}

//:: now update routine's helpers

:(replace{} "inline index_t& current_step_index()")
inline index_t& current_step_index() {
  return Current_routine->calls.top().running_step_index;
}
:(replace{} "inline const string& current_recipe_name()")
inline const string& current_recipe_name() {
  return Recipe[Current_routine->calls.top().running_recipe].name;
}
:(replace{} "inline const instruction& current_instruction()")
inline const instruction& current_instruction() {
  return Recipe[Current_routine->calls.top().running_recipe].steps.at(Current_routine->calls.top().running_step_index);
}

:(replace{} "default:" following "End Primitive Recipe Implementations")
default: {
  // not a primitive; try to look up the book of recipes
  if (Recipe.find(current_instruction().operation) == Recipe.end()) {
    raise << "undefined operation " << current_instruction().operation << ": " << current_instruction().to_string() << '\n';
    break;
  }
  Current_routine->calls.push(call(current_instruction().operation));
  continue;  // not done with caller; don't increment current_step_index()
}

//:: finally, we need to fix the termination conditions for the run loop

:(replace{} "inline bool routine::completed() const")
inline bool routine::completed() const {
  return calls.empty();
}

inline const vector<instruction>& routine::steps() const {
  return Recipe[calls.top().running_recipe].steps;
}

:(before "Running One Instruction")
// when we reach the end of one call, we may reach the end of the one below
// it, and the one below that, and so on
while (current_step_index() >= Current_routine->steps().size()) {
  Current_routine->calls.pop();
  if (Current_routine->calls.empty()) return;
  // todo: no results returned warning
  ++current_step_index();
}

:(before "End Includes")
#include <stack>
using std::stack;
