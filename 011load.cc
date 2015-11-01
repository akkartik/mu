//: Phase 1 of running mu code: load it from a textual representation.

:(scenarios load)  // use 'load' instead of 'run' in all scenarios in this layer
:(scenario first_recipe)
recipe main [
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}

:(code)
vector<recipe_ordinal> load(string form) {
  istringstream in(form);
  in >> std::noskipws;
  return load(in);
}

vector<recipe_ordinal> load(istream& in) {
  in >> std::noskipws;
  vector<recipe_ordinal> result;
  while (!in.eof()) {
    skip_whitespace_and_comments(in);
    if (in.eof()) break;
    string command = next_word(in);
    // Command Handlers
    if (command == "recipe") {
      result.push_back(slurp_recipe(in));
    }
    else if (command == "recipe!") {
      Disable_redefine_warnings = true;
      result.push_back(slurp_recipe(in));
      Disable_redefine_warnings = false;
    }
    // End Command Handlers
    else {
      raise_error << "unknown top-level command: " << command << '\n' << end();
    }
  }
  return result;
}

long long int slurp_recipe(istream& in) {
  recipe result;
  result.name = next_word(in);
  // End recipe Refinements
  if (result.name.empty())
    raise_error << "empty result.name\n" << end();
  trace(9991, "parse") << "--- defining " << result.name << end();
  if (Recipe_ordinal.find(result.name) == Recipe_ordinal.end()) {
    Recipe_ordinal[result.name] = Next_recipe_ordinal++;
  }
  if (Recipe.find(Recipe_ordinal[result.name]) != Recipe.end()) {
    trace(9991, "parse") << "already exists" << end();
    if (warn_on_redefine(result.name))
      raise << "redefining recipe " << result.name << "\n" << end();
    Recipe.erase(Recipe_ordinal[result.name]);
  }
  slurp_body(in, result);
  // End recipe Body(result)
  Recipe[Recipe_ordinal[result.name]] = result;
  // track added recipes because we may need to undo them in tests; see below
  recently_added_recipes.push_back(Recipe_ordinal[result.name]);
  return Recipe_ordinal[result.name];
}

void slurp_body(istream& in, recipe& result) {
  in >> std::noskipws;
  skip_whitespace(in);
  if (in.get() != '[')
    raise_error << "recipe body must begin with '['\n" << end();
  skip_whitespace_and_comments(in);
  instruction curr;
  while (next_instruction(in, &curr)) {
    // End Rewrite Instruction(curr, recipe result)
    trace(9992, "load") << "after rewriting: " << curr.to_string() << end();
    if (!curr.is_clear())
      result.steps.push_back(curr);
  }
}

bool next_instruction(istream& in, instruction* curr) {
  curr->clear();
  if (in.eof()) {
    raise_error << "0: unbalanced '[' for recipe\n" << end();
    return false;
  }
  skip_whitespace(in);
  if (in.eof()) {
    raise_error << "1: unbalanced '[' for recipe\n" << end();
    return false;
  }
  skip_whitespace_and_comments(in);
  if (in.eof()) {
    raise_error << "2: unbalanced '[' for recipe\n" << end();
    return false;
  }

  vector<string> words;
  while (in.peek() != '\n' && !in.eof()) {
    skip_whitespace(in);
    if (in.eof()) {
      raise_error << "3: unbalanced '[' for recipe\n" << end();
      return false;
    }
    string word = next_word(in);
    words.push_back(word);
    skip_whitespace(in);
  }
  skip_whitespace_and_comments(in);
  if (SIZE(words) == 1 && words.at(0) == "]") {
    return false;  // end of recipe
  }

  if (SIZE(words) == 1 && !isalnum(words.at(0).at(0)) && words.at(0).at(0) != '$') {
    curr->is_label = true;
    curr->label = words.at(0);
    trace(9993, "parse") << "label: " << curr->label << end();
    if (in.eof()) {
      raise_error << "7: unbalanced '[' for recipe\n" << end();
      return false;
    }
    return true;
  }

  vector<string>::iterator p = words.begin();
  if (find(words.begin(), words.end(), "<-") != words.end()) {
    for (; *p != "<-"; ++p) {
      curr->products.push_back(reagent(*p));
    }
    ++p;  // skip <-
  }

  if (p == words.end()) {
    raise_error << "instruction prematurely ended with '<-'\n" << end();
    return false;
  }
  curr->old_name = curr->name = *p;  p++;
  // curr->operation will be set in a later layer

  for (; p != words.end(); ++p) {
    curr->ingredients.push_back(reagent(*p));
  }

  trace(9993, "parse") << "instruction: " << curr->name << end();
  trace(9993, "parse") << "  number of ingredients: " << SIZE(curr->ingredients) << end();
  for (vector<reagent>::iterator p = curr->ingredients.begin(); p != curr->ingredients.end(); ++p) {
    trace(9993, "parse") << "  ingredient: " << p->to_string() << end();
  }
  for (vector<reagent>::iterator p = curr->products.begin(); p != curr->products.end(); ++p) {
    trace(9993, "parse") << "  product: " << p->to_string() << end();
  }
  if (in.eof()) {
    raise_error << "9: unbalanced '[' for recipe\n" << end();
    return false;
  }
  return true;
}

