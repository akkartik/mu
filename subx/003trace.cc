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
//: In response, this layer introduces the notion of *domain-driven* testing.
//: We focus on the domain of inputs the whole program needs to handle rather
//: than the correctness of individual functions. All tests invoke the program
//: in a single way: by calling run() with some input. As the program operates
//: on the input, it traces out a list of _facts_ deduced about the domain:
//:   trace("label") << "fact 1: " << val;
//:
//: Tests can now check these facts:
//:   :(scenario foo)
//:   34  # call run() with this input
//:   +label: fact 1: 34  # 'run' should have deduced this fact
//:   -label: fact 1: 35  # the trace should not contain such a fact
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
//: fundamentally different activity. Instead of a) superficial, b) local rules
//: on c) code [like say http://blog.bbv.ch/2013/06/05/clean-code-cheat-sheet],
//: we allow programmers to engage with the a) deep, b) global structure of the
//: c) domain. If you can systematically track discontinuities in the domain,
//: you don't care if the code used gotos as long as it passed the tests. If
//: tests become more robust to run it becomes easier to try out radically
//: different implementations for the same program. If code is super-easy to
//: rewrite, it becomes less important what indentation style it uses, or that
//: the objects are appropriately encapsulated, or that the functions are
//: referentially transparent.
//:
//: Instead of plumbing, programming becomes building and gradually refining a
//: map of the environment the program must operate under. Whether a program is
//: 'correct' at a given point in time is a red herring; what matters is
//: avoiding regression by monotonically nailing down the more 'eventful' parts
//: of the terrain. It helps readers new and old, and rewards curiosity, to
//: organize large programs in self-similar hierarchies of example scenarios
//: colocated with the code that makes them work.
//:
//:   "Programming properly should be regarded as an activity by which
//:   programmers form a mental model, rather than as production of a program."
//:   -- Peter Naur (http://alistair.cockburn.us/ASD+book+extract%3A+%22Naur,+Ehn,+Musashi%22)

:(before "End Types")
struct trace_line {
  int depth;  // optional field just to help browse traces later
  string label;
  string contents;
  trace_line(string l, string c) :depth(0), label(l), contents(c) {}
  trace_line(int d, string l, string c) :depth(d), label(l), contents(c) {}
};

//: Support for tracing an entire run.
//: Traces can have a lot of overhead, so only turn them on when asked.
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--trace")) {
  Save_trace = true;
}
:(before "End Commandline Parsing")
if (Save_trace) {
  cerr << "initializing trace\n";
  Trace_stream = new trace_stream;
}
:(code)
void cleanup_main() {
  if (!Trace_stream) return;
  if (Save_trace)
    Trace_stream->save();
  delete Trace_stream;
  Trace_stream = NULL;
}
:(before "End One-time Setup")
atexit(cleanup_main);

:(before "End Types")
// Pre-define some global constants that trace_stream needs to know about.
// Since they're in the Types section, they'll be included in any cleaved
// compilation units. So no extern linkage.
const int Max_depth = 9999;
const int Error_depth = 0;  // definitely always print errors
const int Warn_depth = 1;

struct trace_stream {
  vector<trace_line> past_lines;
  // accumulator for current line
  ostringstream* curr_stream;
  string curr_label;
  int curr_depth;
  int collect_depth;
  ofstream null_stream;  // never opens a file, so writes silently fail
  trace_stream() :curr_stream(NULL), curr_depth(Max_depth), collect_depth(Max_depth) {}
  ~trace_stream() { if (curr_stream) delete curr_stream; }

  ostream& stream(string label) {
    return stream(Max_depth, label);
  }

  ostream& stream(int depth, string label) {
    if (depth > collect_depth) return null_stream;
    curr_stream = new ostringstream;
    curr_label = label;
    curr_depth = depth;
    return *curr_stream;
  }

  void save() {
    cerr << "saving trace to 'last_run'\n";
    ofstream fout("last_run");
    fout << readable_contents("");
    fout.close();
  }

  // be sure to call this before messing with curr_stream or curr_label
  void newline();
  // useful for debugging
  string readable_contents(string label);  // empty label = show everything
};

:(code)
void trace_stream::newline() {
  if (!curr_stream) return;
  string curr_contents = curr_stream->str();
  if (!curr_contents.empty()) {
    past_lines.push_back(trace_line(curr_depth, trim(curr_label), curr_contents));  // preserve indent in contents
    if ((!Hide_errors && curr_depth == Error_depth)
        || (!Hide_warnings && !Hide_errors && curr_depth == Warn_depth)
        || Dump_trace
        || (!Dump_label.empty() && curr_label == Dump_label))
      cerr << curr_label << ": " << curr_contents << '\n';
  }
  delete curr_stream;
  curr_stream = NULL;
  curr_label.clear();
  curr_depth = Max_depth;
}

