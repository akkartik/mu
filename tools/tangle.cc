// Reorder a file based on directives starting with ':(' (tangle directives).
// Insert #line directives to preserve line numbers in the original.
// Clear lines starting with '//:' (tangle comments).

#include<assert.h>
#include<cstdlib>
#include<cstring>

#include<vector>
using std::vector;
#include<list>
using std::list;
#include<utility>
using std::pair;

#include<string>
using std::string;

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

#include <locale>
using std::isspace;  // unicode-aware

//// Core data structures

struct Line {
  string filename;
  size_t line_number;
  string contents;
  Line() :line_number(0) {}
  Line(const string& text) :line_number(0) {
    contents = text;
  }
  Line(const string& text, const string& f, const size_t& l) {
    contents = text;
    filename = f;
    line_number = l;
  }
  Line(const string& text, const Line& origin) {
    contents = text;
    filename = origin.filename;
    line_number = origin.line_number;
  }
};

// Emit a list of line contents, inserting directives just at discontinuities.
// Needs to be a macro because 'out' can have the side effect of creating a
// new trace in Trace_stream.
#define EMIT(lines, out) if (!lines.empty()) { \
  string last_file = lines.begin()->filename; \
  size_t last_line = lines.begin()->line_number-1; \
  out << line_directive(lines.begin()->line_number, lines.begin()->filename) << '\n'; \
  for (list<Line>::const_iterator p = lines.begin(); p != lines.end(); ++p) { \
    if (last_file != p->filename || last_line != p->line_number-1) \
      out << line_directive(p->line_number, p->filename) << '\n'; \
    out << p->contents << '\n'; \
    last_file = p->filename; \
    last_line = p->line_number; \
  } \
}

//// Traces and white-box tests

bool Passed = true;

long Num_failures = 0;

#define CHECK(X) \
  if (!(X)) { \
    ++Num_failures; \
    cerr << "\nF " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << '\n'; \
    Passed = false; \
    return; \
  }

#define CHECK_EQ(X, Y) \
  if ((X) != (Y)) { \
    ++Num_failures; \
    cerr << "\nF " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << " == " << #Y << '\n'; \
    cerr << "  got " << (X) << '\n';  /* BEWARE: multiple eval */ \
    Passed = false; \
    return; \
  }

bool Hide_warnings = false;

struct trace_stream {
  vector<pair<string, string> > past_lines;  // [(layer label, line)]
  // accumulator for current line
  ostringstream* curr_stream;
  string curr_layer;
  trace_stream() :curr_stream(NULL) {}
  ~trace_stream() { if (curr_stream) delete curr_stream; }

  ostringstream& stream(string layer) {
    newline();
    curr_stream = new ostringstream;
    curr_layer = layer;
    return *curr_stream;
  }

  // be sure to call this before messing with curr_stream or curr_layer
  void newline() {
    if (!curr_stream) return;
    string curr_contents = curr_stream->str();
    curr_contents.erase(curr_contents.find_last_not_of("\r\n")+1);
    past_lines.push_back(pair<string, string>(curr_layer, curr_contents));
    delete curr_stream;
    curr_stream = NULL;
  }

  string readable_contents(string layer) {  // missing layer = everything
    newline();
    ostringstream output;
    for (vector<pair<string, string> >::iterator p = past_lines.begin(); p != past_lines.end(); ++p)
      if (layer.empty() || layer == p->first)
        output << p->first << ": " << with_newline(p->second);
    return output.str();
  }

  string with_newline(string s) {
    if (s[s.size()-1] != '\n') return s+'\n';
    return s;
  }
};

trace_stream* Trace_stream = NULL;

// Top-level helper. IMPORTANT: can't nest.
#define trace(layer)  !Trace_stream ? cerr /*print nothing*/ : Trace_stream->stream(layer)
// Warnings should go straight to cerr by default since calls to trace() have
// some unfriendly constraints (they delay printing, they can't nest)
#define raise  ((!Trace_stream || !Hide_warnings) ? cerr /*do print*/ : Trace_stream->stream("warn")) << __FILE__ << ":" << __LINE__ << " "

