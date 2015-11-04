// So far instructions can only contain linear lists of properties. Now we add
// support for more complex trees of properties in dilated reagents. This will
// come in handy later for expressing complex types, like "a dictionary from
// (address to array of charaters) to (list of numbers)".

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

//: an exception is 'new', which takes a type tree as its ingredient *value*

:(scenario dilated_reagent_with_new)
recipe main [
  x:address:number <- new {(foo bar): type}
]
# type isn't defined so size is meaningless, but at least we parse the type correctly
+new: size of <"foo" : <"bar" : <>>> is 1

:(before "End Post-processing(type_name) When Converting 'new'")
type_name = parse_string_tree(type_name);
