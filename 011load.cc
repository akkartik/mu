//: Phase 1 of running mu code: load it from a textual representation.

:(scenarios load)  // use 'load' instead of 'run' in all scenarios in this layer
:(scenario first_recipe)
def main [
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"

:(code)
vector<recipe_ordinal> load(string form) {
  istringstream in(form);
  in >> std::noskipws;
  return load(in);
}

vector<recipe_ordinal> load(istream& in) {
  in >> std::noskipws;
  vector<recipe_ordinal> result;
  while (has_data(in)) {
    skip_whitespace_and_comments(in);
    if (!has_data(in)) break;
    string command = next_word(in);
    // Command Handlers
    if (command == "recipe" || command == "def") {
      result.push_back(slurp_recipe(in));
    }
    else if (command == "recipe!" || command == "def!") {
      Disable_redefine_checks = true;
      result.push_back(slurp_recipe(in));
      Disable_redefine_checks = false;
    }
    // End Command Handlers
    else {
      raise << "unknown top-level command: " << command << '\n' << end();
    }
  }
  return result;
}

long long int slurp_recipe(istream& in) {
  recipe result;
  result.name = next_word(in);
  // End Load Recipe Name
  skip_whitespace_but_not_newline(in);
  // End Recipe Refinements
  if (result.name.empty())
    raise << "empty result.name\n" << end();
  trace(9991, "parse") << "--- defining " << result.name << end();
  if (!contains_key(Recipe_ordinal, result.name))
    put(Recipe_ordinal, result.name, Next_recipe_ordinal++);
  if (Recipe.find(get(Recipe_ordinal, result.name)) != Recipe.end()) {
    trace(9991, "parse") << "already exists" << end();
    if (should_check_for_redefine(result.name))
      raise << "redefining recipe " << result.name << "\n" << end();
    Recipe.erase(get(Recipe_ordinal, result.name));
  }
  slurp_body(in, result);
  // End Recipe Body(result)
  put(Recipe, get(Recipe_ordinal, result.name), result);
  // track added recipes because we may need to undo them in tests; see below
  Recently_added_recipes.push_back(get(Recipe_ordinal, result.name));
  return get(Recipe_ordinal, result.name);
}

void slurp_body(istream& in, recipe& result) {
  in >> std::noskipws;
  skip_whitespace_but_not_newline(in);
  if (in.get() != '[')
    raise << "recipe body must begin with '['\n" << end();
  skip_whitespace_and_comments(in);  // permit trailing comment after '['
  instruction curr;
  while (next_instruction(in, &curr)) {
    // End Rewrite Instruction(curr, recipe result)
    trace(9992, "load") << "after rewriting: " << to_string(curr) << end();
    if (!curr.is_empty()) {
      curr.original_string = to_string(curr);
      result.steps.push_back(curr);
    }
  }
}

bool next_instruction(istream& in, instruction* curr) {
  curr->clear();
  skip_whitespace_and_comments(in);
  if (!has_data(in)) {
    raise << "0: unbalanced '[' for recipe\n" << end();
    return false;
  }

  vector<string> words;
  while (has_data(in) && in.peek() != '\n') {
    skip_whitespace_but_not_newline(in);
    if (!has_data(in)) {
      raise << "1: unbalanced '[' for recipe\n" << end();
      return false;
    }
    string word = next_word(in);
    words.push_back(word);
    skip_whitespace_but_not_newline(in);
  }
  skip_whitespace_and_comments(in);
  if (SIZE(words) == 1 && words.at(0) == "]")
    return false;  // end of recipe

  if (SIZE(words) == 1 && !isalnum(words.at(0).at(0)) && words.at(0).at(0) != '$') {
    curr->is_label = true;
    curr->label = words.at(0);
    trace(9993, "parse") << "label: " << curr->label << end();
    if (!has_data(in)) {
      raise << "7: unbalanced '[' for recipe\n" << end();
      return false;
    }
    return true;
  }

  vector<string>::iterator p = words.begin();
  if (find(words.begin(), words.end(), "<-") != words.end()) {
    for (; *p != "<-"; ++p)
      curr->products.push_back(reagent(*p));
    ++p;  // skip <-
  }

  if (p == words.end()) {
    raise << "instruction prematurely ended with '<-'\n" << end();
    return false;
  }
  curr->old_name = curr->name = *p;  p++;
  // curr->operation will be set in a later layer

  for (; p != words.end(); ++p)
    curr->ingredients.push_back(reagent(*p));

  trace(9993, "parse") << "instruction: " << curr->name << end();
  trace(9993, "parse") << "  number of ingredients: " << SIZE(curr->ingredients) << end();
  for (vector<reagent>::iterator p = curr->ingredients.begin(); p != curr->ingredients.end(); ++p)
    trace(9993, "parse") << "  ingredient: " << to_string(*p) << end();
  for (vector<reagent>::iterator p = curr->products.begin(); p != curr->products.end(); ++p)
    trace(9993, "parse") << "  product: " << to_string(*p) << end();
  if (!has_data(in)) {
    raise << "9: unbalanced '[' for recipe\n" << end();
    return false;
  }
  return true;
}

string next_word(istream& in) {
  skip_whitespace_but_not_newline(in);
  // End next_word Special-cases
  ostringstream out;
  slurp_word(in, out);
  skip_whitespace_and_comments_but_not_newline(in);
  return out.str();
}

:(before "End Globals")
// word boundaries
const string Terminators("(){}");
:(code)
void slurp_word(istream& in, ostream& out) {
  char c;
  if (has_data(in) && Terminators.find(in.peek()) != string::npos) {
    in >> c;
    out << c;
    return;
  }
  while (in >> c) {
    if (isspace(c) || Terminators.find(c) != string::npos || Ignore.find(c) != string::npos) {
      in.putback(c);
      break;
    }
    out << c;
  }
}

void skip_whitespace_and_comments(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    if (isspace(in.peek())) in.get();
    else if (Ignore.find(in.peek()) != string::npos) in.get();
    else if (in.peek() == '#') skip_comment(in);
    else break;
  }
}