// raise << die exits after printing -- unless Hide_warnings is set.
struct die {};
ostream& operator<<(ostream& os, __attribute__((unused)) die) {
  if (Hide_warnings) return os;
  os << "dying\n";
  exit(1);
}

#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

#define DUMP(layer)  cerr << Trace_stream->readable_contents(layer)

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
struct lease_tracer {
  lease_tracer() { Trace_stream = new trace_stream; }
  ~lease_tracer() { delete Trace_stream, Trace_stream = NULL; }
};

#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;

vector<string> split(string s, string delim) {
  vector<string> result;
  string::size_type begin=0, end=s.find(delim);
  while (true) {
    if (end == string::npos) {
      result.push_back(string(s, begin, string::npos));
      break;
    }
    result.push_back(string(s, begin, end-begin));
    begin = end+delim.size();
    end = s.find(delim, begin);
  }
  return result;
}

bool check_trace_contents(string FUNCTION, string FILE, int LINE, string layer, string expected) {  // empty layer == everything
  vector<string> expected_lines = split(expected, "\n");
  size_t curr_expected_line = 0;
  while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
    ++curr_expected_line;
  if (curr_expected_line == expected_lines.size()) return true;
  Trace_stream->newline();
  ostringstream output;
  for (vector<pair<string, string> >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (!layer.empty() && layer != p->first)
      continue;
    if (p->second != expected_lines[curr_expected_line])
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

int trace_count(string layer, string line) {
  Trace_stream->newline();
  long result = 0;
  for (vector<pair<string, string> >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (layer == p->first)
      if (line == "" || p->second == line)
        ++result;
  }
  return result;
}

#define CHECK_TRACE_WARNS()  CHECK(trace_count("warn", "") > 0)
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

#define CHECK_TRACE_DOESNT_CONTAIN(...)  CHECK(trace_doesnt_contain(__VA_ARGS__))

// Tests for trace infrastructure

void test_trace_check_compares() {
  CHECK_TRACE_CONTENTS("test layer", "");
  trace("test layer") << "foo";
  CHECK_TRACE_CONTENTS("test layer", "foo");
}

void test_trace_check_filters_layers() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  CHECK_TRACE_CONTENTS("test layer 1", "foo");
}

void test_trace_check_ignores_other_lines() {
  trace("test layer 1") << "foo";
  trace("test layer 1") << "bar";
  CHECK_TRACE_CONTENTS("test layer 1", "foo");
}

void test_trace_check_always_finds_empty_lines() {
  CHECK_TRACE_CONTENTS("test layer 1", "");
}

void test_trace_check_treats_empty_layers_as_wildcards() {
  trace("test layer 1") << "foo";
  CHECK_TRACE_CONTENTS("", "foo");
}

void test_trace_check_multiple_lines_at_once() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  CHECK_TRACE_CONTENTS("", "foo\n"
                           "bar\n");
}

void test_trace_check_always_finds_empty_lines2() {
  CHECK_TRACE_CONTENTS("test layer 1", "\n\n\n");
}

void test_trace_orders_across_layers() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  trace("test layer 1") << "qux";
  CHECK_TRACE_CONTENTS("", "foo\n"
                           "bar\n"
                           "qux\n");
}

void test_trace_supports_count() {
  trace("test layer 1") << "foo";
  trace("test layer 1") << "foo";
  CHECK_EQ(trace_count("test layer 1", "foo"), 2);
}

//// helpers

// can't check trace because trace methods call 'split'

void test_split_returns_at_least_one_elem() {
  vector<string> result = split("", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result[0], "");
}

void test_split_returns_entire_input_when_no_delim() {
  vector<string> result = split("abc", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result[0], "abc");
}

void test_split_works() {
  vector<string> result = split("abc,def", ",");
  CHECK_EQ(result.size(), 2);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
}

