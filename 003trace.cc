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

:(before "End Tracing")
bool Hide_warnings = false;
:(before "End Setup")
//? cerr << "AAA setup\n"; //? 2
Hide_warnings = false;

:(before "End Types")
struct trace_line {
  int depth;  // optional field just to help browse traces later
  string label;
  string contents;
  trace_line(string l, string c) :depth(0), label(l), contents(c) {}
  trace_line(int d, string l, string c) :depth(d), label(l), contents(c) {}
};

:(before "End Tracing")
struct trace_stream {
  vector<trace_line> past_lines;
  // accumulator for current line
  ostringstream* curr_stream;
  string curr_layer;
  int curr_depth;
  string dump_layer;
  string collect_layer;  // if set, ignore all other layers
  ofstream null_stream;  // never opens a file, so writes silently fail
  trace_stream() :curr_stream(NULL), curr_depth(0) {}
  ~trace_stream() { if (curr_stream) delete curr_stream; }

  ostream& stream(string layer) {
    return stream(0, layer);
  }

  ostream& stream(int depth, string layer) {
    if (!collect_layer.empty() && layer != collect_layer) return null_stream;
    newline();
    curr_stream = new ostringstream;
    curr_layer = layer;
    curr_depth = depth;
    return *curr_stream;
  }

  // be sure to call this before messing with curr_stream or curr_layer
  void newline() {
    if (!curr_stream) return;
    string curr_contents = curr_stream->str();
    past_lines.push_back(trace_line(curr_depth, trim(curr_layer), curr_contents));  // preserve indent in contents
    if (curr_layer == dump_layer || curr_layer == "dump" || dump_layer == "all" ||
        (!Hide_warnings && curr_layer == "warn"))
//?     if (dump_layer == "all" && (Current_routine->id == 3 || curr_layer == "schedule")) //? 1
      cerr << curr_layer << ": " << curr_contents << '\n';
    delete curr_stream;
    curr_stream = NULL;
    curr_layer.clear();
    curr_depth = 0;
  }

  // Useful for debugging.
  string readable_contents(string layer) {  // missing layer = everything
    newline();
    ostringstream output;
    layer = trim(layer);
    for (vector<trace_line>::iterator p = past_lines.begin(); p != past_lines.end(); ++p)
      if (layer.empty() || layer == p->label) {
        if (p->depth)
          output << std::setw(4) << p->depth << ' ';
        output << p->label << ": " << p->contents << '\n';
      }
    return output.str();
  }
};



trace_stream* Trace_stream = NULL;

// Top-level helper. IMPORTANT: can't nest.
#define trace(...)  !Trace_stream ? cerr /*print nothing*/ : Trace_stream->stream(__VA_ARGS__)
// Warnings should go straight to cerr by default since calls to trace() have
// some unfriendly constraints (they delay printing, they can't nest)
#define raise  ((!Trace_stream || !Hide_warnings) ? (tb_shutdown(),cerr) /*do print*/ : Trace_stream->stream("warn"))

// A separate helper for debugging. We should only trace domain-specific
// facts. For everything else use log.
#define xlog if (false) log
// To turn on logging replace 'xlog' with 'log'.
#define log cerr

:(before "End Types")
// raise << die exits after printing -- unless Hide_warnings is set.
struct die {};
:(before "End Tracing")
ostream& operator<<(ostream& os, unused die) {
  if (Hide_warnings) return os;
  tb_shutdown();
  os << "dying";
  if (Trace_stream) Trace_stream->newline();
  exit(1);
}

#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

#define DUMP(layer)  if (Trace_stream) cerr << Trace_stream->readable_contents(layer);

