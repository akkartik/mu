//: Phase 1 of running mu code: load it from a textual representation.

:(scenarios load)
:(scenario first_recipe)
recipe main [
  1:integer <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

:(code)
vector<recipe_number> load(string form) {
  istringstream in(form);
  in >> std::noskipws;
  return load(in);
}

vector<recipe_number> load(istream& in) {
  vector<recipe_number> result;
  while (!in.eof()) {
    skip_comments_and_newlines(in);
    if (in.eof()) break;
    string command = next_word(in);
    // Command Handlers
    if (command == "recipe") {
      result.push_back(add_recipe(in));
    }
    // End Command Handlers
    else {
      raise << "unknown top-level command: " << command << '\n';
    }
  }
  return result;
}

recipe_number add_recipe(istream& in) {
  skip_comments_and_newlines(in);
  string recipe_name = next_word(in);
//?   cout << "recipe name: ^" << recipe_name << "$\n"; //? 3
  if (recipe_name.empty())
    raise << "empty recipe name\n";
//?     raise << "empty recipe name in " << in.str() << '\n';
  if (Recipe_number.find(recipe_name) == Recipe_number.end()) {
    Recipe_number[recipe_name] = Next_recipe_number++;
//?     cout << "AAA: " << recipe_name << " is now " << Recipe_number[recipe_name] << '\n'; //? 1
  }
  recipe_number r = Recipe_number[recipe_name];
  if (Recipe.find(r) != Recipe.end()) {
    raise << "redefining recipe " << Recipe[r].name << "\n";
    Recipe.erase(r);
  }
//?   cout << recipe_name << ": adding recipe " << r << '\n'; //? 3

  skip_whitespace(in);
  if (in.get() != '[')
    raise << "recipe body must begin with '['\n";

  skip_comments_and_newlines(in);

  instruction curr;
  while (next_instruction(in, &curr)) {
//?     if (!curr.products.empty()) cout << curr.products[0].to_string() << '\n'; //? 1
    Recipe[r].steps.push_back(curr);
  }
  Recipe[r].name = recipe_name;
//?   cout << "recipe " << recipe_name << " has " << Recipe[r].steps.size() << " steps.\n"; //? 1
  // track added recipes because we may need to undo them in tests; see below
  recently_added_recipes.push_back(r);
  return r;
}

bool next_instruction(istream& in, instruction* curr) {
  curr->clear();
  if (in.eof()) return false;
  skip_whitespace(in);  if (in.eof()) return false;
  skip_comments_and_newlines(in);  if (in.eof()) return false;

  vector<string> words;
  while (in.peek() != '\n') {
    skip_whitespace(in);  if (in.eof()) return false;
    string word = next_word(in);  if (in.eof()) return false;
    words.push_back(word);
    skip_whitespace(in);  if (in.eof()) return false;
  }
  skip_comments_and_newlines(in);  if (in.eof()) return false;

//?   if (words.size() == 1) cout << words[0] << ' ' << words[0].size() << '\n'; //? 1
  if (words.size() == 1 && words[0] == "]") {
//?     cout << "AAA\n"; //? 1
    return false;  // end of recipe
  }

  if (words.size() == 1 && !isalnum(words[0][0]) && words[0][0] != '$') {
    curr->is_label = true;
    curr->label = words[0];
    trace("parse") << "label: " << curr->label;
    return !in.eof();
  }

  vector<string>::iterator p = words.begin();
  if (find(words.begin(), words.end(), "<-") != words.end()) {
    for (; *p != "<-"; ++p) {
      if (*p == ",") continue;
      curr->products.push_back(reagent(*p));
    }
    ++p;  // skip <-
  }

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

void skip_comments_and_newlines(istream& in) {
  while (in.peek() == '\n' || in.peek() == '#') {
    if (in.peek() == '#') {
      in.get();
      while (in.peek() != '\n') in.get();
    }
    in.get();
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

//: Have tests clean up any recipes they added.
:(before "End Globals")
vector<recipe_number> recently_added_recipes;
:(before "End Setup")
for (size_t i = 0; i < recently_added_recipes.size(); ++i) {
//?   cout << "AAA clearing " << Recipe[recently_added_recipes[i]].name << '\n'; //? 2
  Recipe_number.erase(Recipe[recently_added_recipes[i]].name);
  Recipe.erase(recently_added_recipes[i]);
}
// Clear Other State For recently_added_recipes
recently_added_recipes.clear();

:(scenario parse_comment_outside_recipe)
# this comment will be dropped by the tangler, so we need a dummy recipe to stop that
recipe f1 [ ]
# this comment will go through to 'load'
recipe main [
  1:integer <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

:(scenario parse_comment_amongst_instruction)
recipe main [
  # comment
  1:integer <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

:(scenario parse_comment_amongst_instruction2)
recipe main [
  # comment
  1:integer <- copy 23:literal
  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

:(scenario parse_comment_amongst_instruction3)
recipe main [
  1:integer <- copy 23:literal
  # comment
  2:integer <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "2", value: 0, type: 1, properties: ["2": "integer"]}

:(scenario parse_comment_after_instruction)
recipe main [
  1:integer <- copy 23:literal  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

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
  1:integer <- copy 23:literal/foo:bar:baz
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal", "foo": "bar":"baz"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}

:(scenario parse_multiple_products)
recipe main [
  1:integer, 2:integer <- copy 23:literal
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}
+parse:   product: {name: "2", value: 0, type: 1, properties: ["2": "integer"]}

:(scenario parse_multiple_ingredients)
recipe main [
  1:integer, 2:integer <- copy 23:literal, 4:integer
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   ingredient: {name: "4", value: 0, type: 1, properties: ["4": "integer"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}
+parse:   product: {name: "2", value: 0, type: 1, properties: ["2": "integer"]}

:(scenario parse_multiple_types)
recipe main [
  1:integer, 2:address:integer <- copy 23:literal, 4:integer
]
+parse: instruction: copy
+parse:   ingredient: {name: "23", value: 0, type: 0, properties: ["23": "literal"]}
+parse:   ingredient: {name: "4", value: 0, type: 1, properties: ["4": "integer"]}
+parse:   product: {name: "1", value: 0, type: 1, properties: ["1": "integer"]}
+parse:   product: {name: "2", value: 0, type: 2-1, properties: ["2": "address":"integer"]}

:(scenario parse_properties)
recipe main [
  1:integer:address/deref <- copy 23:literal
]
+parse:   product: {name: "1", value: 0, type: 1-2, properties: ["1": "integer":"address", "deref": ]}
