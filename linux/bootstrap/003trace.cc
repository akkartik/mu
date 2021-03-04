//: The goal of layers is to make programs more easy to understand and more
//: malleable, easy to rewrite in radical ways without accidentally breaking
//: some corner case. Tests further both goals. They help understandability by
//: letting one make small changes and get feedback. What if I wrote this line
//: like so? What if I removed this function call, is it really necessary?
//: Just try it, see if the tests pass. Want to explore rewriting this bit in
//: this way? Tests put many refactorings on a firmer footing.
//:
//: But the usual way we write tests seems incomplete. Refactorings tend to
//: work in the small, but don't help with changes to function boundaries. If
//: you want to extract a new function you have to manually test-drive it to
//: create tests for it. If you want to inline a function its tests are no
//: longer valid. In both cases you end up having to reorganize code as well as
//: tests, an error-prone activity.
//:
//: In response, this layer introduces the notion of domain-driven *white-box*
//: testing. We focus on the domain of inputs the whole program needs to
//: handle rather than the correctness of individual functions. All white-box
//: tests invoke the program in a single way: by calling run() with some
//: input. As the program operates on the input, it traces out a list of
//: _facts_ deduced about the domain:
//:   trace("label") << "fact 1: " << val;
//:
//: Tests can now check for these facts in the trace:
//:   CHECK_TRACE_CONTENTS("label", "fact 1: 34\n"
//:                                 "fact 2: 35\n");
//:
//: Since we never call anything but the run() function directly, we never have
//: to rewrite the tests when we reorganize the internals of the program. We
//: just have to make sure our rewrite deduces the same facts about the domain,
//: and that's something we're going to have to do anyway.
//:
//: To avoid the combinatorial explosion of integration tests, each layer
//: mainly logs facts to the trace with a common *label*. All tests in a layer
//: tend to check facts with this label. Validating the facts logged with a
//: specific label is like calling functions of that layer directly.
//:
//: To build robust tests, trace facts about your domain rather than details of
//: how you computed them.
//:
//: More details: http://akkartik.name/blog/tracing-tests
//:
//: ---
//:
//: Between layers and domain-driven testing, programming starts to look like a
//: fundamentally different activity. Instead of focusing on a) superficial,
//: b) local rules on c) code [like say http://blog.bbv.ch/2013/06/05/clean-code-cheat-sheet],
//: we allow programmers to engage with the a) deep, b) global structure of
//: the c) domain. If you can systematically track discontinuities in the
//: domain, you don't care if the code used gotos as long as it passed all
//: tests. If tests become more robust to run, it becomes easier to try out
//: radically different implementations for the same program. If code is
//: super-easy to rewrite, it becomes less important what indentation style it
//: uses, or that the objects are appropriately encapsulated, or that the
//: functions are referentially transparent.
//:
//: Instead of plumbing, programming becomes building and gradually refining a
//: map of the environment the program must operate under. Whether a program
//: is 'correct' at a given point in time is a red herring; what matters is
//: avoiding regression by monotonically nailing down the more 'eventful'
//: parts of the terrain. It helps readers new and old, and rewards curiosity,
//: to organize large programs in self-similar hierarchies of example tests
//: colocated with the code that makes them work.
//:
//:   "Programming properly should be regarded as an activity by which
//:   programmers form a mental model, rather than as production of a program."
//:   -- Peter Naur (http://akkartik.name/naur.pdf)

//:: == Core data structures

:(before "End Globals")
trace_stream* Trace_stream = NULL;

:(before "End Types")
struct trace_stream {
  vector<trace_line> past_lines;
  // End trace_stream Fields

  trace_stream() {
    // End trace_stream Constructor
  }
  ~trace_stream() {
    // End trace_stream Destructor
  }
  // End trace_stream Methods
};

//:: == Adding to the trace

//: Top-level method is trace() which can be used like an ostream. Usage:
//:   trace(depth, label) << ... << end();
//: Don't forget the 'end()' to actually append to the trace.
:(before "End Includes")
// No brackets around the expansion so that it prints nothing if Trace_stream
// isn't initialized.
#define trace(...)  !Trace_stream ? cerr : Trace_stream->stream(__VA_ARGS__)

