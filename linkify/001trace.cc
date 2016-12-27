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

bool check_trace_contents(string FUNCTION, string FILE, int LINE, string layer, string expected) {  // empty layer == everything
  vector<string> expected_lines = split(expected, "");
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
