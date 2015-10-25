//: An alternative syntax for reagents that permits whitespace in properties,
//: grouped by brackets.

:(scenarios load)
:(scenario dilated_reagent)
recipe main [
  {1: number, foo: bar} <- copy 34
]
+parse:   product: {name: "1", properties: ["1": "number", "foo": "bar"]}

//: First augment next_word to group balanced brackets together.

:(after "string next_word(istream& in)")
  if (in.peek() == '(')
    return slurp_balanced_bracket(in);
  // curlies are like parens, but don't mess up labels
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
  if (in.peek() == '\n') {
    in.putback('{');
    return false;
  }
  in.putback('{');
  return true;
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
  istringstream in(s);
  in >> std::noskipws;
  in.get();  // skip '{'
  while (!in.eof()) {
    string key = next_dilated_word(in);
    string value = next_dilated_word(in);
    vector<string> values;
    values.push_back(value);
    properties.push_back(pair<string, vector<string> >(key, values));
  }
  // structures for the first row of properties
  name = properties.at(0).first;
  string type = properties.at(0).second.at(0);
  if (Type_ordinal.find(type) == Type_ordinal.end()) {
      // this type can't be an integer
    Type_ordinal[type] = Next_type_ordinal++;
  }
  types.push_back(Type_ordinal[type]);
  return;
}

:(code)
string next_dilated_word(istream& in) {
  while (in.peek() == ',') in.get();
  string result = next_word(in);
  while (true) {
    if (result.empty())
      return result;
    else if (*result.rbegin() == ':')
      strip_last(result);
    // if the word doesn't start with a bracket, next_word() was from previous
    // layers when reading it, and therefore oblivious about brackets
    else if (*result.begin() != '{' && *result.rbegin() == '}')
      strip_last(result);
    else
      break;
  }
  return result;
}
