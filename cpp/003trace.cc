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
//: A final wrinkle is for recursive functions; it's often useful to segment
//: calls of different depth in the trace:
//:   +eval/1: => 34  # the topmost call to eval should have logged this line
//: (look at new_trace_frame below)
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
Hide_warnings = false;

:(before "End Tracing")
struct trace_stream {
  vector<pair<string, pair<int, string> > > past_lines;  // [(layer label, frame, line)]
  map<string, int> frame;
  // accumulator for current line
  ostringstream* curr_stream;
  string curr_layer;
  string dump_layer;
  trace_stream() :curr_stream(NULL) {}
  ~trace_stream() { if (curr_stream) delete curr_stream; }

  ostringstream& stream(string layer) {
    newline();
    curr_stream = new ostringstream;
    curr_layer = layer;
    return *curr_stream;
  }

  // be sure to call this before messing with curr_stream or curr_layer or frame
  void newline() {
    if (!curr_stream) return;
    string curr_contents = curr_stream->str();
    curr_contents.erase(curr_contents.find_last_not_of("\r\n")+1);
    past_lines.push_back(pair<string, pair<int, string> >(curr_layer, pair<int, string>(frame[curr_layer], curr_contents)));
    if (curr_layer == dump_layer || curr_layer == "dump" || dump_layer == "all" ||
        (!Hide_warnings && curr_layer == "warn"))
      cerr << curr_layer << '/' << frame[curr_layer] << ": " << curr_contents << '\n';
    delete curr_stream;
    curr_stream = NULL;
  }

  // Useful for debugging.
  string readable_contents(string layer) {  // missing layer = everything, frame, hierarchical layers
    newline();
    ostringstream output;
    string real_layer, frame;
    parse_layer_and_frame(layer, &real_layer, &frame);
    for (vector<pair<string, pair<int, string> > >::iterator p = past_lines.begin(); p != past_lines.end(); ++p)
      if (layer.empty() || prefix_match(real_layer, p->first))
        output << p->first << "/" << p->second.first << ": " << p->second.second << '\n';
    return output.str();
  }

  // Useful for a newcomer to visualize the program at work.
  void dump_browseable_contents(string layer) {
    ofstream dump("dump");
    dump << "<div class='frame' frame_index='1'>start</div>\n";
    for (vector<pair<string, pair<int, string> > >::iterator p = past_lines.begin(); p != past_lines.end(); ++p) {
      if (p->first != layer) continue;
      dump << "<div class='frame";
      if (p->second.first > 1) dump << " hidden";
      dump << "' frame_index='" << p->second.first << "'>";
      dump << p->second.second;
      dump << "</div>\n";
    }
    dump.close();
  }
};



trace_stream* Trace_stream = NULL;

// Top-level helper. IMPORTANT: can't nest.
#define trace(layer)  !Trace_stream ? cerr /*print nothing*/ : Trace_stream->stream(layer)
// Warnings should go straight to cerr by default since calls to trace() have
// some unfriendly constraints (they delay printing, they can't nest)
#define raise  ((!Trace_stream || !Hide_warnings) ? cerr /*do print*/ : Trace_stream->stream("warn"))

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
  os << "dying";
  if (Trace_stream) Trace_stream->newline();
  exit(1);
}

#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

#define DUMP(layer)  if (Trace_stream) cerr << Trace_stream->readable_contents(layer);

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
string Trace_file;
static string Trace_dir = ".traces/";
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

// To transparently save traces, start tests with the TEST() macro.
#define TEST(name) void test_##name() { Trace_file = #name;

#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;
:(before "End Test Setup")
START_TRACING_UNTIL_END_OF_SCOPE
//? Trace_stream->dump_layer = "all"; //? 1

:(before "End Tracing")
void trace_all(const string& label, const list<string>& in) {
  for (list<string>::const_iterator p = in.begin(); p != in.end(); ++p)
    trace(label) << *p;
}

