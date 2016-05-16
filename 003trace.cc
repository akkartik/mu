//: The goal of this skeleton is to make programs more easy to understand and
//: more malleable, easy to rewrite in radical ways without accidentally
//: breaking some corner case. Tests further both goals. They help
//: understandability by letting one make small changes and get feedback. What
//: if I wrote this line like so? What if I removed this function call, is it
//: really necessary? Just try it, see if the tests pass. Want to explore
//: rewriting this bit in this way? Tests put many refactorings on a firmer
//: footing.
//:
//: But the usual way we write tests seems incomplete. Refactorings tend to
//: work in the small, but don't help with changes to function boundaries. If
//: you want to extract a new function you have to manually test-drive it to
//: create tests for it. If you want to inline a function its tests are no
//: longer valid. In both cases you end up having to reorganize code as well as
//: tests, an error-prone activity.
//:
//: This file tries to fix this problem by supporting domain-driven testing
//: We try to focus on the domain of inputs the program should work on. All
//: tests invoke the program in a single way: by calling run() with different
//: inputs. The program operates on the input and logs _facts_ it deduces to a
//: trace:
//:   trace("label") << "fact 1: " << val;
//:
//: The tests check for facts:
//:   :(scenario foo)
//:   34  # call run() with this input
//:   +label: fact 1: 34  # trace should have logged this at the end
//:   -label: fact 1: 35  # trace should never contain such a line
//:
//: Since we never call anything but the run() function directly, we never have
//: to rewrite the tests when we reorganize the internals of the program. We
//: just have to make sure our rewrite deduces the same facts about the domain,
//: and that's something we're going to have to do anyway.
//:
//: To avoid the combinatorial explosion of integration tests, we organize the
//: program into different layers, and each fact is logged to the trace with a
//: specific label. Individual tests can focus on specific labels. In essence,
//: validating the facts logged with a specific label is identical to calling
//: some internal subsystem.
//:
//: Traces interact salubriously with layers. Thanks to our ordering
//: directives, each layer can contain its own tests. They may rely on other
//: layers, but when a test fails its usually due to breakage in the same
//: layer. When multiple tests fail, it's usually useful to debug the very
//: first test to fail. This is in contrast with the traditional approach,
//: where changes can cause breakages in faraway subsystems, and picking the
//: right test to debug can be an important skill to pick up.
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
//: on c) code [like http://blog.bbv.ch/2013/06/05/clean-code-cheat-sheet],
//: we allow programmers to engage with the a) deep, b) global structure of the
//: c) domain. If you can systematically track discontinuities in the domain
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
//: of the terrain. It helps readers new and old and rewards curiosity to
//: organize large programs in self-similar hiearchies of example scenarios
//: colocated with the code that makes them work.
//:
//:   "Programming properly should be regarded as an activity by which
//:   programmers form a mental model, rather than as production of a program."
//:   -- Peter Naur (http://alistair.cockburn.us/ASD+book+extract%3A+%22Naur,+Ehn,+Musashi%22)

:(before "int main")
// End Tracing  // hack to ensure most code in this layer comes before anything else

:(before "End Types")
struct trace_line {
  int depth;  // optional field just to help browse traces later
  string label;
  string contents;
  trace_line(string l, string c) :depth(0), label(l), contents(c) {}
  trace_line(int d, string l, string c) :depth(d), label(l), contents(c) {}
};

:(before "End Globals")
const int Max_depth = 9999;
const int Error_depth = 0;  // definitely always print errors
const int App_depth = 2;  // temporarily where all mu code will trace to
:(before "End Tracing")
bool Hide_errors = false;
:(before "End Setup")
Hide_errors = false;

:(before "End Tracing")
struct trace_stream {
  vector<trace_line> past_lines;
  // accumulator for current line
  ostringstream* curr_stream;
  string curr_label;
  int curr_depth;
  int callstack_depth;
  int collect_depth;
  ofstream null_stream;  // never opens a file, so writes silently fail
  trace_stream() :curr_stream(NULL), curr_depth(Max_depth), callstack_depth(0), collect_depth(Max_depth) {}
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

  // be sure to call this before messing with curr_stream or curr_label
  void newline() {
    if (!curr_stream) return;
    string curr_contents = curr_stream->str();
    if (curr_contents.empty()) return;
    past_lines.push_back(trace_line(curr_depth, trim(curr_label), curr_contents));  // preserve indent in contents
    if (!Hide_errors && curr_label == "error")
      cerr << curr_label << ": " << curr_contents << '\n';
    delete curr_stream;
    curr_stream = NULL;
    curr_label.clear();
    curr_depth = Max_depth;
  }

  // useful for debugging
  string readable_contents(string label) {  // empty label = show everything
    ostringstream output;
    label = trim(label);
    for (vector<trace_line>::iterator p = past_lines.begin(); p != past_lines.end(); ++p)
      if (label.empty() || label == p->label) {
        output << std::setw(4) << p->depth << ' ' << p->label << ": " << p->contents << '\n';
      }
    return output.str();
  }
};



