//: Phase 1 of running mu code: load it from a textual representation.

:(scenarios load)  // use 'load' instead of 'run' in all scenarios in this layer
:(scenario first_recipe)
recipe main [
  1:number <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

:(code)
vector<recipe_number> load(string form) {
  istringstream in(form);
  in >> std::noskipws;
  return load(in);
}

vector<recipe_number> load(istream& in) {
  in >> std::noskipws;
  vector<recipe_number> result;
  while (!in.eof()) {
//?     cerr << "===\n"; //? 1
    skip_whitespace_and_comments(in);
    if (in.eof()) break;
    string command = next_word(in);
    // Command Handlers
    if (command == "recipe") {
      string recipe_name = next_word(in);
//?       cerr << "recipe: " << recipe_name << '\n'; //? 1
      if (recipe_name.empty())
        raise << "empty recipe name\n";
      if (Recipe_number.find(recipe_name) == Recipe_number.end()) {
        Recipe_number[recipe_name] = Next_recipe_number++;
      }
      if (Recipe.find(Recipe_number[recipe_name]) != Recipe.end()) {
        raise << "redefining recipe " << Recipe[Recipe_number[recipe_name]].name << "\n";
        Recipe.erase(Recipe_number[recipe_name]);
      }
      // todo: save user-defined recipes to mu's memory
      Recipe[Recipe_number[recipe_name]] = slurp_recipe(in);
//?       cerr << Recipe_number[recipe_name] << ": " << recipe_name << '\n'; //? 1
      Recipe[Recipe_number[recipe_name]].name = recipe_name;
      // track added recipes because we may need to undo them in tests; see below
      recently_added_recipes.push_back(Recipe_number[recipe_name]);
      result.push_back(Recipe_number[recipe_name]);
    }
    // End Command Handlers
    else {
      raise << "unknown top-level command: " << command << '\n';
    }
  }
  // End Load Sanity Checks
  return result;
}

recipe slurp_recipe(istream& in) {
  recipe result;
  skip_whitespace(in);
  if (in.get() != '[')
    raise << "recipe body must begin with '['\n";
  skip_whitespace_and_comments(in);
  instruction curr;
  while (next_instruction(in, &curr)) {
    // End Rewrite Instruction(curr)
//?     cerr << "instruction: " << curr.to_string() << '\n'; //? 2
    result.steps.push_back(curr);
  }
  return result;
}

bool next_instruction(istream& in, instruction* curr) {
  in >> std::noskipws;
  curr->clear();
  if (in.eof()) return false;
//?   show_rest_of_stream(in); //? 1
  skip_whitespace(in);  if (in.eof()) return false;
//?   show_rest_of_stream(in); //? 1
  skip_whitespace_and_comments(in);  if (in.eof()) return false;

  vector<string> words;
//?   show_rest_of_stream(in); //? 1
  while (in.peek() != '\n') {
    skip_whitespace(in);  if (in.eof()) return false;
//?     show_rest_of_stream(in); //? 1
    string word = next_word(in);  if (in.eof()) return false;
//?     cerr << "AAA: " << word << '\n'; //? 1
    words.push_back(word);
    skip_whitespace(in);  if (in.eof()) return false;
  }
  skip_whitespace_and_comments(in);  if (in.eof()) return false;

//?   if (SIZE(words) == 1) cout << words.at(0) << ' ' << SIZE(words.at(0)) << '\n'; //? 1
  if (SIZE(words) == 1 && words.at(0) == "]") {
//?     cout << "AAA\n"; //? 1
    return false;  // end of recipe
  }

  if (SIZE(words) == 1 && !isalnum(words.at(0).at(0)) && words.at(0).at(0) != '$') {
    curr->is_label = true;
    curr->label = words.at(0);
    trace("parse") << "label: " << curr->label;
    return !in.eof();
  }

  vector<string>::iterator p = words.begin();
  if (find(words.begin(), words.end(), "<-") != words.end()) {
    for (; *p != "<-"; ++p) {
      if (*p == ",") continue;
      curr->products.push_back(reagent(*p));
//?       cerr << "product: " << curr->products.back().to_string() << '\n'; //? 1
    }
    ++p;  // skip <-
  }

  if (p == words.end())
    raise << "instruction prematurely ended with '<-'\n" << die();
  curr->name = *p;
  if (Recipe_number.find(*p) == Recipe_number.end()) {
    Recipe_number[*p] = Next_recipe_number++;
//?     cout << "AAA: " << *p << " is now " << Recipe_number[*p] << '\n'; //? 1
  }
  if (Recipe_number[*p] == 0) {
    raise << "Recipe " << *p << " has number 0, which is reserved for IDLE.\n" << die();
  }
  curr->operation = Recipe_number[*p];  ++p;

  for (; p != words.end(); ++p) {
    if (*p == ",") continue;
    curr->ingredients.push_back(reagent(*p));
//?     cerr << "ingredient: " << curr->ingredients.back().to_string() << '\n'; //? 1
  }

  trace("parse") << "instruction: " << curr->name;
  for (vector<reagent>::iterator p = curr->ingredients.begin(); p != curr->ingredients.end(); ++p) {
    trace("parse") << "  ingredient: " << p->to_string();
  }
  for (vector<reagent>::iterator p = curr->products.begin(); p != curr->products.end(); ++p) {
    trace("parse") << "  product: " << p->to_string();
  }
  return !in.eof();
}

string next_word(istream& in) {
//?   cout << "AAA next_word\n"; //? 1
  ostringstream out;
  skip_whitespace(in);
  slurp_word(in, out);
  skip_whitespace(in);
  skip_comment(in);
//?   cerr << '^' << out.str() << "$\n"; //? 1
  return out.str();
}

void slurp_word(istream& in, ostream& out) {
//?   cout << "AAA slurp_word\n"; //? 1
  char c;
  if (in.peek() == ',') {
    in >> c;
    out << c;
    return;
  }
  while (in >> c) {
//?     cout << c << '\n'; //? 1
    if (isspace(c) || c == ',') {
      in.putback(c);
      break;
    }
    out << c;
  }
}

void skip_whitespace(istream& in) {
  while (isspace(in.peek()) && in.peek() != '\n') {
    in.get();
  }
}

void skip_whitespace_and_comments(istream& in) {
  while (true) {
    if (isspace(in.peek())) in.get();
    else if (in.peek() == '#') skip_comment(in);
    else break;
  }
}

void skip_comment(istream& in) {
  if (in.peek() == '#') {
    in.get();
    while (in.peek() != '\n') in.get();
  }
}

void skip_comma(istream& in) {
  skip_whitespace(in);
  if (in.peek() == ',') in.get();
  skip_whitespace(in);
}

// for debugging
:(before "End Globals")
bool Show_rest_of_stream = false;
:(code)
void show_rest_of_stream(istream& in) {
  if (!Show_rest_of_stream) return;
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
vector<recipe_number> recently_added_recipes;
:(before "End Setup")
for (long long int i = 0; i < SIZE(recently_added_recipes); ++i) {
//?   cout << "AAA clearing " << Recipe[recently_added_recipes.at(i)].name << '\n'; //? 2
  Recipe_number.erase(Recipe[recently_added_recipes.at(i)].name);
  Recipe.erase(recently_added_recipes.at(i));
}
// Clear Other State For recently_added_recipes
recently_added_recipes.clear();

:(scenario parse_comment_outside_recipe)
# this comment will be dropped by the tangler, so we need a dummy recipe to stop that
recipe f1 [ ]
# this comment will go through to 'load'
recipe main [
  1:number <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

:(scenario parse_comment_amongst_instruction)
recipe main [
  # comment
  1:number <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

:(scenario parse_comment_amongst_instruction2)
recipe main [
  # comment
  1:number <- copy 23:literal
  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

:(scenario parse_comment_amongst_instruction3)
recipe main [
  1:number <- copy 23:literal
  # comment
  2:number <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "2", properties: ["2": "number"]}

:(scenario parse_comment_after_instruction)
recipe main [
  1:number <- copy 23:literal  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

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
  1:number <- copy 23:literal/foo:bar:baz
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal", "foo": "bar":"baz"]}
+parse:   product: {name: "1", properties: ["1": "number"]}

:(scenario parse_multiple_products)
recipe main [
  1:number, 2:number <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   product: {name: "1", properties: ["1": "number"]}
+parse:   product: {name: "2", properties: ["2": "number"]}

:(scenario parse_multiple_ingredients)
recipe main [
  1:number, 2:number <- copy 23:literal, 4:number
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   ingredient: {name: "4", properties: ["4": "number"]}
+parse:   product: {name: "1", properties: ["1": "number"]}
+parse:   product: {name: "2", properties: ["2": "number"]}

:(scenario parse_multiple_types)
recipe main [
  1:number, 2:address:number <- copy 23:literal, 4:number
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", properties: ["23": "literal"]}
+parse:   ingredient: {name: "4", properties: ["4": "number"]}
+parse:   product: {name: "1", properties: ["1": "number"]}
+parse:   product: {name: "2", properties: ["2": "address":"number"]}

:(scenario parse_properties)
recipe main [
  1:number:address/deref <- copy 23:literal
]
+parse:   product: {name: "1", properties: ["1": "number":"address", "deref": ]}
