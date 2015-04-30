//: Support a scenario [ ... ] form at the top level so we can start creating
//: scenarios in mu files just like we do in C++.

:(before "End Types")
struct scenario {
  string name;
  string dump_layer;
  string to_run;
  map<int, int> memory_expectations;
  // End scenario Fields
};

:(before "End Globals")
vector<scenario> Scenarios;

//:: How we check Scenarios.

:(before "End Tests")
time_t mu_time; time(&mu_time);
cerr << "\nMu tests: " << ctime(&mu_time);
for (size_t i = 0; i < Scenarios.size(); ++i) {
  run_mu_test(i);
}

:(code)
void run_mu_test(size_t i) {
  setup();
  Trace_file = Scenarios[i].name;
  START_TRACING_UNTIL_END_OF_SCOPE
  if (!Scenarios[i].dump_layer.empty())
    Trace_stream->dump_layer = Scenarios[i].dump_layer;
//?   cerr << "AAA " << Scenarios[i].name << '\n'; //? 1
//?   cout << Scenarios[i].to_run; //? 2
  run(Scenarios[i].to_run);
//?   cout << "after: " << Memory[1] << '\n'; //? 1
//?   cout << "after:\n";  dump_memory(); //? 1
  for (map<int, int>::iterator p = Scenarios[i].memory_expectations.begin();
       p != Scenarios[i].memory_expectations.end();
       ++p) {
    if (Memory[p->first] != p->second) {
      // todo: unit tests for the test parsing infrastructure; use raise?
      cerr << Scenarios[i].name << ": Expected location " << p->first << " to contain " << p->second << " but saw " << Memory[p->first] << '\n';
      Passed = false;
    }
  }
  // End Scenario Checks
  teardown();
  if (Passed) cerr << ".";
}

//:: How we create Scenarios.

:(scenarios "parse_scenario")
:(scenario parse_scenario_memory_expectation)
scenario foo [
  run [
    a <- b
  ]
  memory should contain [
    1 <- 0
  ]
]
+parse: scenario will run: a <- b

:(scenario parse_scenario_memory_expectation_duplicate)
% Hide_warnings = true;
scenario foo [
  run [
    a <- b
  ]
  memory should contain [
    1 <- 0
    1 <- 1
  ]
]
+warn: duplicate expectation for location 1: 0 -> 1

:(before "End Command Handlers")
else if (command == "scenario") {
//?   cout << "AAA scenario\n"; //? 1
  Scenarios.push_back(parse_scenario(in));
}

:(code)
scenario parse_scenario(istream& in) {
  scenario x;
  x.name = next_word(in);
  trace("parse") << "reading scenario " << x.name;
  skip_bracket(in, "'scenario' must begin with '['");
  ostringstream buffer;
  slurp_until_matching_bracket(in, buffer);
//?   cout << "inner buffer: ^" << buffer.str() << "$\n"; //? 1
  istringstream inner(buffer.str());
  inner >> std::noskipws;
  while (!inner.eof()) {
    skip_whitespace_and_comments(inner);
    string scenario_command = next_word(inner);
    if (scenario_command.empty() && inner.eof()) break;
    // Scenario Command Handlers
    if (scenario_command == "run") {
      handle_scenario_run_directive(inner, x);
    }
    else if (scenario_command == "memory") {
      handle_scenario_memory_directive(inner, x);
    }
    else if (scenario_command == "dump") {
      skip_whitespace_and_comments(inner);
      x.dump_layer = next_word(inner);
    }
    // End Scenario Command Handlers
    else {
      raise << "unknown command in scenario: ^" << scenario_command << "$\n";
    }
  }
  return x;
}

void handle_scenario_run_directive(istream& in, scenario& result) {
  skip_bracket(in, "'run' inside scenario must begin with '['");
  ostringstream buffer;
  slurp_until_matching_bracket(in, buffer);
  string trace_result = buffer.str();  // temporary copy
  trace("parse") << "scenario will run: " << trim(trace_result);
//?   cout << buffer.str() << '\n'; //? 1
  result.to_run = "recipe test-"+result.name+" [" + buffer.str() + "]";
}