string trace_stream::readable_contents(string label) {
  ostringstream output;
  label = trim(label);
  for (vector<trace_line>::iterator p = past_lines.begin();  p != past_lines.end();  ++p)
    if (label.empty() || label == p->label) {
      output << std::setw(4) << p->depth << ' ' << p->label << ": " << p->contents << '\n';
    }
  return output.str();
}

:(before "End Globals")
trace_stream* Trace_stream = NULL;
int Trace_errors = 0;  // used only when Trace_stream is NULL

:(before "End Globals")
bool Hide_errors = false;  // if set, don't print even error trace lines to screen
bool Hide_warnings = false;  // if set, don't print warnings to screen
bool Dump_trace = false;  // if set, print trace lines to screen
string Dump_label = "";  // if set, print trace lines matching a single label to screen
:(before "End Reset")
Hide_errors = false;
Hide_warnings = false;
Dump_trace = false;
Dump_label = "";
//: Never dump warnings in scenarios
:(before "End Test Setup")
Hide_warnings = true;

:(before "End Includes")
#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

// Top-level helper. IMPORTANT: can't nest
#define trace(...)  !Trace_stream ? cerr /*print nothing*/ : Trace_stream->stream(__VA_ARGS__)

// Just for debugging; 'git log' should never show any calls to 'dbg'.
#define dbg trace(0, "a")
#define DUMP(label)  if (Trace_stream) cerr << Trace_stream->readable_contents(label);

// Errors and warnings are special layers.
#define raise  (!Trace_stream ? (++Trace_errors,cerr) /*do print*/ : Trace_stream->stream(Error_depth, "error"))
#define warn (!Trace_stream ? (++Trace_errors,cerr) /*do print*/ : Trace_stream->stream(Warn_depth, "warn"))
// If we aren't yet sure how to deal with some corner case, use assert_for_now
// to indicate that it isn't an inviolable invariant.
#define assert_for_now assert

// Inside tests, fail any tests that displayed (unexpected) errors.
// Expected errors in tests should always be hidden and silently checked for.
:(before "End Test Teardown")
if (Passed && !Hide_errors && trace_contains_errors()) {
  Passed = false;
}
:(code)
bool trace_contains_errors() {
  return Trace_errors > 0 || trace_count("error") > 0;
}

:(before "End Types")
struct end {};
:(code)
ostream& operator<<(ostream& os, end /*unused*/) {
  if (Trace_stream) Trace_stream->newline();
  return os;
}

:(before "End Globals")
bool Save_trace = false;  // if set, write out trace to disk

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
:(before "End Types")
struct lease_tracer {
  lease_tracer();
  ~lease_tracer();
};
:(code)
lease_tracer::lease_tracer() { Trace_stream = new trace_stream; }
lease_tracer::~lease_tracer() {
  if (Save_trace) Trace_stream->save();
  delete Trace_stream, Trace_stream = NULL;
}
:(before "End Includes")
#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;
:(before "End Test Setup")
START_TRACING_UNTIL_END_OF_SCOPE

:(before "End Includes")
#define CHECK_TRACE_CONTENTS(...)  check_trace_contents(__FUNCTION__, __FILE__, __LINE__, __VA_ARGS__)

#define CHECK_TRACE_CONTAINS_ERRORS()  CHECK(trace_contains_errors())
#define CHECK_TRACE_DOESNT_CONTAIN_ERRORS() \
  if (Passed && trace_contains_errors()) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): unexpected errors\n"; \
    DUMP("error"); \
    Passed = false; \
    return; \
  }

#define CHECK_TRACE_COUNT(label, count) \
  if (Passed && trace_count(label) != (count)) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): trace_count of " << label << " should be " << count << '\n'; \
    cerr << "  got " << trace_count(label) << '\n';  /* multiple eval */ \
    DUMP(label); \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

#define CHECK_TRACE_DOESNT_CONTAIN(...)  CHECK(trace_doesnt_contain(__VA_ARGS__))

:(code)
bool check_trace_contents(string FUNCTION, string FILE, int LINE, string expected) {
  if (!Passed) return false;
  if (!Trace_stream) return false;
  vector<string> expected_lines = split(expected, "");
  int curr_expected_line = 0;
  while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
    ++curr_expected_line;
  if (curr_expected_line == SIZE(expected_lines)) return true;
  string label, contents;
  split_label_contents(expected_lines.at(curr_expected_line), &label, &contents);
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (label != p->label) continue;
    if (contents != trim(p->contents)) continue;
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

bool trace_doesnt_contain(string label, string line) {
  return trace_count(label, line) == 0;
}

bool trace_doesnt_contain(string expected) {
  vector<string> tmp = split_first(expected, ": ");
  return trace_doesnt_contain(tmp.at(0), tmp.at(1));
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
