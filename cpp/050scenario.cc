//: Support a scenario [ ... ] form at the top level so we can start creating
//: scenarios in mu files just like we do in C++.

:(before "End Types")
struct scenario {
  string name;
  string to_run;
};

:(before "End Globals")
vector<scenario> Scenarios;

//:: How we check Scenarios.

:(scenarios run_mu_scenario)
:(scenario scenario_block)
scenario foo [
  run [
    1:integer <- copy 13:literal
  ]
  memory-should-contain [
    1 <- 13
  ]
]
# checks are inside scenario

:(scenario scenario_multiple_blocks)
scenario foo [
  run [
    1:integer <- copy 13:literal
  ]
  memory-should-contain [
    1 <- 13
  ]
  run [
    2:integer <- copy 13:literal
  ]
  memory-should-contain [
    1 <- 13
    2 <- 13
  ]
]

:(scenario scenario_check_memory_and_trace)
scenario foo [
  run [
    1:integer <- copy 13:literal
    trace [a], [a b c]
  ]
  memory-should-contain [
    1 <- 13
  ]
  trace-should-contain [
    a: a b c
  ]
  trace-should-not-contain [
    a: x y z
  ]
]

:(code)
// just for tests
void run_mu_scenario(const string& form) {
  istringstream in(form);
  in >> std::noskipws;
  assert(next_word(in) == "scenario");
  scenario s = parse_scenario(in);
  run_mu_scenario(s);
}

scenario parse_scenario(istream& in) {
  scenario result;
  result.name = next_word(in);
  skip_bracket(in, "'scenario' must begin with '['");
  ostringstream buffer;
  slurp_until_matching_bracket(in, buffer);
  result.to_run = buffer.str();
  return result;
}

void run_mu_scenario(const scenario& s) {
  bool not_already_inside_test = !Trace_stream;
  if (not_already_inside_test) {
    Trace_file = s.name;
    Trace_stream = new trace_stream;
    setup();
  }
  run("recipe "+s.name+" [ " + s.to_run + " ]");
  if (not_already_inside_test) {
    teardown();
    ofstream fout((Trace_dir+Trace_file).c_str());
    fout << Trace_stream->readable_contents("");
    fout.close();
    delete Trace_stream;
    Trace_stream = NULL;
    Trace_file = "";
  }
}

:(before "End Command Handlers")
else if (command == "scenario") {
  Scenarios.push_back(parse_scenario(in));
}

:(before "End Tests")
time_t mu_time; time(&mu_time);
cerr << "\nMu tests: " << ctime(&mu_time);
for (index_t i = 0; i < Scenarios.size(); ++i) {
//?   cerr << Passed << '\n'; //? 1
  run_mu_scenario(Scenarios[i]);
  if (Passed) cerr << ".";
}

//:: Helpers

:(code)
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
