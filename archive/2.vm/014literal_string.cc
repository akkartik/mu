//: For convenience, some instructions will take literal arrays of characters
//: (text or strings).
//:
//: Instead of quotes, we'll use [] to delimit strings. That'll reduce the
//: need for escaping since we can support nested brackets. And we can also
//: imagine that 'recipe' might one day itself be defined in Mu, doing its own
//: parsing.

void test_string_literal() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [abc def]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"abc def\": \"literal-string\"}\n"
  );
}

void test_string_literal_with_colons() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [abc:def/ghi]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"abc:def/ghi\": \"literal-string\"}\n"
  );
}

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-string", 0);

:(before "End next_word Special-cases")
if (in.peek() == '[') {
  string result = slurp_quoted(in);
  skip_whitespace_and_comments_but_not_newline(in);
  return result;
}

:(code)
string slurp_quoted(istream& in) {
  ostringstream out;
  assert(has_data(in));  assert(in.peek() == '[');  out << static_cast<char>(in.get());  // slurp the '['
  if (is_code_string(in, out))
    slurp_quoted_comment_aware(in, out);
  else
    slurp_quoted_comment_oblivious(in, out);
  return out.str();
}

// A string is a code string (ignores comments when scanning for matching
// brackets) if it contains a newline at the start before any non-whitespace.
bool is_code_string(istream& in, ostream& out) {
  while (has_data(in)) {
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
  while (has_data(in)) {
    char c = in.get();
    if (c == '\\') {
      slurp_one_past_backslashes(in, out);
      continue;
    }
    out << c;
    if (c == '[') ++brace_depth;
    if (c == ']') --brace_depth;
    if (brace_depth == 0) break;
  }
  if (!has_data(in) && brace_depth > 0) {
    raise << "unbalanced '['\n" << end();
    out.clear();
  }
}

// Read a code string. Code strings can contain either code or regular strings.
void slurp_quoted_comment_aware(istream& in, ostream& out) {
  char c;
  while (in >> c) {
    if (c == '\\') {
      slurp_one_past_backslashes(in, out);
      continue;
    }
    if (c == '#') {
      out << c;
      while (has_data(in) && in.peek() != '\n') out << static_cast<char>(in.get());
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
  raise << "unbalanced '['\n" << end();
  out.clear();
}

:(after "Parsing reagent(string s)")
if (starts_with(s, "[")) {
  if (*s.rbegin() != ']') return;  // unbalanced bracket; handled elsewhere
  name = s;
  // delete [] delimiters
  name.erase(0, 1);
  strip_last(name);
  type = new type_tree("literal-string", 0);
  return;
}

//: Unlike other reagents, escape newlines in literal strings to make them
//: more friendly to trace().

:(after "string to_string(const reagent& r)")
  if (is_literal_text(r))
    return emit_literal_string(r.name);

:(code)
bool is_literal_text(const reagent& x) {
  return x.type && x.type->name == "literal-string";
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

void slurp_one_past_backslashes(istream& in, ostream& out) {
  // When you encounter a backslash, strip it out and pass through any
  // following run of backslashes. If we 'escaped' a single following
  // character, then the character '\' would be:
  //   '\\' escaped once
  //   '\\\\' escaped twice
  //   '\\\\\\\\' escaped thrice (8 backslashes)
  // ..and so on. With our approach it'll be:
  //   '\\' escaped once
  //   '\\\' escaped twice
  //   '\\\\' escaped thrice
  // This only works as long as backslashes aren't also overloaded to create
  // special characters. So Mu doesn't follow C's approach of overloading
  // backslashes both to escape quote characters and also as a notation for
  // unprintable characters like '\n'.
  while (has_data(in)) {
    char c = in.get();
    out << c;
    if (c != '\\') break;
  }
}

void test_string_literal_nested() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [abc [def]]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"abc [def]\": \"literal-string\"}\n"
  );
}

void test_string_literal_escaped() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [abc \\[def]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"abc [def\": \"literal-string\"}\n"
  );
}

void test_string_literal_escaped_twice() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [\n"
      "abc \\\\[def]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"\\nabc \\[def\": \"literal-string\"}\n"
  );
}

void test_string_literal_and_comment() {
  load(
      "def main [\n"
      "  1:address:array:character <- copy [abc]  # comment\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse: --- defining main\n"
      "parse: instruction: copy\n"
      "parse:   number of ingredients: 1\n"
      "parse:   ingredient: {\"abc\": \"literal-string\"}\n"
      "parse:   product: {1: (\"address\" \"array\" \"character\")}\n"
  );
}

void test_string_literal_escapes_newlines_in_trace() {
  load(
      "def main [\n"
      "  copy [abc\n"
      "def]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"abc\\ndef\": \"literal-string\"}\n"
  );
}

void test_string_literal_can_skip_past_comments() {
  load(
      "def main [\n"
      "  copy [\n"
      "    # ']' inside comment\n"
      "    bar\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"\\n    # ']' inside comment\\n    bar\\n  \": \"literal-string\"}\n"
  );
}

void test_string_literal_empty() {
  load(
      "def main [\n"
      "  copy []\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {\"\": \"literal-string\"}\n"
  );
}

void test_multiple_unfinished_recipes() {
  Hide_errors = true;
  load(
      "def f1 [\n"
      "def f2 [\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: unbalanced '['\n"
  );
}