void handle_scenario_memory_directive(istream& in, scenario& out) {
  if (next_word(in) != "should") {
    raise << "'memory' directive inside scenario must continue 'memory should'\n";
  }
  if (next_word(in) != "contain") {
    raise << "'memory' directive inside scenario must continue 'memory should contain'\n";
  }
  skip_bracket(in, "'memory' directive inside scenario must begin with 'memory should contain ['\n");
  while (true) {
    skip_whitespace_and_comments(in);
    if (in.eof()) break;
//?     cout << "a: " << in.peek() << '\n'; //? 1
    if (in.peek() == ']') break;
    string lhs = next_word(in);
    if (!is_number(lhs)) {
      handle_type(lhs, in, out);
      continue;
    }
    int address = to_int(lhs);
//?     cout << "address: " << address << '\n'; //? 2
//?     cout << "b: " << in.peek() << '\n'; //? 1
    skip_whitespace_and_comments(in);
//?     cout << "c: " << in.peek() << '\n'; //? 1
    string _assign;  in >> _assign;  assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    int value = 0;  in >> value;
    if (out.memory_expectations.find(address) != out.memory_expectations.end())
      raise << "duplicate expectation for location " << address << ": " << out.memory_expectations[address] << " -> " << value << '\n';
    out.memory_expectations[address] = value;
    trace("parse") << "memory expectation: *" << address << " == " << value;
  }
  skip_whitespace(in);
  assert(in.get() == ']');
}

void handle_type(const string& lhs, istream& in, scenario& out) {
  reagent x(lhs);
  if (x.properties[0].second[0] == "string") {
    x.set_value(to_int(x.name));
//?     cerr << x.name << ' ' << x.value << '\n'; //? 1
    skip_whitespace_and_comments(in);
    string _assign = next_word(in);
//?     cerr << _assign << '\n'; //? 1
    assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string literal = next_word(in);
//?     cerr << literal << '\n'; //? 1
    size_t address = x.value;
    out.memory_expectations[address] = literal.size()-2;  // exclude quoting brackets
    ++address;
    for (size_t i = 1; i < literal.size()-1; ++i) {
//?       cerr << "checking " << address << ": " << literal[i] << '\n'; //? 1
      out.memory_expectations[address] = literal[i];
      ++address;
    }
    return;
  }
  raise << "scenario doesn't know how to parse memory expectation on " << lhs << '\n';
}

//:: Helpers

void slurp_until_matching_bracket(istream& in, ostream& out) {
  int brace_depth = 1;  // just scanned '['
  char c;
  while (in >> c) {
    if (c == '[') ++brace_depth;
    if (c == ']') --brace_depth;
    if (brace_depth == 0) break;  // drop final ']'
    out << c;
  }
}

:(code)
// for tests
void parse_scenario(const string& s) {
  istringstream in(s);
  in >> std::noskipws;
  skip_whitespace_and_comments(in);
  string _scenario = next_word(in);
//?   cout << _scenario << '\n'; //? 1
  assert(_scenario == "scenario");
  parse_scenario(in);
}

string &trim(string &s) {
  return ltrim(rtrim(s));
}

string &ltrim(string &s) {
  s.erase(s.begin(), std::find_if(s.begin(), s.end(), std::not1(std::ptr_fun<int, int>(isspace))));
  return s;
}

string &rtrim(string &s) {
  s.erase(std::find_if(s.rbegin(), s.rend(), std::not1(std::ptr_fun<int, int>(isspace))).base(), s.end());
  return s;
}

:(before "End Includes")
#include <sys/stat.h>
:(code)
bool file_exists(const string& filename) {
  struct stat buffer;
  return stat(filename.c_str(), &buffer) == 0;
}