void test_split_works2() {
  vector<string> result = split("abc,def,ghi", ",");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
  CHECK_EQ(result[2], "ghi");
}

void test_split_handles_multichar_delim() {
  vector<string> result = split("abc,,def,,ghi", ",,");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
  CHECK_EQ(result[2], "ghi");
}

//// Core program

#include "tangle.function_list"

string line_directive(size_t line_number, string filename) {
  ostringstream result;
  if (filename.empty())
    result << "#line " << line_number;
  else
    result << "#line " << line_number << " \"" << filename << '"';
  return result.str();
}

string Toplevel = "run";

int main(int argc, const char* argv[]) {
  if (flag("test", argc, argv))
    return run_tests();
  return tangle(argc, argv);
}

bool flag(const string& flag, int argc, const char* argv[]) {
  for (int i = 1; i < argc; ++i)
    if (string(argv[i]) == flag)
      return true;
  return false;
}

void setup() {
  Hide_warnings = false;
  Passed = true;
}

void verify() {
  Hide_warnings = false;
  if (!Passed)
    ;
  else
    cerr << ".";
}

int tangle(int argc, const char* argv[]) {
  list<Line> result;
  for (int i = 1; i < argc; ++i) {
//?     cerr << "new file " << argv[i] << '\n';
    Toplevel = "run";
    ifstream in(argv[i]);
    tangle(in, argv[i], result);
  }

  EMIT(result, cout);
  return 0;
}

void tangle(istream& in, const string& filename, list<Line>& out) {
  string curr_line;
  size_t line_number = 1;
  while (!in.eof()) {
    getline(in, curr_line);
    if (starts_with(curr_line, ":(")) {
      ++line_number;
      process_next_hunk(in, trim(curr_line), filename, line_number, out);
      continue;
    }
    if (starts_with(curr_line, "//:")) {
      ++line_number;
      continue;
    }
    out.push_back(Line(curr_line, filename, line_number));
    ++line_number;
  }

  // Trace all line contents, inserting directives just at discontinuities.
  if (!Trace_stream) return;
  EMIT(out, Trace_stream->stream("tangle"));
}

// just for tests
void tangle(istream& in, list<Line>& out) {
  tangle(in, "", out);
}

void process_next_hunk(istream& in, const string& directive, const string& filename, size_t& line_number, list<Line>& out) {
  istringstream directive_stream(directive.substr(2));  // length of ":("
  string cmd = next_tangle_token(directive_stream);

  // first slurp all lines until next directive
  list<Line> hunk;
  {
    string curr_line;
    while (!in.eof()) {
      std::streampos old = in.tellg();
      getline(in, curr_line);
      if (starts_with(curr_line, ":(")) {
        in.seekg(old);
        break;
      }
      if (starts_with(curr_line, "//:")) {
        // tangle comments
        ++line_number;
        continue;
      }
      hunk.push_back(Line(curr_line, filename, line_number));
      ++line_number;
    }
  }

  if (cmd == "code") {
    out.insert(out.end(), hunk.begin(), hunk.end());
    return;
  }

  if (cmd == "before" || cmd == "after" || cmd == "replace" || cmd == "replace{}" || cmd == "delete" || cmd == "delete{}") {
    list<Line>::iterator target = locate_target(out, directive_stream);
    if (target == out.end()) {
      raise << "couldn't find target " << directive << '\n' << die();
      return;
    }

    indent_all(hunk, target);

    if (cmd == "before") {
      out.splice(target, hunk);
    }
    else if (cmd == "after") {
      ++target;
      out.splice(target, hunk);
    }
    else if (cmd == "replace" || cmd == "delete") {
      out.splice(target, hunk);
      out.erase(target);
    }
    else if (cmd == "replace{}" || cmd == "delete{}") {
      if (find_trim(hunk, ":OLD_CONTENTS") == hunk.end()) {
        out.splice(target, hunk);
        out.erase(target, balancing_curly(target));
      }
      else {
        list<Line>::iterator next = balancing_curly(target);
        list<Line> old_version;
        old_version.splice(old_version.begin(), out, target, next);
        old_version.pop_back();  old_version.pop_front();  // contents only please, not surrounding curlies

        list<Line>::iterator new_pos = find_trim(hunk, ":OLD_CONTENTS");
        indent_all(old_version, new_pos);
        hunk.splice(new_pos, old_version);
        hunk.erase(new_pos);
        out.splice(next, hunk);
      }
    }
    return;
  }

  raise << "unknown directive " << cmd << '\n' << die();
}