:(before "End trace_stream Fields")
// accumulator for current trace_line
ostringstream* curr_stream;
string curr_label;
int curr_depth;
// other stuff
int collect_depth;  // avoid tracing lower levels for speed
ofstream null_stream;  // never opened, so writes to it silently fail

//: Some constants.
:(before "struct trace_stream")  // include constants in all cleaved compilation units
const int Max_depth = 9999;
:(before "End trace_stream Constructor")
curr_stream = NULL;
curr_depth = Max_depth;
collect_depth = Max_depth;

:(before "struct trace_stream")
struct trace_line {
  string contents;
  string label;
  int depth;  // 0 is 'sea level'; positive integers are progressively 'deeper' and lower level
  trace_line(string c, string l) {
    contents = c;
    label = l;
    depth = 0;
  }
  trace_line(string c, string l, int d) {
    contents = c;
    label = l;
    depth = d;
  }
};

string unescape_newline(string& s) {
  std::stringstream ss;
  for (int i = 0;  i < SIZE(s);  ++i) {
    if (s.at(i) == '\n')
      ss << "\\n";
    else
      ss << s.at(i);
  }
  return ss.str();
}

void dump_trace_line(ostream& s, trace_line& t) {
  s << std::setw(2) << t.depth << ' ' << t.label << ": " << unescape_newline(t.contents) << '\n';
}

//: Starting a new trace line.
:(before "End trace_stream Methods")
ostream& stream(string label) {
  return stream(Max_depth, label);
}

ostream& stream(int depth, string label) {
  if (depth > collect_depth) return null_stream;
  curr_stream = new ostringstream;
  curr_label = label;
  curr_depth = depth;
  (*curr_stream) << std::hex;  // printing addresses is the common case
  return *curr_stream;
}

//: End of a trace line; append it to the trace.
:(before "End Types")
struct end {};
:(code)
ostream& operator<<(ostream& os, end /*unused*/) {
  if (Trace_stream) Trace_stream->newline();
  return os;
}

//: Fatal error.
:(before "End Types")
struct die {};
:(code)
ostream& operator<<(ostream& /*unused*/, die /*unused*/) {
  if (Trace_stream) Trace_stream->newline();
  exit(1);
}

:(before "End trace_stream Methods")
void newline();
:(code)
void trace_stream::newline() {
  if (!curr_stream) return;
  string curr_contents = curr_stream->str();
  if (!curr_contents.empty()) {
    past_lines.push_back(trace_line(curr_contents, trim(curr_label), curr_depth));  // preserve indent in contents
    // maybe print this line to stderr
    trace_line& t = past_lines.back();
    if (should_incrementally_print_trace()) {
      dump_trace_line(cerr, t);
    }
    // End trace Commit
  }

  // clean up
  delete curr_stream;
  curr_stream = NULL;
  curr_label.clear();
  curr_depth = Max_depth;
}

//:: == Initializing the trace in tests

:(before "End Includes")
#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;
:(before "End Test Setup")
START_TRACING_UNTIL_END_OF_SCOPE

//: Trace_stream is a resource, lease_tracer uses RAII to manage it.
:(before "End Types")
struct lease_tracer {
  lease_tracer();
  ~lease_tracer();
};
:(code)
lease_tracer::lease_tracer() { Trace_stream = new trace_stream; }
lease_tracer::~lease_tracer() {
  delete Trace_stream;
  Trace_stream = NULL;
}

//:: == Errors and warnings using traces

:(before "End Includes")
#define raise  (!Trace_stream ? (++Trace_errors,cerr) /*do print*/ : Trace_stream->stream(Error_depth, "error"))
#define warn (!Trace_stream ? (++Trace_errors,cerr) /*do print*/ : Trace_stream->stream(Warn_depth, "warn"))

