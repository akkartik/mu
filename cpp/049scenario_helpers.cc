//: Some pseudo-primitives to support writing tests in mu.
//: When we throw out the C layer these will require more work.

//:: 'run' can interpret a string as a set of instructions

:(scenario run)
#? % Trace_stream->dump_layer = "all";
recipe main [
  run [
    1:integer <- copy 13:literal
  ]
]
+mem: storing 13 in location 1

:(before "End Globals")
size_t Num_temporary_recipes = 0;
:(before "End Setup")
Num_temporary_recipes = 0;

:(before "End Primitive Recipe Declarations")
RUN,
:(before "End Primitive Recipe Numbers")
Recipe_number["run"] = RUN;
:(before "End Primitive Recipe Implementations")
case RUN: {
//?   cout << "recipe " << current_instruction().ingredients[0].name << '\n'; //? 1
  ostringstream tmp;
  tmp << "recipe tmp" << Num_temporary_recipes++ << " [ " << current_instruction().ingredients[0].name << " ]";
  vector<recipe_number> tmp_recipe = load(tmp.str());
  transform_all();
//?   cout << tmp_recipe[0] << ' ' << Recipe_number["main"] << '\n'; //? 1
  Current_routine->calls.push(call(tmp_recipe[0]));
  continue;  // not done with caller; don't increment current_step_index()
}

:(scenario run_multiple)
recipe main [
  run [
    1:integer <- copy 13:literal
  ]
  run [
    2:integer <- copy 13:literal
  ]
]
+mem: storing 13 in location 1
+mem: storing 13 in location 2

//:: memory-should-contain can raise warnings if specific locations aren't as
//:: expected.

:(scenario memory_check)
% Hide_warnings = true;
recipe main [
  memory-should-contain [
    1 <- 13
  ]
]
+run: checking location 1
+warn: expected location 1 to contain 13 but saw 0

:(before "End Primitive Recipe Declarations")
MEMORY_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
Recipe_number["memory-should-contain"] = MEMORY_SHOULD_CONTAIN;
:(before "End Primitive Recipe Implementations")
case MEMORY_SHOULD_CONTAIN: {
//?   cout << current_instruction().ingredients[0].name << '\n'; //? 1
  check_memory(current_instruction().ingredients[0].name);
  break;
}

:(code)
void check_memory(const string& s) {
  istringstream in(s);
  in >> std::noskipws;
  set<size_t> locations_checked;
  while (true) {
    skip_whitespace_and_comments(in);
    if (in.eof()) break;
    string lhs = next_word(in);
    if (!is_number(lhs)) {
      check_type(lhs, in);
      continue;
    }
    int address = to_int(lhs);
    skip_whitespace_and_comments(in);
    string _assign;  in >> _assign;  assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    int value = 0;  in >> value;
    if (locations_checked.find(address) != locations_checked.end())
      raise << "duplicate expectation for location " << address << '\n';
    trace("run") << "checking location " << address;
    if (Memory[address] != value)
      raise << "expected location " << address << " to contain " << value << " but saw " << Memory[address] << '\n';
    locations_checked.insert(address);
  }
}

void check_type(const string& lhs, istream& in) {
  reagent x(lhs);
  if (x.properties[0].second[0] == "string") {
    x.set_value(to_int(x.name));
    skip_whitespace_and_comments(in);
    string _assign = next_word(in);
    assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string literal = next_word(in);
    size_t address = x.value;
    trace("run") << "checking array length at " << address;
    if (Memory[address] != static_cast<signed>(literal.size()-2))  // exclude quoting brackets
      raise << "expected location " << address << " to contain length " << literal.size()-2 << " of string " << literal << " but saw " << Memory[address] << '\n';
    for (size_t i = 1; i < literal.size()-1; ++i) {
      trace("run") << "checking location " << address+i;
      if (Memory[address+i] != literal[i])
        raise << "expected location " << (address+i) << " to contain " << literal[i] << " but saw " << Memory[address+i] << '\n';
    }
    return;
  }
  raise << "don't know how to check memory for " << lhs << '\n';
}

:(scenario memory_check_multiple)
% Hide_warnings = true;
recipe main [
  memory-should-contain [
    1 <- 0
    1 <- 0
  ]
]
+warn: duplicate expectation for location 1

:(scenario memory_check_string_length)
% Hide_warnings = true;
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 97:literal  # 'a'
  3:integer <- copy 98:literal  # 'b'
  4:integer <- copy 99:literal  # 'c'
  memory-should-contain [
    1:string <- [ab]
  ]
]
+warn: expected location 1 to contain length 2 of string [ab] but saw 3

:(scenario memory_check_string)
recipe main [
  1:integer <- copy 3:literal
  2:integer <- copy 97:literal  # 'a'
  3:integer <- copy 98:literal  # 'b'
  4:integer <- copy 99:literal  # 'c'
  memory-should-contain [
    1:string <- [abc]
  ]
]
+run: checking array length at 1
+run: checking location 2
+run: checking location 3
+run: checking location 4

//:: trace-should-contain and trace-should-not-contain raise warnings if the
//:: trace doesn't meet given conditions

:(scenario trace_check_warns_on_failure)
% Hide_warnings = true;
recipe main [
  trace-should-contain [
    a: b
    a: d
  ]
]
+warn: missing [b] in trace layer a

:(before "End Primitive Recipe Declarations")
TRACE_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
Recipe_number["trace-should-contain"] = TRACE_SHOULD_CONTAIN;
:(before "End Primitive Recipe Implementations")
case TRACE_SHOULD_CONTAIN: {
  check_trace(current_instruction().ingredients[0].name);
  break;
}

:(code)
// simplified version of check_trace_contents() that emits warnings rather
// than just printing to stderr
bool check_trace(const string& expected) {
  Trace_stream->newline();
  vector<pair<string, string> > expected_lines = parse_trace(expected);
  if (expected_lines.empty()) return true;
  size_t curr_expected_line = 0;
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (expected_lines[curr_expected_line].first != p->first) continue;
    if (expected_lines[curr_expected_line].second != p->second.second) continue;
    // match
    ++curr_expected_line;
    if (curr_expected_line == expected_lines.size()) return true;
  }

  raise << "missing [" << expected_lines[curr_expected_line].second << "] "
        << "in trace layer " << expected_lines[curr_expected_line].first << '\n';
  return false;
}

vector<pair<string, string> > parse_trace(const string& expected) {
  vector<string> buf = split(expected, "\n");
  vector<pair<string, string> > result;
  for (size_t i = 0; i < buf.size(); ++i) {
    buf[i] = trim(buf[i]);
    if (buf[i].empty()) continue;
    size_t delim = buf[i].find(": ");
    result.push_back(pair<string, string>(buf[i].substr(0, delim), buf[i].substr(delim+2)));
  }
  return result;
}

// see tests for this function in tangle/030tangle.test.cc
string trim(const string& s) {
  string::const_iterator first = s.begin();
  while (first != s.end() && isspace(*first))
    ++first;
  if (first == s.end()) return "";

  string::const_iterator last = --s.end();
  while (last != s.begin() && isspace(*last))
    --last;
  ++last;
  return string(first, last);
}

:(scenario trace_check_warns_on_failure_in_later_line)
% Hide_warnings = true;
recipe main [
  run [
    trace [a], [b]
  ]
  trace-should-contain [
    a: b
    a: d
  ]
]
+warn: missing [d] in trace layer a

:(scenario trace_check_passes_silently)
% Hide_warnings = true;
recipe main [
  run [
    trace [a], [b]
  ]
  trace-should-contain [
    a: b
  ]
]
-warn: missing [b] in trace layer a