string next_word(istream& in) {
  skip_whitespace(in);
  skip_ignored_characters(in);
  // End next_word Special-cases
  ostringstream out;
  slurp_word(in, out);
  skip_whitespace(in);
  skip_comment(in);
  return out.str();
}

:(before "End Globals")
// word boundaries
string Terminators("(){}");
string Ignore(",");  // meaningless except within [] strings
:(code)
void slurp_word(istream& in, ostream& out) {
  char c;
  if (!in.eof() && Terminators.find(in.peek()) != string::npos) {
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

void skip_ignored_characters(istream& in) {
  while (isspace(in.peek()) || Ignore.find(in.peek()) != string::npos) {
    in.get();
  }
}

void skip_whitespace_and_comments(istream& in) {
  while (true) {
    if (in.eof()) break;
    if (isspace(in.peek())) in.get();
    else if (in.peek() == '#') skip_comment(in);
    else break;
  }
}

void skip_comment(istream& in) {
  if (!in.eof() && in.peek() == '#') {
    in.get();
    while (!in.eof() && in.peek() != '\n') in.get();
  }
}

//: Warn if a recipe gets redefined, because large codebases can accidentally
//: step on their own toes. But there'll be many occasions later where
//: we'll want to disable the warnings.
:(before "End Globals")
bool Disable_redefine_warnings = false;
:(before "End Setup")
Disable_redefine_warnings = false;
:(code)
bool warn_on_redefine(const string& recipe_name) {
  if (Disable_redefine_warnings) return false;
  return true;
}

// for debugging
:(code)
void show_rest_of_stream(istream& in) {
  cerr << '^';
  char c;
  while (in >> c) {
    cerr << c;
  }
  cerr << "$\n";
  exit(0);
}

//: Have tests clean up any recipes they added.
:(before "End Globals")
vector<recipe_ordinal> recently_added_recipes;
long long int Reserved_for_tests = 1000;
:(before "End Setup")
for (long long int i = 0; i < SIZE(recently_added_recipes); ++i) {
  if (recently_added_recipes.at(i) >= Reserved_for_tests)  // don't renumber existing recipes, like 'interactive'
    Recipe_ordinal.erase(Recipe[recently_added_recipes.at(i)].name);
  Recipe.erase(recently_added_recipes.at(i));
}
// Clear Other State For recently_added_recipes
recently_added_recipes.clear();

:(code)
:(scenario parse_comment_outside_recipe)
# this comment will be dropped by the tangler, so we need a dummy recipe to stop that
recipe f1 [ ]
# this comment will go through to 'load'
recipe main [
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}

:(scenario parse_comment_amongst_instruction)
recipe main [
  # comment
  1:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}

:(scenario parse_comment_amongst_instruction_2)
recipe main [
  # comment
  1:number <- copy 23
  # comment
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}

:(scenario parse_comment_amongst_instruction_3)
recipe main [
  1:number <- copy 23
  # comment
  2:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"2": "number"}

:(scenario parse_comment_after_instruction)
recipe main [
  1:number <- copy 23  # comment
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}

:(scenario parse_label)
recipe main [
  +foo
]
+parse: label: +foo

:(scenario parse_dollar_as_recipe_name)
recipe main [
  $foo
]
+parse: instruction: $foo

:(scenario parse_multiple_properties)
recipe main [
  1:number <- copy 23/foo:bar:baz
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal", "foo": <"bar" : <"baz" : <>>>}
+parse:   product: {"1": "number"}

:(scenario parse_multiple_products)
recipe main [
  1:number, 2:number <- copy 23
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   product: {"1": "number"}
+parse:   product: {"2": "number"}

:(scenario parse_multiple_ingredients)
recipe main [
  1:number, 2:number <- copy 23, 4:number
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   ingredient: {"4": "number"}
+parse:   product: {"1": "number"}
+parse:   product: {"2": "number"}

:(scenario parse_multiple_types)
recipe main [
  1:number, 2:address:number <- copy 23, 4:number
]
+parse: instruction: copy
+parse:   ingredient: {"23": "literal"}
+parse:   ingredient: {"4": "number"}
+parse:   product: {"1": "number"}
+parse:   product: {"2": <"address" : <"number" : <>>>}

:(scenario parse_properties)
recipe main [
  1:number:address/lookup <- copy 23
]
+parse:   product: {"1": <"number" : <"address" : <>>>, "lookup": <>}

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

:(scenario warn_on_redefine)
% Hide_warnings = true;
recipe main [
  1:number <- copy 23
]
recipe main [
  1:number <- copy 24
]
+warn: redefining recipe main

:(scenario redefine_without_warning)
% Hide_warnings = true;
recipe main [
  1:number <- copy 23
]
recipe! main [
  1:number <- copy 24
]
-warn: redefining recipe main
$warn: 0