//: Print errors and warnings to the screen by default.
:(before "struct trace_stream")  // include constants in all cleaved compilation units
const int Error_depth = 0;
const int Warn_depth = 1;
:(before "End Globals")
int Hide_errors = false;  // if set, don't print errors or warnings to screen
int Hide_warnings = false;  // if set, don't print warnings to screen
:(before "End Reset")
Hide_errors = false;
Hide_warnings = false;
//: Never dump warnings in tests
:(before "End Test Setup")
Hide_warnings = true;
:(code)
bool trace_stream::should_incrementally_print_trace() {
  if (!Hide_errors && curr_depth == Error_depth) return true;
  if (!Hide_warnings && !Hide_errors && curr_depth == Warn_depth) return true;
  // End Incremental Trace Print Conditions
  return false;
}
:(before "End trace_stream Methods")
bool should_incrementally_print_trace();

:(before "End Globals")
int Trace_errors = 0;  // used only when Trace_stream is NULL

// Fail tests that displayed (unexpected) errors.
// Expected errors should always be hidden and silently checked for.
:(before "End Test Teardown")
if (Passed && !Hide_errors && trace_contains_errors()) {
  Passed = false;
}
:(code)
bool trace_contains_errors() {
  return Trace_errors > 0 || trace_count("error") > 0;
}

:(before "End Includes")
// If we aren't yet sure how to deal with some corner case, use assert_for_now
// to indicate that it isn't an inviolable invariant.
#define assert_for_now assert
#define raise_for_now raise

//:: == Other assertions on traces
//: Primitives:
//:   - CHECK_TRACE_CONTENTS(lines)
//:     Assert that the trace contains the given lines (separated by newlines)
//:     in order. There can be other intervening lines between them.
//:   - CHECK_TRACE_DOESNT_CONTAIN(line)
//:   - CHECK_TRACE_DOESNT_CONTAIN(label, contents)
//:     Assert that the trace doesn't contain the given (single) line.
//:   - CHECK_TRACE_COUNT(label, count)
//:     Assert that the trace contains exactly 'count' lines with the given
//:     'label'.
//:   - CHECK_TRACE_CONTAINS_ERRORS()
//:   - CHECK_TRACE_DOESNT_CONTAIN_ERRORS()
//:   - trace_count_prefix(label, prefix)
//:     Count the number of trace lines with the given 'label' that start with
//:     the given 'prefix'.

:(before "End Includes")
#define CHECK_TRACE_CONTENTS(...)  check_trace_contents(__FUNCTION__, __FILE__, __LINE__, __VA_ARGS__)

#define CHECK_TRACE_DOESNT_CONTAIN(...)  CHECK(trace_doesnt_contain(__VA_ARGS__))

#define CHECK_TRACE_COUNT(label, count) \
  if (Passed && trace_count(label) != (count)) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): trace_count of " << label << " should be " << count << '\n'; \
    cerr << "  got " << trace_count(label) << '\n';  /* multiple eval */ \
    DUMP(label); \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

#define CHECK_TRACE_CONTAINS_ERRORS()  CHECK(trace_contains_errors())
#define CHECK_TRACE_DOESNT_CONTAIN_ERRORS() \
  if (Passed && trace_contains_errors()) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): unexpected errors\n"; \
    DUMP("error"); \
    Passed = false; \
    return; \
  }

// Allow tests to ignore trace lines generated during setup.
#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream

:(code)
bool check_trace_contents(string FUNCTION, string FILE, int LINE, string expected) {
  if (!Passed) return false;
  if (!Trace_stream) return false;
  vector<string> expected_lines = split(expected, "\n");
  int curr_expected_line = 0;
  while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
    ++curr_expected_line;
  if (curr_expected_line == SIZE(expected_lines)) return true;
  string label, contents;
  split_label_contents(expected_lines.at(curr_expected_line), &label, &contents);
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (label != p->label) continue;
    string t = trim(p->contents);
    if (contents != unescape_newline(t)) continue;
    ++curr_expected_line;
    while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
      ++curr_expected_line;
    if (curr_expected_line == SIZE(expected_lines)) return true;
    split_label_contents(expected_lines.at(curr_expected_line), &label, &contents);
  }

  if (line_exists_anywhere(label, contents)) {
    cerr << "\nF - " << FUNCTION << "(" << FILE << ":" << LINE << "): line [" << label << ": " << contents << "] out of order in trace:\n";
    DUMP("");
  }
  else {
    cerr << "\nF - " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << contents << "] in trace:\n";
    DUMP(label);
  }
  Passed = false;
  return false;
}

