// So far instructions can only contain linear lists of properties. Now we add
// support for more complex trees of properties in dilated reagents. This will
// come in handy later for expressing complex types, like "a dictionary from
// (address to array of charaters) to (list of numbers)".

:(scenario dilated_reagent_with_nested_brackets)
recipe main [
  {1: number, foo: (bar (baz quux))} <- copy 34
]
+parse:   product: 1: "number", {"foo": ("bar" ("baz" "quux"))}

:(before "End Parsing Reagent Property(value)")
value = parse_string_tree(value);
:(before "End Parsing Reagent Type Property(value)")
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
  skip_whitespace_but_not_newline(in);
  if (!has_data(in)) return NULL;
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
    assert(has_data(in));
    *curr = new string_tree("");
    skip_whitespace_but_not_newline(in);
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
% Hide_errors = true;  // 'map' isn't defined yet
recipe main [
  {1: (foo (address array character) (bar number))} <- copy 34
]
# just to avoid errors
container foo [
]
container bar [
]
+parse:   product: 1: ("foo" ("address" "array" "character") ("bar" "number"))

//: an exception is 'new', which takes a type tree as its ingredient *value*

:(scenario dilated_reagent_with_new)
recipe main [
  x:address:shared:address:number <- new {(address number): type}
]
+new: size of ("address" "number") is 1

:(before "End Post-processing(expected_product) When Checking 'new'")
{
  string_tree* tmp_type_names = parse_string_tree(expected_product.type->name);
  delete expected_product.type;
  expected_product.type = new_type_tree(tmp_type_names);
  delete tmp_type_names;
}
:(before "End Post-processing(type_name) When Converting 'new'")
type_name = parse_string_tree(type_name);
