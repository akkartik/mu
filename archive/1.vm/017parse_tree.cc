// So far instructions can only contain linear lists of properties. Now we add
// support for more complex trees of properties in dilated reagents. This will
// come in handy later for expressing complex types, like "a dictionary from
// (address to array of charaters) to (list of numbers)".
//
// Type trees aren't as general as s-expressions even if they look like them:
// the first element of a type tree is always an atom, and it can never be
// dotted (right->right->right->...->right is always NULL).
//
// For now you can't use the simpler 'colon-based' representation inside type
// trees. Once you start typing parens, keep on typing parens.

void test_dilated_reagent_with_nested_brackets() {
  load(
      "def main [\n"
      "  {1: number, foo: (bar (baz quux))} <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   product: {1: \"number\", \"foo\": (\"bar\" (\"baz\" \"quux\"))}\n"
  );
}

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
  return result;
}

void test_dilated_reagent_with_type_tree() {
  Hide_errors = true;  // 'map' isn't defined yet
  load(
      "def main [\n"
      "  {1: (foo (address array character) (bar number))} <- copy 34\n"
      "]\n"
      "container foo [\n"
      "]\n"
      "container bar [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   product: {1: (\"foo\" (\"address\" \"array\" \"character\") (\"bar\" \"number\"))}\n"
  );
}

void test_dilated_empty_tree() {
  load(
      "def main [\n"
      "  {1: number, foo: ()} <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   product: {1: \"number\", \"foo\": ()}\n"
  );
}

void test_dilated_singleton_tree() {
  load(
      "def main [\n"
      "  {1: number, foo: (bar)} <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   product: {1: \"number\", \"foo\": (\"bar\")}\n"
  );
}
