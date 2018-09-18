//: Phase 1 of translating Mu code: load it from a textual representation.
//:
//: The process of translating Mu code:
//:   load -> check types -> convert

:(scenarios load)  // use 'load' instead of 'run' in all scenarios in this layer
:(scenario single_function)
fn foo [
  1 : int <- copy 23
]
+parse: function: foo
+parse:   0 in operands
+parse:   0 in_out operands
+parse: instruction: copy
+parse:   in => 23 : literal
+parse:   in_out => 1 : int

:(code)
void load(string form) {
  istringstream in(form);
  load(in);
}

void load(istream& in) {
  while (has_data(in)) {
    string line_data;
    getline(in, line_data);
    if (line_data.empty()) continue;  // maybe eof
    char c = first_non_whitespace(line_data);
    if (c == '\0') continue;  // only whitespace
    if (c == '#') continue;  // only comment
    trace(99, "parse") << "line: " << line_data << end();
    istringstream lin(line_data);
    while (has_data(lin)) {
      string word_data;
      lin >> word_data;
      if (word_data.empty()) continue;  // maybe eof
      if (word_data[0] == '#') break;  // comment; ignore rest of line
      if (word_data == "record")
        load_record(lin, in);
      else if (word_data == "choice")
        load_choice(lin, in);
      else if (word_data == "var")
        load_global(lin, in);
      else if (word_data == "fn")
        load_function(lin, in);
      else
        raise << "unrecognized top-level keyword '" << word_data << "'; should be one of 'record', 'choice', 'var' or 'fn'\n" << end();
      break;
    }
    // nothing here, because we'll be at the next top-level declaration
  }
}

void load_record(istream& first_line, istream& in) {
}

void load_choice(istream& first_line, istream& in) {
}

void load_global(istream& first_line, istream& in) {
}

void load_function(istream& first_line, istream& in) {
  string name;
  assert(has_data(first_line));
  first_line >> name;
  trace(99, "parse") << "function: " << name << end();
  function_info& curr = new_function(name);
  string tmp;
  // read in parameters
  while (has_data(first_line)) {
    // read operand name
    first_line >> tmp;
//?     cerr << "0: " << tmp << '\n';
    if (tmp == "[") break;
    if (tmp == "->") break;
    assert(tmp != ":");
    curr.in.push_back(operand(tmp));

    // skip ':'
    assert(has_data(first_line));
    first_line >> tmp;
//?     cerr << "1: " << tmp << '\n';
    assert(tmp == ":");  // types are required in function headers

    // read operand type
    assert(has_data(first_line));
    curr.in.back().set_type(first_line);
  }
  // read in-out parameters
  while (tmp != "[" && has_data(first_line)) {
    // read operand name
    first_line >> tmp;
//?     cerr << "inout 0: " << tmp << '\n';
    if (tmp == "[") break;
    assert(tmp != "->");
    assert(tmp != ":");  // types are required in function headers
    curr.in_out.push_back(operand(tmp));

    // skip ':'
    assert(has_data(first_line));
    first_line >> tmp;
//?     cerr << "inout 1: " << tmp << '\n';
    assert(tmp == ":");

    // read operand type
    assert(has_data(first_line));
    curr.in.back().set_type(first_line);
  }
  trace(99, "parse") << "  " << SIZE(curr.in) << " in operands" << end();
  trace(99, "parse") << "  " << SIZE(curr.in_out) << " in_out operands" << end();
  // not bothering checking for tokens past '[' in first_line
  
  // read instructions
  while (has_data(in)) {
    string line_data;
    getline(in, line_data);
    if (first_non_whitespace(line_data) == ']') break;
//?     bool has_in_out = (line_data.find("<-") != string::npos);
    istringstream line(line_data);
    vector<string> words;
    bool has_in_out = false;
    while (has_data(line)) {
      string w;
      line >> w;
      words.push_back(w);
      if (w == "<-")
        has_in_out = true;
    }
    instruction inst;
    int i = 0;
    assert(i < SIZE(words));
    if (has_in_out) {
      while (i < SIZE(words)) {
//?         cerr << "in-out operand: " << i << ' ' << words.at(i) << '\n';
        inst.in_out.push_back(operand(words.at(i)));
        ++i;
        assert(i < SIZE(words));
        if (words.at(i) == ":") {
          ++i;  // skip ':'
          assert(i < SIZE(words));
          assert(words.at(i) != "<-");
          assert(words.at(i) != ":");
          istringstream tmp(words.at(i));
//?           cerr << "setting type to " << i << ' ' << words.at(i) << '\n';
          inst.in_out.back().set_type(tmp);
//?           cerr << "done\n";
          ++i;
          assert(i < SIZE(words));
        }
        if (words.at(i) == "<-") break;
      }
      assert(i < SIZE(words));
      assert(words.at(i) == "<-");
      ++i;
    }
    assert(i < SIZE(words));
    assert(words.at(i) != "<-");
    assert(words.at(i) != ":");
    inst.name = words.at(i);
    ++i;
    while (i < SIZE(words)) {
      inst.in.push_back(operand(words.at(i)));
      ++i;
      if (i < SIZE(words) && words.at(i) == ":") {
        ++i;  // skip ':'
        assert(i < SIZE(words));
        assert(words.at(i) != "<-");
        assert(words.at(i) != ":");
        istringstream tmp(words.at(i));
        inst.in.back().set_type(tmp);
        ++i;
      }
      else if (is_integer(inst.in.back().name)) {
        inst.in.back().type.push_back(Literal_type_id);
      }
    }
    trace(99, "parse") << "instruction: " << inst.name << end();
    for (int i = 0;  i < SIZE(inst.in);  ++i)
      trace(99, "parse") << "  in => " << to_string(inst.in.at(i)) << end();
    for (int i = 0;  i < SIZE(inst.in_out);  ++i)
      trace(99, "parse") << "  in_out => " << to_string(inst.in_out.at(i)) << end();
    curr.instructions.push_back(inst);
  }
}

function_info& new_function(string name) {
  assert(!contains_key(Function_id, name));
  int id = Next_function_id++;
  put(Function_id, name, id);
  assert(!contains_key(Function_info, id));
  function_info& result = Function_info[id];  // insert
  result.id = id;
  result.name = name;
  return result;
}

char first_non_whitespace(string in) {
  for (int i = 0;  i < SIZE(in);  ++i)
    if (!isspace(in.at(i))) return in.at(i);
  return '\0';
}

bool is_integer(const string& s) {
  return s.find_first_not_of("0123456789-") == string::npos  // no other characters
      && s.find_first_of("0123456789") != string::npos  // at least one digit
      && s.find('-', 1) == string::npos;  // '-' only at first position
}

int to_integer(string n) {
  char* end = NULL;
  // safe because string.c_str() is guaranteed to be null-terminated
  int result = strtoll(n.c_str(), &end, /*any base*/0);
  if (*end != '\0') cerr << "tried to convert " << n << " to number\n";
  assert(*end == '\0');
  return result;
}

void test_is_integer() {
  CHECK(is_integer("1234"));
  CHECK(is_integer("-1"));
  CHECK(!is_integer("234.0"));
  CHECK(is_integer("-567"));
  CHECK(!is_integer("89-0"));
  CHECK(!is_integer("-"));
  CHECK(!is_integer("1e3"));  // not supported
}
