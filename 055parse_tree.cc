:(scenario dilated_reagent_with_nested_brackets)
recipe main [
  {1: number, foo: (bar (baz quux))} <- copy 34
]
+parse:   product: {"1": "number", "foo": <"bar" : <<"baz" : <"quux" : <>>> : <>>>}

:(before "End Parsing Reagent Property(value)")
value = parse_string_tree(value);

:(code)
string_tree* parse_string_tree(string_tree* s) {
  assert(!s->left && !s->right);
  if (s->value.at(0) != '(') return s;
  string_tree* result = parse_string_tree(s->value);
  delete s;
  return result;
}

string_tree* parse_string_tree(const string& s) {
  istringstream in(s);
  in >> std::noskipws;
  return parse_string_tree(in);
}

string_tree* parse_string_tree(istream& in) {
  skip_whitespace(in);
  if (in.eof()) return NULL;
  if (in.peek() == ')') {
    in.get();
    return NULL;
  }
  if (in.peek() != '(') {
    return new string_tree(next_word(in));
  }
  in.get();  // skip '('
  if (in.peek() == '(') {
    string_tree* left = parse_string_tree(in);
    string_tree* right = parse_string_tree(in);
    return new string_tree(left, right);
  }
  else {
    string value = next_word(in);
    string_tree* right = parse_string_tree(in);
    string_tree* rest = parse_string_tree(in);
    return new string_tree(value, new string_tree(right, rest));
  }
}