trace_stream* Trace_stream = NULL;

// Top-level helper. IMPORTANT: can't nest
#define trace(...)  !Trace_stream ? cerr /*print nothing*/ : Trace_stream->stream(__VA_ARGS__)

// Errors are a special layer.
#define raise  (!Trace_stream ? (tb_shutdown(),cerr) /*do print*/ : Trace_stream->stream(Error_depth, "error"))
// Inside tests, fail any tests that displayed (unexpected) errors.
// Expected errors in tests should always be hidden and silently checked for.
:(before "End Test Teardown")
if (Passed && !Hide_errors && trace_count("error") > 0) {
  Passed = false;
  ++Num_failures;
}

// Just for debugging.
#define dbg trace(0, "a")

:(before "End Types")
struct end {};
:(before "End Tracing")
ostream& operator<<(ostream& os, unused end) {
  if (Trace_stream) Trace_stream->newline();
  return os;
}

#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

#define DUMP(label)  if (Trace_stream) cerr << Trace_stream->readable_contents(label);

// All scenarios save their traces in the repo, just like code. This gives
// future readers more meat when they try to make sense of a new project.
static string Trace_dir = ".traces/";
string Trace_file;

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
struct lease_tracer {
  lease_tracer() { Trace_stream = new trace_stream; }
  ~lease_tracer() {
    if (!Trace_stream) return;  // in case tests close Trace_stream
    if (!Trace_file.empty()) {
      ofstream fout((Trace_dir+Trace_file).c_str());
      fout << Trace_stream->readable_contents("");
      fout.close();
    }
    delete Trace_stream, Trace_stream = NULL, Trace_file = "";
  }
};

#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;
:(before "End Test Setup")
START_TRACING_UNTIL_END_OF_SCOPE

:(before "End Includes")
#define CHECK_TRACE_CONTENTS(...)  check_trace_contents(__FUNCTION__, __FILE__, __LINE__, __VA_ARGS__)

:(before "End Tracing")
bool check_trace_contents(string FUNCTION, string FILE, int LINE, string expected) {
  if (!Trace_stream) return false;
  vector<string> expected_lines = split(expected, "");
  int curr_expected_line = 0;
  while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
    ++curr_expected_line;
  if (curr_expected_line == SIZE(expected_lines)) return true;
  string label, contents;
  split_label_contents(expected_lines.at(curr_expected_line), &label, &contents);
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (label != p->label)
      continue;

    if (contents != trim(p->contents))
      continue;

    ++curr_expected_line;
    while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
      ++curr_expected_line;
    if (curr_expected_line == SIZE(expected_lines)) return true;
    split_label_contents(expected_lines.at(curr_expected_line), &label, &contents);
  }

  ++Num_failures;
  cerr << "\nF - " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << contents << "] in trace:\n";
  DUMP(label);
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



int trace_count(string label) {
  return trace_count(label, "");
}

int trace_count(string label, string line) {
  if (!Trace_stream) return 0;
  long result = 0;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (label == p->label) {
      if (line == "" || trim(line) == trim(p->contents))
        ++result;
    }
  }
  return result;
}

#define CHECK_TRACE_CONTAINS_ERROR()  CHECK(trace_count("error") > 0)
#define CHECK_TRACE_DOESNT_CONTAIN_ERROR() \
  if (trace_count("error") > 0) { \
    ++Num_failures; \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): unexpected errors\n"; \
    DUMP("error"); \
    Passed = false; \
    return; \
  }

#define CHECK_TRACE_COUNT(label, count) \
  if (trace_count(label) != (count)) { \
    ++Num_failures; \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): trace_count of " << label << " should be " << count << '\n'; \
    cerr << "  got " << trace_count(label) << '\n';  /* multiple eval */ \
    DUMP(label); \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

bool trace_doesnt_contain(string label, string line) {
  return trace_count(label, line) == 0;
}

bool trace_doesnt_contain(string expected) {
  vector<string> tmp = split_first(expected, ": ");
  return trace_doesnt_contain(tmp.at(0), tmp.at(1));
}

#define CHECK_TRACE_DOESNT_CONTAIN(...)  CHECK(trace_doesnt_contain(__VA_ARGS__))



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
#include<vector>
using std::vector;
#include<list>
using std::list;
#include<map>
using std::map;
#include<set>
using std::set;
#include<algorithm>

#include<sstream>
using std::istringstream;
using std::ostringstream;

#include<fstream>
using std::ifstream;
using std::ofstream;

#include"termbox/termbox.h"

#define unused  __attribute__((unused))

:(before "End Globals")
//: In future layers we'll use the depth field as follows:
//:
//: Errors will be depth 0.
//: Mu 'applications' will be able to use depths 1-100 as they like.
//: Primitive statements will occupy 101-9989
const int Initial_callstack_depth = 101;
const int Max_callstack_depth = 9989;
//: Finally, details of primitive mu statements will occupy depth 9990-9999 (more on that later as well)
//:
//: This framework should help us hide some details at each level, mixing
//: static ideas like layers with the dynamic notion of call-stack depth.