bool check_trace_contents(string FUNCTION, string FILE, int LINE, string expected) {  // missing layer == anywhere, frame, hierarchical layers
  vector<string> expected_lines = split(expected, "");
  size_t curr_expected_line = 0;
  while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
    ++curr_expected_line;
  if (curr_expected_line == expected_lines.size()) return true;
  Trace_stream->newline();
  string layer, frame, contents;
  parse_layer_frame_contents(expected_lines[curr_expected_line], &layer, &frame, &contents);
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (!layer.empty() && !prefix_match(layer, p->first))
      continue;

    if (!frame.empty() && strtol(frame.c_str(), NULL, 0) != p->second.first)
      continue;

    if (contents != p->second.second)
      continue;

    ++curr_expected_line;
    while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
      ++curr_expected_line;
    if (curr_expected_line == expected_lines.size()) return true;
    parse_layer_frame_contents(expected_lines[curr_expected_line], &layer, &frame, &contents);
  }

  ++Num_failures;
  cerr << "\nF " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << contents << "] in trace:\n";
  DUMP(layer);
  Passed = false;
  return false;
}

void parse_layer_frame_contents(const string& orig, string* layer, string* frame, string* contents) {
  string layer_and_frame;
  parse_contents(orig, ": ", &layer_and_frame, contents);
  parse_layer_and_frame(layer_and_frame, layer, frame);
}

void parse_contents(const string& s, const string& delim, string* prefix, string* contents) {
  string::size_type pos = s.find(delim);
  if (pos == NOT_FOUND) {
    *prefix = "";
    *contents = s;
  }
  else {
    *prefix = s.substr(0, pos);
    *contents = s.substr(pos+delim.size());
  }
}

void parse_layer_and_frame(const string& orig, string* layer, string* frame) {
  size_t last_slash = orig.rfind('/');
  if (last_slash == NOT_FOUND
      || orig.find_last_not_of("0123456789") != last_slash) {
    *layer = orig;
    *frame = "";
  }
  else {
    *layer = orig.substr(0, last_slash);
    *frame = orig.substr(last_slash+1);
  }
}



bool check_trace_contents(string FUNCTION, string FILE, int LINE, string layer, string expected) {  // empty layer == everything, multiple layers, hierarchical layers
  vector<string> expected_lines = split(expected, "");
  size_t curr_expected_line = 0;
  while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
    ++curr_expected_line;
  if (curr_expected_line == expected_lines.size()) return true;
  Trace_stream->newline();
  vector<string> layers = split(layer, ",");
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (!layer.empty() && !any_prefix_match(layers, p->first))
      continue;
    if (p->second.second != expected_lines[curr_expected_line])
      continue;
    ++curr_expected_line;
    while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
      ++curr_expected_line;
    if (curr_expected_line == expected_lines.size()) return true;
  }

  ++Num_failures;
  cerr << "\nF " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << expected_lines[curr_expected_line] << "] in trace:\n";
  DUMP(layer);
  Passed = false;
  return false;
}

#define CHECK_TRACE_CONTENTS(...)  check_trace_contents(__FUNCTION__, __FILE__, __LINE__, __VA_ARGS__)

int trace_count(string layer) {
  return trace_count(layer, "");
}

int trace_count(string layer, string line) {
  Trace_stream->newline();
  long result = 0;
  vector<string> layers = split(layer, ",");
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (any_prefix_match(layers, p->first))
      if (line == "" || p->second.second == line)
        ++result;
  }
  return result;
}

int trace_count(string layer, int frame, string line) {
  Trace_stream->newline();
  long result = 0;
  vector<string> layers = split(layer, ",");
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (any_prefix_match(layers, p->first) && p->second.first == frame)
      if (line == "" || p->second.second == line)
        ++result;
  }
  return result;
}

#define CHECK_TRACE_WARNS()  CHECK(trace_count("warn") > 0)
#define CHECK_TRACE_DOESNT_WARN() \
  if (trace_count("warn") > 0) { \
    ++Num_failures; \
    cerr << "\nF " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): unexpected warnings\n"; \
    DUMP("warn"); \
    Passed = false; \
    return; \
  }