bool trace_doesnt_contain(string expected) {
  vector<string> tmp = split_first(expected, ": ");
  if (SIZE(tmp) == 1) {
    raise << expected << ": missing label or contents in trace line\n" << end();
    assert(false);
  }
  return trace_count(tmp.at(0), tmp.at(1)) == 0;
}

int trace_count(string label) {
  return trace_count(label, "");
}

int trace_count(string label, string line) {
  if (!Trace_stream) return 0;
  long result = 0;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (label == p->label) {
      if (line == "" || trim(line) == trim(p->contents))
        ++result;
    }
  }
  return result;
}

int trace_count_prefix(string label, string prefix) {
  if (!Trace_stream) return 0;
  long result = 0;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (label == p->label) {
      if (starts_with(trim(p->contents), trim(prefix)))
        ++result;
    }
  }
  return result;
}

void split_label_contents(const string& s, string* label, string* contents) {
  static const string delim(": ");
  size_t pos = s.find(delim);
  if (pos == string::npos) {
    *label = "";
    *contents = trim(s);
  }
  else {
    *label = trim(s.substr(0, pos));
    *contents = trim(s.substr(pos+SIZE(delim)));
  }
}

bool line_exists_anywhere(const string& label, const string& contents) {
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (label != p->label) continue;
    if (contents == trim(p->contents)) return true;
  }
  return false;
}

vector<string> split(string s, string delim) {
  vector<string> result;
  size_t begin=0, end=s.find(delim);
  while (true) {
    if (end == string::npos) {
      result.push_back(string(s, begin, string::npos));
      break;
    }
    result.push_back(string(s, begin, end-begin));
    begin = end+SIZE(delim);
    end = s.find(delim, begin);
  }
  return result;
}

vector<string> split_first(string s, string delim) {
  vector<string> result;
  size_t end=s.find(delim);
  result.push_back(string(s, 0, end));
  if (end != string::npos)
    result.push_back(string(s, end+SIZE(delim), string::npos));
  return result;
}

//:: == Helpers for debugging using traces

:(before "End Includes")
// To debug why a test is failing, dump its trace using '?'.
#define DUMP(label)  if (Trace_stream) cerr << Trace_stream->readable_contents(label);

// To add temporary prints to the trace, use 'dbg'.
// `git log` should never show any calls to 'dbg'.
#define dbg trace(0, "a")

//: Dump the entire trace to file where it can be browsed offline.
//: Dump the trace as it happens; that way you get something even if the
//: program crashes.

:(before "End Globals")
ofstream Trace_file;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--trace")) {
  cerr << "saving trace to 'last_run'\n";
  Trace_file.open("last_run");
  // Add a dummy line up top; otherwise the `browse_trace` tool currently has
  // no way to expand any lines above an error.
  Trace_file << "   0 dummy: start\n";
  // End --trace Settings
}
:(before "End trace Commit")
if (Trace_file.is_open()) {
  dump_trace_line(Trace_file, t);
  Trace_file.flush();
  past_lines.pop_back();  // economize on memory
}
:(before "End One-time Setup")
atexit(cleanup_main);
:(code)
void cleanup_main() {
  if (Trace_file.is_open()) Trace_file.close();
  // End cleanup_main
}

:(before "End trace_stream Methods")
string readable_contents(string label) {
  string trim(const string& s);  // prototype
  ostringstream output;
  label = trim(label);
  for (vector<trace_line>::iterator p = past_lines.begin();  p != past_lines.end();  ++p)
    if (label.empty() || label == p->label)
      dump_trace_line(output, *p);
  return output.str();
}

//: Print traces to the screen as they happen.
//: Particularly useful when juggling multiple trace streams, like when
//: debugging sandboxes.
:(before "End Globals")
bool Dump_trace = false;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--dump")) {
  Dump_trace = true;
}
:(before "End Incremental Trace Print Conditions")
if (Dump_trace) return true;

//: Miscellaneous helpers.

:(code)
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

:(before "End Includes")
#include <vector>
using std::vector;
#include <list>
using std::list;
#include <set>
using std::set;

#include <sstream>
using std::istringstream;
using std::ostringstream;

#include <fstream>
using std::ifstream;
using std::ofstream;
