//: For convenience, some instructions will take literal arrays of characters (strings).
//:
//: Instead of quotes, we'll use [] to delimit strings. That'll reduce the
//: need for escaping since we can support nested brackets. And we can also
//: imagine that 'recipe' might one day itself be defined in mu, doing its own
//: parsing.

:(scenarios load)
:(scenario string_literal)
recipe main [
  1:address:array:character <- copy [abc def]  # copy can't really take a string
]
+parse:   ingredient: {"abc def": "literal-string"}

:(scenario string_literal_with_colons)
recipe main [
  1:address:array:character <- copy [abc:def/ghi]
]
+parse:   ingredient: {"abc:def/ghi": "literal-string"}

:(before "End Mu Types Initialization")
Type_ordinal["literal-string"] = 0;

:(before "End next_word Special-cases")
  if (in.peek() == '[') {
    string result = slurp_quoted(in);
    skip_whitespace(in);
    skip_comment(in);
    return result;
  }

:(code)
string slurp_quoted(istream& in) {
  ostringstream out;
  assert(!in.eof());  assert(in.peek() == '[');  out << static_cast<char>(in.get());  // slurp the '['
  if (is_code_string(in, out))
    slurp_quoted_comment_aware(in, out);
  else
    slurp_quoted_comment_oblivious(in, out);
  return out.str();
}

// A string is a code string if it contains a newline before any non-whitespace
// todo: support comments before the newline. But that gets messy.
bool is_code_string(istream& in, ostream& out) {
  while (!in.eof()) {
    char c = in.get();
    if (!isspace(c)) {
      in.putback(c);
      return false;
    }
    out << c;
    if (c == '\n') {
      return true;
    }
  }
  return false;
}

// Read a regular string. Regular strings can only contain other regular
// strings.
void slurp_quoted_comment_oblivious(istream& in, ostream& out) {
  int brace_depth = 1;
  while (!in.eof()) {
    char c = in.get();
    if (c == '\\') {
      out << static_cast<char>(in.get());
      continue;
    }
    out << c;
    if (c == '[') ++brace_depth;
    if (c == ']') --brace_depth;
    if (brace_depth == 0) break;
  }
  if (in.eof() && brace_depth > 0) {
    raise_error << "unbalanced '['\n" << end();
    out.clear();
  }
}

// Read a code string. Code strings can contain either code or regular strings.
void slurp_quoted_comment_aware(istream& in, ostream& out) {
  char c;
  while (in >> c) {
    if (c == '\\') {
      out << static_cast<char>(in.get());
      continue;
    }
    if (c == '#') {
      out << c;
      while (!in.eof() && in.peek() != '\n') out << static_cast<char>(in.get());
      continue;
    }
    if (c == '[') {
      in.putback(c);
      // recurse
      out << slurp_quoted(in);
      continue;
    }
    out << c;
    if (c == ']') return;
  }
  raise_error << "unbalanced '['\n" << end();
  out.clear();
}

:(after "Parsing reagent(string s)")
if (s.at(0) == '[') {
  assert(*s.rbegin() == ']');
  // delete [] delimiters
  s.erase(0, 1);
  strip_last(s);
  name = s;
  type = new type_tree(0);
  properties.push_back(pair<string, string_tree*>(name, new string_tree("literal-string")));
  return;
}

//: Unlike other reagents, escape newlines in literal strings to make them
//: more friendly to trace().

:(after "string reagent::to_string()")
  if (is_literal_string(*this))
    return emit_literal_string(name);

:(code)
bool is_literal_string(const reagent& x) {
  return x.properties.at(0).second && x.properties.at(0).second->value == "literal-string";
}

string emit_literal_string(string name) {
  size_t pos = 0;
  while (pos != string::npos)
    pos = replace(name, "\n", "\\n", pos);
  return "{\""+name+"\": \"literal-string\"}";
}

size_t replace(string& str, const string& from, const string& to, size_t n) {
  size_t result = str.find(from, n);
  if (result != string::npos)
    str.replace(result, from.length(), to);
  return result;
}

void strip_last(string& s) {
  if (!s.empty()) s.erase(SIZE(s)-1);
}

:(scenario string_literal_nested)
recipe main [
  1:address:array:character <- copy [abc [def]]
]
+parse:   ingredient: {"abc [def]": "literal-string"}

:(scenario string_literal_escaped)
recipe main [
  1:address:array:character <- copy [abc \[def]
]
+parse:   ingredient: {"abc [def": "literal-string"}

:(scenario string_literal_escaped_comment_aware)
recipe main [
  1:address:array:character <- copy [
abc \\\[def]
]
+parse:   ingredient: {"\nabc \[def": "literal-string"}

:(scenario string_literal_and_comment)
recipe main [
  1:address:array:character <- copy [abc]  # comment
]
+parse: --- defining main
+parse: instruction: copy
+parse:   number of ingredients: 1
+parse:   ingredient: {"abc": "literal-string"}
+parse:   product: {"1": <"address" : <"array" : <"character" : <>>>>}

:(scenario string_literal_escapes_newlines_in_trace)
recipe main [
  copy [abc
def]
]
+parse:   ingredient: {"abc\ndef": "literal-string"}

:(scenario string_literal_can_skip_past_comments)
recipe main [
  copy [
    # ']' inside comment
    bar
  ]
]
+parse:   ingredient: {"\n    # ']' inside comment\n    bar\n  ": "literal-string"}

:(scenario string_literal_empty)
recipe main [
  copy []
]
+parse:   ingredient: {"": "literal-string"}
