//: An alternative syntax for reagents that permits whitespace in properties,
//: grouped by brackets. We'll use this ability in the next layer, when we
//: generalize types from lists to trees of properties.

:(scenarios load)
:(scenario dilated_reagent)
recipe main [
  {1: number, foo: bar} <- copy 34
]
+parse:   product: 1: "number", {"foo": "bar"}

:(scenario load_trailing_space_after_curly_bracket)
recipe main [
  # line below has a space at the end
  { 
]
# successfully parsed

:(scenarios run)
:(scenario dilated_reagent_with_comment)
% Hide_errors = true;
recipe main [
  {1: number, foo: bar} <- copy 34  # test comment
]
+parse:   product: 1: "number", {"foo": "bar"}
$error: 0

:(scenario dilated_reagent_with_comment_immediately_following)
% Hide_errors = true;
recipe main [
  1:number <- copy {34: literal}  # test comment
]
$error: 0

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
bool start_of_dilated_reagent(istream& in) {
  if (in.peek() != '{') return false;
  long long int pos = in.tellg();
  in.get();  // slurp '{'
  skip_whitespace_but_not_newline(in);
  char next = in.peek();
  in.seekg(pos);
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
  skip_whitespace_and_comments_but_not_newline(in);
  return result.str();
}

:(after "Parsing reagent(string s)")
if (s.at(0) == '{') {
  assert(properties.empty());
  istringstream in(s);
  in >> std::noskipws;
  in.get();  // skip '{'
  name = slurp_key(in);
  if (name.empty()) {
    raise_error << "invalid reagent " << s << " without a name\n";
    return;
  }
  if (name == "}") {
    raise_error << "invalid empty reagent " << s << '\n';
    return;
  }
  {
    string_tree* value = new string_tree(next_word(in));
    // End Parsing Reagent Type Property(value)
    type = new_type_tree(value);
    delete value;
  }
  while (has_data(in)) {
    string key = slurp_key(in);
    if (key.empty()) continue;
    if (key == "}") continue;
    string_tree* value = new string_tree(next_word(in));
    // End Parsing Reagent Property(value)
    properties.push_back(pair<string, string_tree*>(key, value));
  }
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