list<Line>::iterator locate_target(list<Line>& out, istream& directive_stream) {
  string pat = next_tangle_token(directive_stream);
  if (pat == "") return out.end();

  string next_token = next_tangle_token(directive_stream);
  if (next_token == "") {
    return find_substr(out, pat);
  }
  // first way to do nested pattern: pattern 'following' intermediate
  else if (next_token == "following") {
    string pat2 = next_tangle_token(directive_stream);
    if (pat2 == "") return out.end();
    list<Line>::iterator intermediate = find_substr(out, pat2);
    if (intermediate == out.end()) return out.end();
    return find_substr(out, intermediate, pat);
  }
  // second way to do nested pattern: intermediate 'then' pattern
  else if (next_token == "then") {
    list<Line>::iterator intermediate = find_substr(out, pat);
    if (intermediate == out.end()) return out.end();
    string pat2 = next_tangle_token(directive_stream);
    if (pat2 == "") return out.end();
    return find_substr(out, intermediate, pat2);
  }
  raise << "unknown keyword in directive: " << next_token << '\n';
  return out.end();
}

// indent all lines in l like indentation at exemplar
void indent_all(list<Line>& l, list<Line>::iterator exemplar) {
  string curr_indent = indent(exemplar->contents);
  for (list<Line>::iterator p = l.begin(); p != l.end(); ++p)
    if (!p->contents.empty())
      p->contents.insert(p->contents.begin(), curr_indent.begin(), curr_indent.end());
}

string next_tangle_token(istream& in) {
  in >> std::noskipws;
  ostringstream out;
  skip_whitespace(in);
  if (in.peek() == '"')
    slurp_tangle_string(in, out);
  else
    slurp_word(in, out);
  return out.str();
}

void slurp_tangle_string(istream& in, ostream& out) {
  in.get();
  char c;
  while (in >> c) {
    if (c == '\\') {
      // skip backslash and save next character unconditionally
      in >> c;
      out << c;
      continue;
    }
    if (c == '"') break;
    out << c;
  }
}

void slurp_word(istream& in, ostream& out) {
  char c;
  while (in >> c) {
    if (isspace(c) || c == ')') {
      in.putback(c);
      break;
    }
    out << c;
  }
}

void skip_whitespace(istream& in) {
  while (isspace(in.peek()))
    in.get();
}

list<Line>::iterator balancing_curly(list<Line>::iterator curr) {
  long open_curlies = 0;
  do {
    for (string::iterator p = curr->contents.begin(); p != curr->contents.end(); ++p) {
      if (*p == '{') ++open_curlies;
      if (*p == '}') --open_curlies;
    }
    ++curr;
    // no guard so far against unbalanced curly, including inside comments or strings
  } while (open_curlies != 0);
  return curr;
}

list<Line>::iterator find_substr(list<Line>& in, const string& pat) {
  for (list<Line>::iterator p = in.begin(); p != in.end(); ++p)
    if (p->contents.find(pat) != string::npos)
      return p;
  return in.end();
}

list<Line>::iterator find_substr(list<Line>& in, list<Line>::iterator p, const string& pat) {
  for (; p != in.end(); ++p)
    if (p->contents.find(pat) != string::npos)
      return p;
  return in.end();
}

list<Line>::iterator find_trim(list<Line>& in, const string& pat) {
  for (list<Line>::iterator p = in.begin(); p != in.end(); ++p)
    if (trim(p->contents) == pat)
      return p;
  return in.end();
}