// confusing; move to the next line only to skip a comment, but never otherwise
void skip_whitespace_and_comments_but_not_newline(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    if (in.peek() == '\n') break;
    if (isspace(in.peek())) in.get();
    else if (Ignore.find(in.peek()) != string::npos) in.get();
    else if (in.peek() == '#') skip_comment(in);
    else break;
  }
}

void skip_comment(istream& in) {
  if (has_data(in) && in.peek() == '#') {
    in.get();
    while (has_data(in) && in.peek() != '\n') in.get();
  }
}

//: Warn if a recipe gets redefined, because large codebases can accidentally
//: step on their own toes. But there'll be many occasions later where
//: we'll want to disable the errors.
:(before "End Globals")
bool Disable_redefine_checks = false;
:(before "End Setup")
Disable_redefine_checks = false;
:(code)
bool should_check_for_redefine(const string& recipe_name) {
  if (Disable_redefine_checks) return false;
  return true;
}

// for debugging
:(code)
void show_rest_of_stream(istream& in) {
  cerr << '^';
  char c;
  while (in >> c)
    cerr << c;
  cerr << "$\n";
  exit(0);
}

//: Have tests clean up any recipes they added.
:(before "End Globals")
vector<recipe_ordinal> Recently_added_recipes;
long long int Reserved_for_tests = 1000;
:(before "End Setup")
clear_recently_added_recipes();
:(code)
void clear_recently_added_recipes() {
  for (long long int i = 0; i < SIZE(Recently_added_recipes); ++i) {
    if (Recently_added_recipes.at(i) >= Reserved_for_tests  // don't renumber existing recipes, like 'interactive'
        && contains_key(Recipe, Recently_added_recipes.at(i)))  // in case previous test had duplicate definitions
      Recipe_ordinal.erase(get(Recipe, Recently_added_recipes.at(i)).name);
    Recipe.erase(Recently_added_recipes.at(i));
  }
  // Clear Other State For Recently_added_recipes
  Recently_added_recipes.clear();
}

:(scenario parse_comment_outside_recipe)
# this comment will be dropped by the tangler, so we need a dummy recipe to stop that
def f1 [
]
# this comment will go through to 'load'
def main [
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"

:(scenario parse_comment_amongst_instruction)
def main [
  # comment
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"

:(scenario parse_comment_amongst_instruction_2)
def main [
  # comment
  1:number <- copy 23
  # comment
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"

:(scenario parse_comment_amongst_instruction_3)
def main [
  1:number <- copy 23
  # comment
  2:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 2: "number"

:(scenario parse_comment_after_instruction)
def main [
  1:number <- copy 23  # comment
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"

:(scenario parse_label)
def main [
  +foo
]
+parse: label: +foo

:(scenario parse_dollar_as_recipe_name)
def main [
  $foo
]
+parse: instruction: $foo

:(scenario parse_multiple_properties)
def main [
  1:number <- copy 23/foo:bar:baz
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal", {"foo": ("bar" "baz")}
+parse:   product: 1: "number"

:(scenario parse_multiple_products)
def main [
  1:number, 2:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   product: 1: "number"
+parse:   product: 2: "number"

:(scenario parse_multiple_ingredients)
def main [
  1:number, 2:number <- copy 23, 4:number
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   ingredient: 4: "number"
+parse:   product: 1: "number"
+parse:   product: 2: "number"

:(scenario parse_multiple_types)
def main [
  1:number, 2:address:number <- copy 23, 4:number
]
+parse: instruction: copy
+parse:   ingredient: 23: "literal"
+parse:   ingredient: 4: "number"
+parse:   product: 1: "number"
+parse:   product: 2: ("address" "number")

:(scenario parse_properties)
def main [
  1:address:number/lookup <- copy 23
]
+parse:   product: 1: ("address" "number"), {"lookup": ()}

//: this test we can't represent with a scenario
:(code)
void test_parse_comment_terminated_by_eof() {
  Trace_file = "parse_comment_terminated_by_eof";
  load("recipe main [\n"
       "  a:number <- copy 34\n"
       "]\n"
       "# abc");  // no newline after comment
  cerr << ".";  // termination = success
}

:(scenario forbid_redefining_recipes)
% Hide_errors = true;
def main [
  1:number <- copy 23
]
def main [
  1:number <- copy 24
]
+error: redefining recipe main

:(scenario permit_forcibly_redefining_recipes)
def main [
  1:number <- copy 23
]
def! main [
  1:number <- copy 24
]
-error: redefining recipe main
$error: 0