// All scenarios save their traces in the repo, just like code. This gives
// future readers more meat when they try to make sense of a new project.
static string Trace_dir = ".traces/";
string Trace_file;

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
struct lease_tracer {
  lease_tracer() { Trace_stream = new trace_stream; }
  ~lease_tracer() {
//?     cerr << "write to file? " << Trace_file << "$\n"; //? 2
    if (!Trace_file.empty()) {
//?       cerr << "writing\n"; //? 2
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
//? Trace_stream->dump_layer = "all"; //? 1

#define CHECK_TRACE_CONTENTS(...)  check_trace_contents(__FUNCTION__, __FILE__, __LINE__, __VA_ARGS__)

:(before "End Tracing")
bool check_trace_contents(string FUNCTION, string FILE, int LINE, string expected) {  // missing layer == anywhere
  vector<string> expected_lines = split(expected, "");
  long long int curr_expected_line = 0;
  while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
    ++curr_expected_line;
  if (curr_expected_line == SIZE(expected_lines)) return true;
  Trace_stream->newline();
  string layer, contents;
  split_layer_contents(expected_lines.at(curr_expected_line), &layer, &contents);
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
//?     cerr << "AAA " << layer << ' ' << p->label << '\n'; //? 1
    if (layer != p->label)
      continue;

//?     cerr << "BBB ^" << contents << "$ ^" << p->contents << "$\n"; //? 1
    if (contents != trim(p->contents))
      continue;

//?     cerr << "CCC\n"; //? 1
    ++curr_expected_line;
    while (curr_expected_line < SIZE(expected_lines) && expected_lines.at(curr_expected_line).empty())
      ++curr_expected_line;
    if (curr_expected_line == SIZE(expected_lines)) return true;
    split_layer_contents(expected_lines.at(curr_expected_line), &layer, &contents);
  }

  ++Num_failures;
  cerr << "\nF - " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << contents << "] in trace:\n";
  DUMP(layer);
//?   exit(0); //? 1
  Passed = false;
  return false;
}

void split_layer_contents(const string& s, string* layer, string* contents) {
  static const string delim(": ");
  size_t pos = s.find(delim);
  if (pos == string::npos) {
    *layer = "";
    *contents = trim(s);
  }
  else {
    *layer = trim(s.substr(0, pos));
    *contents = trim(s.substr(pos+SIZE(delim)));
  }
}



int trace_count(string layer) {
  return trace_count(layer, "");
}

int trace_count(string layer, string line) {
  Trace_stream->newline();
  long result = 0;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (layer == p->label) {
//?       cerr << "a: " << line << "$\n"; //? 1
//?       cerr << "b: " << trim(p->contents) << "$\n"; //? 1
      if (line == "" || line == trim(p->contents))
        ++result;
    }
  }
  return result;
}

#define CHECK_TRACE_WARNS()  CHECK(trace_count("warn") > 0)
#define CHECK_TRACE_DOESNT_WARN() \
  if (trace_count("warn") > 0) { \
    ++Num_failures; \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): unexpected warnings\n"; \
    DUMP("warn"); \
    Passed = false; \
    return; \
  }

bool trace_doesnt_contain(string layer, string line) {
  return trace_count(layer, line) == 0;
}

bool trace_doesnt_contain(string expected) {
  vector<string> tmp = split(expected, ": ");
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
    begin = SIZE(end+delim);
    end = s.find(delim, begin);
  }
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

#include<iostream>
using std::istream;
using std::ostream;
using std::cin;
using std::cout;
using std::cerr;
#include<iomanip>

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
//: Mu 'applications' will be able to use depths 1-99 as they like.
//: Depth 100 will be for scheduling (more on that later).
const int Scheduling_depth = 100;
//: Primitive statements will occupy 101-9998
const int Initial_callstack_depth = 101;
const int Max_callstack_depth = 9998;
//: (ignore this until the call layer)
:(before "End Globals")
int Callstack_depth = 0;
:(before "End Setup")
Callstack_depth = 0;
//: Finally, details of primitive mu statements will occupy depth 9999 (more on that later as well)
:(before "End Globals")
const int Primitive_recipe_depth = 9999;
//:
//: This framework should help us hide some details at each level, mixing
//: static ideas like layers with the dynamic notion of call-stack depth.