string escape(string s) {
  s = replace_all(s, "\\", "\\\\");
  s = replace_all(s, "\"", "\\\"");
  s = replace_all(s, "", "\\n");
  return s;
}

string replace_all(string s, const string& a, const string& b) {
  for (size_t pos = s.find(a); pos != string::npos; pos = s.find(a, pos+b.size()))
    s = s.replace(pos, a.size(), b);
  return s;
}

// does s start with pat, after skipping whitespace?
// pat can't start with whitespace
bool starts_with(const string& s, const string& pat) {
  for (size_t pos = 0; pos < s.size(); ++pos)
    if (!isspace(s.at(pos)))
      return s.compare(pos, pat.size(), pat) == 0;
  return false;
}

string indent(const string& s) {
  for (size_t pos = 0; pos < s.size(); ++pos)
    if (!isspace(s.at(pos)))
      return s.substr(0, pos);
  return "";
}

string strip_indent(const string& s, size_t n) {
  if (s.empty()) return "";
  string::const_iterator curr = s.begin();
  while (curr != s.end() && n > 0 && isspace(*curr)) {
    ++curr;
    --n;
  }
  return string(curr, s.end());
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

const Line& front(const list<Line>& l) {
  assert(!l.empty());
  return l.front();
}

//// Tests for tangle

void test_tangle() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_with_linenumber() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "#line 1\n"
                                 "a\n"
                                 "#line 5\n"
                                 "d\n"
                                 "#line 2\n"
                                 "b\n"
                                 "c\n");
  // no other #line directives
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "#line 3");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "#line 4");
}

void test_tangle_linenumbers_with_filename() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, "foo", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 5 \"foo\"\n"
                                 "d\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_line_numbers_with_multiple_filenames() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(before b)\n"
                    "d\n");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 2 \"foo\"\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_linenumbers_with_multiple_directives() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(before b)\n"
                    "d\n"
                    ":(before c)\n"
                    "e");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 2 \"foo\"\n"
                                 "b\n"
                                 "#line 4 \"bar\"\n"
                                 "e\n"
                                 "#line 3 \"foo\"\n"
                                 "c\n");
}

void test_tangle_with_multiple_filenames_after() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(after b)\n"
                    "d\n");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 3 \"foo\"\n"
                                 "c\n");
}

void test_tangle_skip_tanglecomments() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   "//: 1\n"
                   "//: 2\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "c\n"
                                 "\n"
                                 "\n"
                                 "d\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_tanglecomments_and_directive() {
  istringstream in("a\n"
                   "//: 1\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n"
                   ":(code)\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 6\n"
                                 "d\n"
                                 "#line 3\n"
                                 "b\n"
                                 "c\n"
                                 "#line 8\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_tanglecomments_inside_directive() {
  istringstream in("a\n"
                   "//: 1\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "//: abc\n"
                   "d\n"
                   ":(code)\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 7\n"
                                 "d\n"
                                 "#line 3\n"
                                 "b\n"
                                 "c\n"
                                 "#line 9\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_multiword_directives() {
  istringstream in("a b\n"
                   "c\n"
                   ":(after \"a b\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a b\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle_with_quoted_multiword_directives() {
  istringstream in("a \"b\"\n"
                   "c\n"
                   ":(after \"a \\\"b\\\"\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a \"b\"\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle2() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle_at_end() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after c)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "c\n"
                                 "d\n");
}

void test_tangle_indents_hunks_correctly() {
  istringstream in("a\n"
                   "  b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "  b\n"
                                 "  d\n"
                                 "c\n");
}

void test_tangle_warns_on_missing_target() {
  Hide_warnings = true;
  istringstream in(":(before)\n"
                   "abc def\n");
  list<Line> lines;
  tangle(in, lines);
  CHECK_TRACE_WARNS();
}

void test_tangle_warns_on_unknown_target() {
  Hide_warnings = true;
  istringstream in(":(before \"foo\")\n"
                   "abc def\n");
  list<Line> lines;
  tangle(in, lines);
  CHECK_TRACE_WARNS();
}

void test_tangle_delete_range_of_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(delete{} \"b\")\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "c");
}

void test_tangle_replace() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(replace b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "c\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b");
}

void test_tangle_replace_range_of_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(replace{} \"b\")\n"
                   "d\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b {");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "c");
}

