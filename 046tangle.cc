//: Allow code for recipes to be pulled in from multiple places.
//:
//: TODO: switch recipe.steps to a more efficient data structure.

:(scenario tangle_before)
recipe main [
  1:number <- copy 0:literal
  +label1
  3:number <- copy 0:literal
]

before +label1 [
  2:number <- copy 0:literal
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
+mem: storing 0 in location 3
# nothing else
$mem: 3

//: while loading recipes, load before/after fragments

:(before "End Globals")
map<string /*label*/, recipe> Before_fragments, After_fragments;
:(before "End Setup")
Before_fragments.clear();
After_fragments.clear();

:(before "End Command Handlers")
else if (command == "before") {
  string label = next_word(in);
  recipe tmp = slurp_recipe(in);
  Before_fragments[label].steps.insert(Before_fragments[label].steps.end(), tmp.steps.begin(), tmp.steps.end());
}
else if (command == "after") {
  string label = next_word(in);
  recipe tmp = slurp_recipe(in);
  After_fragments[label].steps.insert(After_fragments[label].steps.begin(), tmp.steps.begin(), tmp.steps.end());
}

//: after all recipes are loaded, insert fragments at appropriate labels

:(after "int main")
  Transform.push_back(insert_fragments);

:(code)
void insert_fragments(const recipe_number r) {
  // Copy into a new vector because insertions invalidate iterators.
  // But this way we can't insert into labels created inside before/after.
  vector<instruction> result;
  for (index_t i = 0; i < Recipe[r].steps.size(); ++i) {
    const instruction inst = Recipe[r].steps.at(i);
    if (!inst.is_label) {
      result.push_back(inst);
      continue;
    }
    if (Before_fragments.find(inst.label) != Before_fragments.end()) {
      result.insert(result.end(), Before_fragments[inst.label].steps.begin(), Before_fragments[inst.label].steps.end());
    }
    result.push_back(inst);
    if (After_fragments.find(inst.label) != After_fragments.end()) {
      result.insert(result.end(), After_fragments[inst.label].steps.begin(), After_fragments[inst.label].steps.end());
    }
  }
//?   for (index_t i = 0; i < result.size(); ++i) { //? 1
//?     cout << result.at(i).to_string() << '\n'; //? 1
//?   } //? 1
  Recipe[r].steps.swap(result);
}

:(scenario tangle_before_and_after)
recipe main [
  1:number <- copy 0:literal
  +label1
  4:number <- copy 0:literal
]
before +label1 [
  2:number <- copy 0:literal
]
after +label1 [
  3:number <- copy 0:literal
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
# label1
+mem: storing 0 in location 3
+mem: storing 0 in location 4
# nothing else
$mem: 4

:(scenario tangle_keeps_labels_separate)
recipe main [
  1:number <- copy 0:literal
  +label1
  +label2
  6:number <- copy 0:literal
]
before +label1 [
  2:number <- copy 0:literal
]
after +label1 [
  3:number <- copy 0:literal
]
before +label2 [
  4:number <- copy 0:literal
]
after +label2 [
  5:number <- copy 0:literal
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
# label1
+mem: storing 0 in location 3
# 'after' fragments for earlier label always go before 'before' fragments for later label
+mem: storing 0 in location 4
# label2
+mem: storing 0 in location 5
+mem: storing 0 in location 6
# nothing else
$mem: 6

:(scenario tangle_stacks_multiple_fragments)
recipe main [
  1:number <- copy 0:literal
  +label1
  6:number <- copy 0:literal
]
before +label1 [
  2:number <- copy 0:literal
]
after +label1 [
  3:number <- copy 0:literal
]
before +label1 [
  4:number <- copy 0:literal
]
after +label1 [
  5:number <- copy 0:literal
]
+mem: storing 0 in location 1
# 'before' fragments stack in order
+mem: storing 0 in location 2
+mem: storing 0 in location 4
# label1
# 'after' fragments stack in reverse order
+mem: storing 0 in location 5
+mem: storing 0 in location 3
+mem: storing 0 in location 6
# nothing else
$mem: 6

:(scenario tangle_supports_fragments_with_multiple_instructions)
recipe main [
  1:number <- copy 0:literal
  +label1
  6:number <- copy 0:literal
]
before +label1 [
  2:number <- copy 0:literal
  3:number <- copy 0:literal
]
after +label1 [
  4:number <- copy 0:literal
  5:number <- copy 0:literal
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
+mem: storing 0 in location 3
# label1
+mem: storing 0 in location 4
+mem: storing 0 in location 5
+mem: storing 0 in location 6
# nothing else
$mem: 6

:(scenario tangle_tangles_into_all_labels_with_same_name)
recipe main [
  1:number <- copy 0:literal
  +label1
  +label1
  4:number <- copy 0:literal
]
before +label1 [
  2:number <- copy 0:literal
]
after +label1 [
  3:number <- copy 0:literal
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
# label1
+mem: storing 0 in location 3
+mem: storing 0 in location 2
# label1
+mem: storing 0 in location 3
+mem: storing 0 in location 4
# nothing else
$mem: 6
