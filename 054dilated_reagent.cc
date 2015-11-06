//: An alternative syntax for reagents that permits whitespace in properties,
//: grouped by brackets.

:(scenarios load)
:(scenario dilated_reagent)
recipe main [
  {1: number, foo: bar} <- copy 34
]
+parse:   product: {"1": "number", "foo": "bar"}

//: First augment next_word to group balanced brackets together.

:(before "End next_word Special-cases")
  if (in.peek() == '(')
    return slurp_balanced_bracket(in);
  // treat curlies mostly like parens, but don't mess up labels
  if (start_of_dilated_reagent(in))
    return slurp_balanced_bracket(in);

:(code)
// A curly is considered a label if it's the last thing on a line. Dilated
// reagents should remain all on one line.
//
// Side-effect: This might delete some whitespace after an initial '{'.
bool start_of_dilated_reagent(istream& in) {
  if (in.peek() != '{') return false;
  in.get();  // slurp '{'
  skip_whitespace(in);
  char next = in.peek();
  in.putback('{');
  return next != '\n';
}

// Assume the first letter is an open bracket, and read everything until the
// matching close bracket.
// We balance {} () and []. And we skip one character after '\'.
string slurp_balanced_bracket(istream& in) {
  ostringstream result;
  char c;
  list<char> open_brackets;
  while (in >> c) {
    if (c == '\\') {
      // always silently skip the next character
      result << c;
      if (!(in >> c)) break;
      result << c;
      continue;
    }
    if (c == '(') open_brackets.push_back(c);
    if (c == ')') {
      assert(open_brackets.back() == '(');
      open_brackets.pop_back();
    }
    if (c == '[') open_brackets.push_back(c);
    if (c == ']') {
      assert(open_brackets.back() == '[');
      open_brackets.pop_back();
    }
    if (c == '{') open_brackets.push_back(c);
    if (c == '}') {
      assert(open_brackets.back() == '{');
      open_brackets.pop_back();
    }
    result << c;
    if (open_brackets.empty()) break;
  }
  return result.str();
}

:(after "Parsing reagent(string s)")
if (s.at(0) == '{') {
  assert(properties.empty());
  istringstream in(s);
  in >> std::noskipws;
  in.get();  // skip '{'
  while (!in.eof()) {
    string key = slurp_key(in);
    if (key.empty()) continue;
    if (key == "}") continue;
    string_tree* value = new string_tree(next_word(in));
    // End Parsing Reagent Property(value)
    properties.push_back(pair<string, string_tree*>(key, value));
  }
  // structures for the first row of properties
  name = properties.at(0).first;
  string type_name = properties.at(0).second->value;
  if (Type_ordinal.find(type_name) == Type_ordinal.end()) {
      // this type can't be an integer literal
    put(Type_ordinal, type_name, Next_type_ordinal++);
  }
  type = new type_tree(get(Type_ordinal, type_name));
  return;
}

:(code)
string slurp_key(istream& in) {
  string result = next_word(in);
  while (!result.empty() && *result.rbegin() == ':')
    strip_last(result);
  while (isspace(in.peek()) || in.peek() == ':')
    in.get();
  return result;
}
