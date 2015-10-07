//: Support literal non-integers.

:(scenarios load)
:(scenario noninteger_literal)
recipe main [
  1:number <- copy 3.14159
]
+parse:   ingredient: {name: "3.14159", properties: ["3.14159": "literal-number"]}

:(after "Parsing reagent(string s)")
if (is_noninteger(s)) {
  name = s;
  types.push_back(0);
  properties.push_back(pair<string, vector<string> >(name, vector<string>()));
  properties.back().second.push_back("literal-number");
  set_value(to_double(s));
  return;
}

:(code)
bool is_noninteger(const string& s) {
  return s.find_first_not_of("0123456789-.") == string::npos
      && std::count(s.begin(), s.end(), '.') == 1;
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
}
