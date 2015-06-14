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
+parse:   ingredient: {name: "abc def", properties: [_: "literal-string"]}

:(scenario string_literal_with_colons)
recipe main [
  1:address:array:character <- copy [abc:def/ghi]
]
+parse:   ingredient: {name: "abc:def/ghi", properties: [_: "literal-string"]}

:(before "End Mu Types Initialization")
Type_number["literal-string"] = 0;

:(after "string next_word(istream& in)")
  if (in.peek() == '[') {
    string result = slurp_quoted(in);
    skip_whitespace(in);
    skip_comment(in);
    return result;
  }

:(code)
string slurp_quoted(istream& in) {
  assert(!in.eof());
  assert(in.peek() == '[');
  ostringstream out;
  int brace_depth = 0;
  while (!in.eof()) {
    char c = in.get();
//?     cout << (int)c << ": " << brace_depth << '\n'; //? 2
    if (c == '\\') {
      out << (char)in.get();
      continue;
    }
    out << c;
//?     cout << out.str() << "$\n"; //? 1
    if (c == '[') ++brace_depth;
    if (c == ']') --brace_depth;
    if (brace_depth == 0) break;
  }
  if (in.eof() && brace_depth > 0) {
    raise << "unbalanced '['\n";
    return "";
  }
  return out.str();
}

:(after "reagent::reagent(string s)")
//?   cout << s.at(0) << '\n'; //? 1
  if (s.at(0) == '[') {
    assert(*s.rbegin() == ']');
    // delete [] delimiters
    s.erase(0, 1);
    s.erase(SIZE(s)-1, SIZE(s));
    name = s;
    types.push_back(0);
    properties.push_back(pair<string, vector<string> >(name, vector<string>()));
    properties.back().second.push_back("literal-string");
    return;
  }

//: Two tweaks to printing literal strings compared to other reagents:
//:   a) Don't print the string twice in the representation, just put '_' in
//:   the property list.
//:   b) Escape newlines in the string to make it more friendly to trace().

:(after "string reagent::to_string()")
  if (!properties.at(0).second.empty() && properties.at(0).second.at(0) == "literal-string") {
    return emit_literal_string(name);
  }

:(code)
string emit_literal_string(string name) {
  size_t pos = 0;
  while (pos != string::npos)
    pos = replace(name, "\n", "\\n", pos);
  return "{name: \""+name+"\", properties: [_: \"literal-string\"]}";
}

size_t replace(string& str, const string& from, const string& to, size_t n) {
  size_t result = str.find(from, n);
  if (result != string::npos)
    str.replace(result, from.length(), to);
  return result;
}

:(scenario string_literal_nested)
recipe main [
  1:address:array:character <- copy [abc [def]]
]
+parse:   ingredient: {name: "abc [def]", properties: [_: "literal-string"]}

:(scenario string_literal_escaped)
recipe main [
  1:address:array:character <- copy [abc \[def]
]
+parse:   ingredient: {name: "abc [def", properties: [_: "literal-string"]}

:(scenario string_literal_and_comment)
recipe main [
  1:address:array:character <- copy [abc]  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "abc", properties: [_: "literal-string"]}
+parse:   product: {name: "1", properties: ["1": "address":"array":"character"]}
# no other ingredients
$parse: 3

:(scenario string_literal_escapes_newlines_in_trace)
recipe main [
  copy [abc
def]
]
+parse:   ingredient: {name: "abc\ndef", properties: [_: "literal-string"]}
