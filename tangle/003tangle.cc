// Reorder a file based on directives starting with ':(' (tangle directives).
// Insert #line directives to preserve line numbers in the original.
// Clear lines starting with '//:' (tangle comments).

//// Preliminaries regarding line number management

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

string line_directive(size_t line_number, string filename) {
  ostringstream result;
  if (filename.empty())
    result << "#line " << line_number;
  else
    result << "#line " << line_number << " \"" << filename << '"';
  return result.str();
}

//// Tangle

string Toplevel = "run";

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
  bool end_of_scenario_input = false;
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
      if (cmd == "scenario") {
        // ignore mu comments in scenarios, but only after the end of input
        if (!starts_with(curr_line, "#") && !is_input(curr_line)) {
          // remaining lines are checks
          end_of_scenario_input = true;
        }
        else if (end_of_scenario_input && starts_with(curr_line, "#")) {
          ++line_number;
          continue;
        }
        if (trim(curr_line).empty()) {
          // ignore empty lines in scenarios, whether in input of after
          ++line_number;
          continue;
        }
      }
      hunk.push_back(Line(curr_line, filename, line_number));
      ++line_number;
    }
  }

  if (cmd == "code") {
    out.insert(out.end(), hunk.begin(), hunk.end());
    return;
  }

  if (cmd == "scenarios") {
    Toplevel = next_tangle_token(directive_stream);
    return;
  }

  if (cmd == "scenario") {
    list<Line> result;
    string name = next_tangle_token(directive_stream);
    emit_test(name, hunk, result);
//?     cerr << out.size() << " " << result.size() << '\n';
    out.insert(out.end(), result.begin(), result.end());
//?     cerr << out.size() << " " << result.size() << '\n';
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

// A scenario is one or more sessions separated by calls to CLEAR_TRACE ('===')
//   A session is:
//     one or more lines of escaped setup in C/C++ ('%')
//   followed by one or more lines of input,
//   followed optionally by (in order):
//     one or more lines expected in trace in order ('+')
//     one or more lines trace shouldn't include ('-')
//     one or more lines expressing counts of specific layers emitted in trace ('$')
//     a directive to print the trace just for debugging ('?')
// Remember to update is_input below if you add to this format.
void emit_test(const string& name, list<Line>& lines, list<Line>& result) {
  result.push_back(Line("void test_"+name+"() {", front(lines).filename, front(lines).line_number-1));  // use line number of directive
//?   result.push_back("cerr << \""+name+"\\n\";");  // debug: uncomment this to print scenario names as you run them
  while (!lines.empty()) {
    while (!lines.empty() && starts_with(front(lines).contents, "% ")) {
      result.push_back(Line("  "+front(lines).contents.substr(strlen("% ")), front(lines)));
      lines.pop_front();
    }
    if (lines.empty()) break;
    result.push_back(input_lines(lines));
    if (!lines.empty() && !front(lines).contents.empty() && front(lines).contents.at(0) == '+')
      result.push_back(expected_in_trace(lines));
    while (!lines.empty() && !front(lines).contents.empty() && front(lines).contents.at(0) == '-') {
      result.push_back(expected_not_in_trace(front(lines)));
      lines.pop_front();
    }
    if (!lines.empty() && front(lines).contents.at(0) == '$') {
      const string& in = front(lines).contents;
      size_t pos = in.find(": ");
      string layer = in.substr(1, pos-1);
      string count = in.substr(pos+2);
      result.push_back(Line("  CHECK_TRACE_COUNT(\""+layer+"\", "+count+");", front(lines)));
      lines.pop_front();
    }
    if (!lines.empty() && front(lines).contents == "===") {
      result.push_back(Line("  CLEAR_TRACE;", front(lines)));
      lines.pop_front();
    }
    if (!lines.empty() && front(lines).contents == "?") {
      result.push_back(Line("  DUMP(\"\");", front(lines)));
      lines.pop_front();
    }
  }
  result.push_back(Line("}"));
}

bool is_input(const string& line) {
  if (line.empty()) return true;
  return line != "===" && line.find_first_of("+-$?%") != 0;
}

Line input_lines(list<Line>& hunk) {
  assert(!hunk.empty());
  Line result;
  result.line_number = hunk.front().line_number;
  result.filename = hunk.front().filename;
  while (!hunk.empty() && is_input(hunk.front().contents)) {
    result.contents += hunk.front().contents+"";  // temporary delimiter; replace with escaped newline after escaping other backslashes
    hunk.pop_front();
  }
  result.contents = "  "+Toplevel+"(\""+escape(result.contents)+"\");";
  return result;
}

Line expected_in_trace(list<Line>& hunk) {
  Line result;
  result.line_number = hunk.front().line_number;
  result.filename = hunk.front().filename;
  while (!hunk.empty() && !front(hunk).contents.empty() && front(hunk).contents.at(0) == '+') {
    hunk.front().contents.erase(0, 1);
    result.contents += hunk.front().contents+"";
    hunk.pop_front();
  }
  result.contents = "  CHECK_TRACE_CONTENTS(\""+escape(result.contents)+"\");";
  return result;
}

Line expected_not_in_trace(const Line& line) {
  Line result;
  result.line_number = line.line_number;
  result.filename = line.filename;
  result.contents = "  CHECK_TRACE_DOESNT_CONTAIN(\""+escape(line.contents.substr(1))+"\");";
  return result;
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

bool any_line_starts_with(const list<Line>& lines, const string& pat) {
  for (list<Line>::const_iterator p = lines.begin(); p != lines.end(); ++p)
    if (starts_with(p->contents, pat)) return true;
  return false;
}

bool any_non_input_line(const list<Line>& lines) {
  for (list<Line>::const_iterator p = lines.begin(); p != lines.end(); ++p)
    if (!is_input(p->contents)) return true;
  return false;
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
