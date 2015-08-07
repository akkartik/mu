//: Allow code for recipes to be pulled in from multiple places.
//:
//: TODO: switch recipe.steps to a more efficient data structure.

:(scenario tangle_before)
recipe main [
  1:number <- copy 0
  +label1
  3:number <- copy 0
]

before +label1 [
  2:number <- copy 0
]
+mem: storing 0 in location 1
+mem: storing 0 in location 2
+mem: storing 0 in location 3
# nothing else
$mem: 3

//: while loading recipes, load before/after fragments

:(before "End Globals")
map<string /*label*/, recipe> Before_fragments, After_fragments;
set<string /*label*/> Fragments_used;
:(before "End Setup")
Before_fragments.clear();
After_fragments.clear();
Fragments_used.clear();

:(before "End Command Handlers")
else if (command == "before") {
  string label = next_word(in);
  recipe tmp = slurp_recipe(in);
//?   cerr << "adding before fragment " << label << '\n'; //? 1
  Before_fragments[label].steps.insert(Before_fragments[label].steps.end(), tmp.steps.begin(), tmp.steps.end());
}
else if (command == "after") {
  string label = next_word(in);
  recipe tmp = slurp_recipe(in);
//?   cerr << "adding after fragment " << label << '\n'; //? 1
  After_fragments[label].steps.insert(After_fragments[label].steps.begin(), tmp.steps.begin(), tmp.steps.end());
}

//: after all recipes are loaded, insert fragments at appropriate labels.

:(after "int main")
  Transform.push_back(insert_fragments);

//; We might need to perform multiple passes, in case inserted fragments
//: include more labels that need further insertions. Track which labels we've
//: already processed using an extra field.
:(before "End instruction Fields")
mutable bool tangle_done;
:(before "End instruction Constructor")
tangle_done = false;

:(code)
void insert_fragments(const recipe_ordinal r) {
  bool made_progress = true;
  while (made_progress) {
    made_progress = false;
    // create a new vector because insertions invalidate iterators
    vector<instruction> result;
    for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
      const instruction inst = Recipe[r].steps.at(i);
      if (!inst.is_label || inst.tangle_done) {
        result.push_back(inst);
        continue;
      }
      inst.tangle_done = true;
      made_progress = true;
      Fragments_used.insert(inst.label);
      if (Before_fragments.find(inst.label) != Before_fragments.end()) {
//?         cerr << "loading code before " << inst.label << '\n'; //? 1
        result.insert(result.end(), Before_fragments[inst.label].steps.begin(), Before_fragments[inst.label].steps.end());
      }
      result.push_back(inst);
      if (After_fragments.find(inst.label) != After_fragments.end()) {
//?         cerr << "loading code after " << inst.label << '\n'; //? 1
        result.insert(result.end(), After_fragments[inst.label].steps.begin(), After_fragments[inst.label].steps.end());
      }
    }
    Recipe[r].steps.swap(result);
  }
}

//: warn about unapplied fragments
:(before "End Globals")
bool Transform_check_insert_fragments_Ran = false;
:(before "End One-time Setup")
Transform.push_back(check_insert_fragments);  // final transform
:(code)
void check_insert_fragments(unused recipe_ordinal) {
  if (Transform_check_insert_fragments_Ran) return;
  Transform_check_insert_fragments_Ran = true;
  for (map<string, recipe>::iterator p = Before_fragments.begin(); p != Before_fragments.end(); ++p) {
    if (Fragments_used.find(p->first) == Fragments_used.end())
      raise << "could not locate insert before " << p->first << '\n' << end();
  }
  for (map<string, recipe>::iterator p = After_fragments.begin(); p != After_fragments.end(); ++p) {
    if (Fragments_used.find(p->first) == Fragments_used.end())
      raise << "could not locate insert after " << p->first << '\n' << end();
  }
}

:(scenario tangle_before_and_after)
recipe main [
  1:number <- copy 0
  +label1
  4:number <- copy 0
]
before +label1 [
  2:number <- copy 0
]
after +label1 [
  3:number <- copy 0
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
  1:number <- copy 0
  +label1
  +label2
  6:number <- copy 0
]
before +label1 [
  2:number <- copy 0
]
after +label1 [
  3:number <- copy 0
]
before +label2 [
  4:number <- copy 0
]
after +label2 [
  5:number <- copy 0
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
  1:number <- copy 0
  +label1
  6:number <- copy 0
]
before +label1 [
  2:number <- copy 0
]
after +label1 [
  3:number <- copy 0
]
before +label1 [
  4:number <- copy 0
]
after +label1 [
  5:number <- copy 0
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
  1:number <- copy 0
  +label1
  6:number <- copy 0
]
before +label1 [
  2:number <- copy 0
  3:number <- copy 0
]
after +label1 [
  4:number <- copy 0
  5:number <- copy 0
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
  1:number <- copy 10
  +label1
  4:number <- copy 10
  recipe2
]
recipe recipe2 [
  1:number <- copy 11
  +label1
  4:number <- copy 11
]
before +label1 [
  2:number <- copy 12
]
after +label1 [
  3:number <- copy 12
]
+mem: storing 10 in location 1
+mem: storing 12 in location 2
# label1
+mem: storing 12 in location 3
+mem: storing 10 in location 4
# recipe2
+mem: storing 11 in location 1
+mem: storing 12 in location 2
# label1
+mem: storing 12 in location 3
+mem: storing 11 in location 4
# nothing else
$mem: 8

:(scenario tangle_tangles_into_all_labels_with_same_name_2)
recipe main [
  1:number <- copy 10
  +label1
  +label1
  4:number <- copy 10
]
before +label1 [
  2:number <- copy 12
]
after +label1 [
  3:number <- copy 12
]
+mem: storing 10 in location 1
+mem: storing 12 in location 2
# label1
+mem: storing 12 in location 3
+mem: storing 12 in location 2
# label1
+mem: storing 12 in location 3
+mem: storing 10 in location 4
# nothing else
$mem: 6

:(scenario tangle_tangles_into_all_labels_with_same_name_3)
recipe main [
  1:number <- copy 10
  +label1
  +foo
  4:number <- copy 10
]
before +label1 [
  2:number <- copy 12
]
after +label1 [
  3:number <- copy 12
]
after +foo [
  +label1
]
+mem: storing 10 in location 1
+mem: storing 12 in location 2
# label1
+mem: storing 12 in location 3
+mem: storing 12 in location 2
# +foo/label1
+mem: storing 12 in location 3
+mem: storing 10 in location 4
# nothing else
$mem: 6
