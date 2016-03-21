//: Support literal non-integers.

:(scenarios load)
:(scenario noninteger_literal)
def main [
  1:number <- copy 3.14159
]
+parse:   ingredient: {3.14159: "literal-fractional-number"}

:(after "Parsing reagent(string s)")
if (is_noninteger(s)) {
  name = s;
  type = new type_tree("literal-fractional-number", 0);
  set_value(to_double(s));
  return;
}

:(code)
bool is_noninteger(const string& s) {
  return s.find_first_not_of("0123456789-.") == string::npos  // no other characters
      && s.find_first_of("0123456789") != string::npos  // at least one digit
      && s.find('-', 1) == string::npos  // '-' only at first position
      && std::count(s.begin(), s.end(), '.') == 1;  // exactly one decimal point
}

double to_double(string n) {
  char* end = NULL;
  // safe because string.c_str() is guaranteed to be null-terminated
  double result = strtod(n.c_str(), &end);
  assert(*end == '\0');
  return result;
}

void test_is_noninteger() {
  CHECK(!is_noninteger("1234"));
  CHECK(!is_noninteger("1a2"));
  CHECK(is_noninteger("234.0"));
  CHECK(!is_noninteger("..."));
  CHECK(!is_noninteger("."));
  CHECK(is_noninteger("2."));
  CHECK(is_noninteger(".2"));
  CHECK(is_noninteger("-.2"));
  CHECK(is_noninteger("-2."));
  CHECK(!is_noninteger("--.2"));
  CHECK(!is_noninteger(".-2"));
  CHECK(!is_noninteger("..2"));
}
