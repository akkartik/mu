//: Textual form for types.

:(scenarios load)
:(scenario container)
container foo [
  x:integer
  y:integer
]
+parse: reading container foo
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

:(before "End Command Handlers")
else if (command == "container") {
  insert_container(command, container, in);
}

:(code)
void insert_container(const string& command, kind_of_type kind, istream& in) {
  skip_whitespace(in);
  string name = next_word(in);
  trace("parse") << "reading " << command << ' ' << name;
//?   cout << name << '\n'; //? 1
  assert(Type_number.find(name) == Type_number.end());
  Type_number[name] = Next_type_number++;
  skip_bracket(in, "'container' must begin with '['");
  assert(Type.find(Type_number[name]) == Type.end());
  type_info& t = Type[Type_number[name]];
  recently_added_types.push_back(Type_number[name]);
  t.name = name;
  t.kind = kind;
  while (!in.eof()) {
    skip_whitespace_and_comments(in);
    string element = next_word(in);
    if (element == "]") break;
    istringstream inner(element);
    t.element_names.push_back(slurp_until(inner, ':'));
    trace("parse") << "  element name: " << t.element_names.back();
    vector<type_number> types;
    while (!inner.eof()) {
      string type_name = slurp_until(inner, ':');
      if (Type_number.find(type_name) == Type_number.end())
        raise << "unknown type " << type_name << '\n';
      types.push_back(Type_number[type_name]);
      trace("parse") << "  type: " << types.back();
    }
    t.elements.push_back(types);
  }
  assert(t.elements.size() == t.element_names.size());
  t.size = t.elements.size();
}

//:: Similarly for exclusive_container.

:(scenario exclusive_container)
exclusive-container foo [
  x:integer
  y:integer
]
+parse: reading exclusive-container foo
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

:(before "End Command Handlers")
else if (command == "exclusive-container") {
  insert_container(command, exclusive_container, in);
}

//:: ensure types created in one scenario don't leak outside it.
:(before "End Globals")
vector<type_number> recently_added_types;
:(before "End Setup")
for (size_t i = 0; i < recently_added_types.size(); ++i) {
//?   cout << "erasing " << Type[recently_added_types[i]].name << '\n'; //? 1
  Type_number.erase(Type[recently_added_types[i]].name);
  Type.erase(recently_added_types[i]);
}
recently_added_types.clear();
//: lastly, ensure scenarios are consistent by always starting them at the
//: same type number.
Next_type_number = 1000;
:(before "End Test Run Initialization")
assert(Next_type_number < 1000);
:(before "End Setup")
Next_type_number = 1000;

:(code)
void skip_bracket(istream& in, string message) {
  skip_whitespace_and_comments(in);
  if (in.get() != '[')
    raise << message << '\n';
}