void test_tangle_replace_tracks_old_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(replace{} \"b\")\n"
                   "d\n"
                   ":OLD_CONTENTS\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "c\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b {");
}

void test_tangle_nested_patterns() {
  istringstream in("a\n"
                   "c\n"
                   "b\n"
                   "c\n"
                   "d\n"
                   ":(after \"b\" then \"c\")\n"
                   "e");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "c\n"
                                 "b\n"
                                 "c\n"
                                 "e\n"
                                 "d\n");
}

void test_tangle_nested_patterns2() {
  istringstream in("a\n"
                   "c\n"
                   "b\n"
                   "c\n"
                   "d\n"
                   ":(after \"c\" following \"b\")\n"
                   "e");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "c\n"
                                 "b\n"
                                 "c\n"
                                 "e\n"
                                 "d\n");
}

// todo: include line numbers in tangle errors

void test_trim() {
  CHECK_EQ(trim(""), "");
  CHECK_EQ(trim(" "), "");
  CHECK_EQ(trim("  "), "");
  CHECK_EQ(trim("a"), "a");
  CHECK_EQ(trim(" a"), "a");
  CHECK_EQ(trim("  a"), "a");
  CHECK_EQ(trim("  ab"), "ab");
  CHECK_EQ(trim("a "), "a");
  CHECK_EQ(trim("a  "), "a");
  CHECK_EQ(trim("ab  "), "ab");
  CHECK_EQ(trim(" a "), "a");
  CHECK_EQ(trim("  a  "), "a");
  CHECK_EQ(trim("  ab  "), "ab");
}

void test_strip_indent() {
  CHECK_EQ(strip_indent("", 0), "");
  CHECK_EQ(strip_indent("", 1), "");
  CHECK_EQ(strip_indent("", 3), "");
  CHECK_EQ(strip_indent(" ", 0), " ");
  CHECK_EQ(strip_indent(" a", 0), " a");
  CHECK_EQ(strip_indent(" ", 1), "");
  CHECK_EQ(strip_indent(" a", 1), "a");
  CHECK_EQ(strip_indent(" ", 2), "");
  CHECK_EQ(strip_indent(" a", 2), "a");
  CHECK_EQ(strip_indent("  ", 0), "  ");
  CHECK_EQ(strip_indent("  a", 0), "  a");
  CHECK_EQ(strip_indent("  ", 1), " ");
  CHECK_EQ(strip_indent("  a", 1), " a");
  CHECK_EQ(strip_indent("  ", 2), "");
  CHECK_EQ(strip_indent("  a", 2), "a");
  CHECK_EQ(strip_indent("  ", 3), "");
  CHECK_EQ(strip_indent("  a", 3), "a");
}

//// Test harness

typedef void (*test_fn)(void);

const test_fn Tests[] = {
  #include "tangle.test_list"  // auto-generated; see 'build*' scripts
};

// Names for each element of the 'Tests' global, respectively.
const string Test_names[] = {
  #include "tangle.test_name_list"  // auto-generated; see 'build*' scripts
};

int run_tests() {
  for (unsigned long i=0; i < sizeof(Tests)/sizeof(Tests[0]); ++i) {
//?     cerr << "running " << Test_names[i] << '\n';
    START_TRACING_UNTIL_END_OF_SCOPE;
    setup();
    (*Tests[i])();
    verify();
  }

  cerr << '\n';
  if (Num_failures > 0)
    cerr << Num_failures << " failure"
         << (Num_failures > 1 ? "s" : "")
         << '\n';
  return Num_failures;
}
