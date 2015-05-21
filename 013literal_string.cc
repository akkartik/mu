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
+parse:   ingredient: {name: "abc def", properties: ["abc def": "literal-string"]}

:(scenario string_literal_with_colons)
recipe main [
  1:address:array:character <- copy [abc:def/ghi]
]
+parse:   ingredient: {name: "abc:def/ghi", properties: ["abc:def/ghi": "literal-string"]}

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
  int size = 0;
  while (!in.eof()) {
    char c = in.get();
//?     cout << c << '\n'; //? 1
    out << c;
//?     cout << out.str() << "$\n"; //? 1
    if (c == '[') ++size;
    if (c == ']') --size;
    if (size == 0) break;
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

:(scenario string_literal_nested)
recipe main [
  1:address:array:character <- copy [abc [def]]
]
+parse:   ingredient: {name: "abc [def]", properties: ["abc [def]": "literal-string"]}

:(scenario string_literal_and_comment)
recipe main [
  1:address:array:character <- copy [abc]  # comment
]
+parse: instruction: copy
+parse:   ingredient: {name: "abc", properties: ["abc": "literal-string"]}
+parse:   product: {name: "1", properties: ["1": "address":"array":"character"]}
# no other ingredients
$parse: 3