bool trace_doesnt_contain(string layer, string line) {
  return trace_count(layer, line) == 0;
}

bool trace_doesnt_contain(string expected) {
  vector<string> tmp = split(expected, ": ");
  return trace_doesnt_contain(tmp[0], tmp[1]);
}

bool trace_doesnt_contain(string layer, int frame, string line) {
  return trace_count(layer, frame, line) == 0;
}

#define CHECK_TRACE_DOESNT_CONTAIN(...)  CHECK(trace_doesnt_contain(__VA_ARGS__))



// manage layer counts in Trace_stream using RAII
struct lease_trace_frame {
  string layer;
  lease_trace_frame(string l) :layer(l) {
    if (!Trace_stream) return;
    Trace_stream->newline();
    ++Trace_stream->frame[layer];
  }
  ~lease_trace_frame() {
    if (!Trace_stream) return;
    Trace_stream->newline();
    --Trace_stream->frame[layer];
  }
};
#define new_trace_frame(layer)  lease_trace_frame leased_frame(layer);

bool check_trace_contents(string FUNCTION, string FILE, int LINE, string layer, int frame, string expected) {  // multiple layers, hierarchical layers
  vector<string> expected_lines = split(expected, "");  // hack: doesn't handle newlines in embedded in lines
  size_t curr_expected_line = 0;
  while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
    ++curr_expected_line;
  if (curr_expected_line == expected_lines.size()) return true;
  Trace_stream->newline();
  vector<string> layers = split(layer, ",");
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (!layer.empty() && !any_prefix_match(layers, p->first))
      continue;
    if (p->second.first != frame)
      continue;
    if (p->second.second != expected_lines[curr_expected_line])
      continue;
    ++curr_expected_line;
    while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
      ++curr_expected_line;
    if (curr_expected_line == expected_lines.size()) return true;
  }

  ++Num_failures;
  cerr << "\nF " << FUNCTION << "(" << FILE << ":" << LINE << "): missing [" << expected_lines[curr_expected_line] << "] in trace/" << frame << ":\n";
  DUMP(layer);
  Passed = false;
  return false;
}

#define CHECK_TRACE_TOP(layer, expected)  CHECK_TRACE_CONTENTS(layer, 1, expected)



vector<string> split(string s, string delim) {
  vector<string> result;
  string::size_type begin=0, end=s.find(delim);
  while (true) {
    if (end == NOT_FOUND) {
      result.push_back(string(s, begin, NOT_FOUND));
      break;
    }
    result.push_back(string(s, begin, end-begin));
    begin = end+delim.size();
    end = s.find(delim, begin);
  }
  return result;
}

bool any_prefix_match(const vector<string>& pats, const string& needle) {
  if (pats.empty()) return false;
  if (*pats[0].rbegin() != '/')
    // prefix match not requested
    return find(pats.begin(), pats.end(), needle) != pats.end();
  // first pat ends in a '/'; assume all pats do.
  for (vector<string>::const_iterator p = pats.begin(); p != pats.end(); ++p)
    if (headmatch(needle, *p)) return true;
  return false;
}

bool prefix_match(const string& pat, const string& needle) {
  if (*pat.rbegin() != '/')
    // prefix match not requested
    return pat == needle;
  return headmatch(needle, pat);
}

bool headmatch(const string& s, const string& pat) {
  if (pat.size() > s.size()) return false;
  return std::mismatch(pat.begin(), pat.end(), s.begin()).first == pat.end();
}

:(before "End Includes")
#include<vector>
using std::vector;
#include<list>
using std::list;
#include<utility>
using std::pair;
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

#include<sstream>
using std::istringstream;
using std::ostringstream;

#include<fstream>
using std::ifstream;
using std::ofstream;

#define unused  __attribute__((unused))
