bool Hide_warnings = false;

struct trace_stream {
  vector<pair<string, pair<int, string> > > past_lines;  // [(layer label, frame, line)]
  unordered_map<string, int> frame;
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
    past_lines.push_back(pair<string, pair<int, string> >(curr_layer, pair<int, string>(frame[curr_layer], curr_stream->str())));
    if (curr_layer == "dump")
      cerr << with_newline(curr_stream->str());
    else if ((!dump_layer.empty() && prefix_match(dump_layer, curr_layer))
        || (!Hide_warnings && curr_layer == "warn"))
      cerr << curr_layer << "/" << frame[curr_layer] << ": " << with_newline(curr_stream->str());
    delete curr_stream;
    curr_stream = NULL;
  }

  string readable_contents(string layer) {  // missing layer = everything, frame, hierarchical layers
    newline();
    ostringstream output;
    string real_layer, frame;
    parse_layer_and_frame(layer, &real_layer, &frame);
    for (vector<pair<string, pair<int, string> > >::iterator p = past_lines.begin(); p != past_lines.end(); ++p)
      if (layer.empty() || prefix_match(real_layer, p->first))
        output << p->first << "/" << p->second.first << ": " << with_newline(p->second.second);
    return output.str();
  }

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
#define raise ((!Trace_stream || !Hide_warnings) ? cerr /*do print*/ : Trace_stream->stream("warn")) << __FILE__ << ":" << __LINE__ << " "
// Just debug logging without any test support.
#define dbg cerr << __FUNCTION__ << '(' << __FILE__ << ':' << __LINE__ << ") "

// raise << die exits after printing -- unless Hide_warnings is set.
struct die {};
ostream& operator<<(ostream& os, unused die) {
  if (Hide_warnings) return os;
  os << "dying";
  exit(1);
}

#define CLEAR_TRACE  delete Trace_stream, Trace_stream = new trace_stream;

#define DUMP(layer)  cerr << Trace_stream->readable_contents(layer)

// Trace_stream is a resource, lease_tracer uses RAII to manage it.
string Trace_file;
static string Trace_dir = ".traces/";
struct lease_tracer {
  lease_tracer() { Trace_stream = new trace_stream; }
  ~lease_tracer() {
//?     cerr << "write to file? " << Trace_file << "$\n"; //? 1
    if (!Trace_file.empty()) {
//?       cerr << "writing\n"; //? 1
      ofstream fout((Trace_dir+Trace_file).c_str());
      fout << Trace_stream->readable_contents("");
      fout.close();
    }
    delete Trace_stream, Trace_stream = NULL; Trace_file = ""; }
};

#define START_TRACING_UNTIL_END_OF_SCOPE  lease_tracer leased_tracer;

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
  ostringstream output;
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
      || last_slash == orig.size()-1  // trailing slash indicates hierarchical layer
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
//?   cout << "aa check2 " << layer << ": " << expected_lines.size() << '\n'; //? 1
  size_t curr_expected_line = 0;
  while (curr_expected_line < expected_lines.size() && expected_lines[curr_expected_line].empty())
    ++curr_expected_line;
  if (curr_expected_line == expected_lines.size()) return true;
  Trace_stream->newline();
  ostringstream output;
  vector<string> layers = split(layer, ",");
  for (vector<pair<string, pair<int, string> > >::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (!layer.empty() && !any_prefix_match(layers, p->first))
      continue;
//?     cout << "comparing " << p->second.second << '\n'; //? 1
//?     cout << "     with " << expected_lines[curr_expected_line] << '\n'; //? 1
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
  ostringstream output;
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
