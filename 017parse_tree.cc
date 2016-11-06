// So far instructions can only contain linear lists of properties. Now we add
// support for more complex trees of properties in dilated reagents. This will
// come in handy later for expressing complex types, like "a dictionary from
// (address to array of charaters) to (list of numbers)".
//
// Type trees aren't as general as s-expressions even if they look like them:
// the first element of a type tree is always an atom, and left and right
// pointers of non-atoms are never NULL. All type trees are 'dotted' in lisp
// parlance.
//
// For now you can't use the simpler 'colon-based' representation inside type
// trees. Once you start typing parens, keep on typing parens.

:(scenarios load)
:(scenario dilated_reagent_with_nested_brackets)
def main [
  {1: number, foo: (bar (baz quux))} <- copy 34
]
+parse:   product: {1: "number", "foo": ("bar" ("baz" "quux"))}

:(before "End Parsing Dilated Reagent Property(value)")
value = parse_string_tree(value);
:(before "End Parsing Dilated Reagent Type Property(type_names)")
type_names = parse_string_tree(type_names);

:(code)
string_tree* parse_string_tree(string_tree* s) {
  assert(s->atom);
  if (!starts_with(s->value, "(")) return s;
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
    string s = next_word(in);
    if (s.empty()) {
      assert(!has_data(in));
      raise << "incomplete string tree at end of file (0)\n" << end();
      return NULL;
    }
    string_tree* result = new string_tree(s);
    return result;
  }
  in.get();  // skip '('
  string_tree* result = NULL;
  string_tree** curr = &result;
  while (true) {
    skip_whitespace_but_not_newline(in);
    assert(has_data(in));
    if (in.peek() == ')') break;
    *curr = new string_tree(NULL, NULL);
    if (in.peek() == '(') {
      (*curr)->left = parse_string_tree(in);
    }
    else {
      string s = next_word(in);
      if (s.empty()) {
        assert(!has_data(in));
        raise << "incomplete string tree at end of file (1)\n" << end();
        return NULL;
      }
      (*curr)->left = new string_tree(s);
    }
    curr = &(*curr)->right;
  }
  in.get();  // skip ')'
  assert(*curr == NULL);
  if (result->right == NULL) return result;
  // standardize the final element to always be on the right if it's an atom
  // (a b c) => (a b . c) in s-expression parlance
  string_tree* tmp = result;
  while (tmp->right->right) tmp = tmp->right;
  assert(!tmp->right->atom);
  if (!tmp->right->left->atom) return result;
  string_tree* tmp2 = tmp->right;
  tmp->right = tmp2->left;
  tmp2->left = NULL;
  assert(tmp2->right == NULL);
  delete tmp2;
  return result;
}

:(scenario dilated_reagent_with_type_tree)
% Hide_errors = true;  // 'map' isn't defined yet
def main [
  {1: (foo (address array character) (bar number))} <- copy 34
]
# just to avoid errors
container foo [
]
container bar [
]
+parse:   product: {1: ("foo" ("address" "array" "character") ("bar" "number"))}

:(scenario dilated_singleton_tree)
def main [
  {1: number, foo: (bar)} <- copy 34
]
+parse:   product: {1: "number", "foo": ("bar")}
