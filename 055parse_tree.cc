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
    string_tree* result = new string_tree(next_word(in));
    return result;
  }
  in.get();  // skip '('
  string_tree* result = NULL;
  string_tree** curr = &result;
  while (in.peek() != ')') {
    assert(!in.eof());
    *curr = new string_tree("");
    skip_whitespace(in);
    skip_ignored_characters(in);
    if (in.peek() == '(')
      (*curr)->left = parse_string_tree(in);
    else
      (*curr)->value = next_word(in);
    curr = &(*curr)->right;
  }
  in.get();  // skip ')'
  return result;
}

:(scenario dilated_reagent_with_type_tree)
recipe main [
  {1: (map (address array character) (list number))} <- copy 34
]
+parse:   product: {"1": <"map" : <<"address" : <"array" : <"character" : <>>>> : <<"list" : <"number" : <>>> : <>>>>}
