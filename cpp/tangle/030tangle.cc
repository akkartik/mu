// Reorder a file based on directives starting with ':(' (tangle directives).
// Insert #line directives to preserve line numbers in the original.
// Clear lines starting with '//:' (tangle comments).

#include<assert.h>
#include<sys/param.h>

size_t Line_number = 0;
string Filename;

int tangle(int argc, const char* argv[]) {
  list<string> result;
  for (int i = 1; i < argc; ++i) {
    ifstream in(argv[i]);
    Filename = argv[i];
    tangle(in, result);
  }
  for (list<string>::iterator p = result.begin(); p != result.end(); ++p)
    cout << *p << '\n';
  return 0;
}

void tangle(istream& in, list<string>& out) {
  Line_number = 1;
  out.push_back(line_directive(Line_number, Filename));
  string curr_line;
  while (!in.eof()) {
    getline(in, curr_line);
    Line_number++;
    if (starts_with(curr_line, ":("))
      process_next_hunk(in, trim(curr_line), out);
    else
      out.push_back(curr_line);
  }
  for (list<string>::iterator p = out.begin(); p != out.end(); ++p) {
    if (starts_with(*p, "//:"))
      p->clear();  // leave the empty lines around so as to not mess up #line numbers
  }
  trace_all("tangle", out);
}

string Toplevel = "run";

void process_next_hunk(istream& in, const string& directive, list<string>& out) {
  list<string> hunk;
  hunk.push_back(line_directive(Line_number, Filename));
  string curr_line;
  while (!in.eof()) {
    std::streampos old = in.tellg();
    getline(in, curr_line);
    if (starts_with(curr_line, ":(")) {
      in.seekg(old);
      break;
    }
    else {
      ++Line_number;
      hunk.push_back(curr_line);
    }
  }

  istringstream directive_stream(directive.substr(2));  // length of ":("
  string cmd = next_tangle_token(directive_stream);

  if (cmd == "code") {
    out.insert(out.end(), hunk.begin(), hunk.end());
    return;
  }

  if (cmd == "scenarios") {
    Toplevel = next_tangle_token(directive_stream);
    return;
  }

  if (cmd == "scenario") {
    list<string> result;
    string name = next_tangle_token(directive_stream);
    result.push_back(hunk.front());  // line number directive
    hunk.pop_front();
    emit_test(name, hunk, result);
    out.insert(out.end(), result.begin(), result.end());
    return;
  }

  if (cmd == "before" || cmd == "after" || cmd == "replace" || cmd == "replace{}" || cmd == "delete" || cmd == "delete{}") {
    list<string>::iterator target = locate_target(out, directive_stream);
    if (target == out.end()) {
      RAISE << "Couldn't find target " << directive << '\n' << die();
      return;
    }

    size_t end_line_number = 0;
    string end_filename;
    scan_up_to_last_line_directive(target, out.begin(), end_line_number, end_filename);

    indent_all(hunk, target);

    if (cmd == "before") {
      hunk.push_back(line_directive(end_line_number, end_filename));
      out.splice(target, hunk);
    }
    else if (cmd == "after") {
      ++end_line_number;
      hunk.push_back(line_directive(end_line_number, end_filename));
      ++target;
      out.splice(target, hunk);
    }
    else if (cmd == "replace" || cmd == "delete") {
      hunk.push_back(line_directive(end_line_number, end_filename));
      out.splice(target, hunk);
      out.erase(target);
    }
    else if (cmd == "replace{}" || cmd == "delete{}") {
      hunk.push_back(line_directive(end_line_number, end_filename));
      if (find_trim(hunk, ":OLD_CONTENTS") == hunk.end()) {
        out.splice(target, hunk);
        out.erase(target, balancing_curly(target));
      }
      else {
        list<string>::iterator next = balancing_curly(target);
        list<string> old_version;
        old_version.splice(old_version.begin(), out, target, next);
        old_version.pop_back();  old_version.pop_front();  // contents only please, not surrounding curlies

        list<string>::iterator new_pos = find_trim(hunk, ":OLD_CONTENTS");
        indent_all(old_version, new_pos);
        hunk.splice(new_pos, old_version);
        hunk.erase(new_pos);
        out.splice(next, hunk);
      }
    }
    return;
  }

  RAISE << "unknown directive " << cmd << '\n';
}

list<string>::iterator locate_target(list<string>& out, istream& directive_stream) {
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
    list<string>::iterator intermediate = find_substr(out, pat2);
    if (intermediate == out.end()) return out.end();
    return find_substr(out, intermediate, pat);
  }
  // second way to do nested pattern: intermediate 'then' pattern
  else if (next_token == "then") {
    list<string>::iterator intermediate = find_substr(out, pat);
    if (intermediate == out.end()) return out.end();
    string pat2 = next_tangle_token(directive_stream);
    if (pat2 == "") return out.end();
    return find_substr(out, intermediate, pat2);
  }
  RAISE << "unknown keyword in directive: " << next_token << '\n';
  return out.end();
}

// indent all lines in l like indentation at exemplar
void indent_all(list<string>& l, list<string>::iterator exemplar) {
  string curr_indent = indent(*exemplar);
  for (list<string>::iterator p = l.begin(); p != l.end(); ++p)
    if (!p->empty())
      p->insert(p->begin(), curr_indent.begin(), curr_indent.end());
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
    if (c == '\\')  // only works for double-quotes
      continue;
    if (c == '"')
      break;
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

list<string>::iterator balancing_curly(list<string>::iterator orig) {
  list<string>::iterator curr = orig;
  long open_curlies = 0;
  do {
    for (string::iterator p = curr->begin(); p != curr->end(); ++p) {
      if (*p == '{') ++open_curlies;
      if (*p == '}') --open_curlies;
    }
    ++curr;
    // no guard so far against unbalanced curly
  } while (open_curlies != 0);
  return curr;
}

// A scenario is one or more sessions separated by calls to CLEAR_TRACE ('===')
//  A session is one or more lines of input
//  followed by a return value ('=>')
//  followed by one or more lines expected in trace in order ('+')
//  followed by one or more lines trace shouldn't include ('-')
// Remember to update is_input below if you add to this format.
void emit_test(const string& name, list<string>& lines, list<string>& result) {
  result.push_back("TEST("+name+")");
  while (any_non_input_line(lines)) {
    if (is_warn(lines.front())) {
      result.push_back("  Hide_warnings = true;");
      lines.pop_front();
    }
    result.push_back("  "+Toplevel+"(\""+input_lines(lines)+"\");");
    if (!lines.empty() && lines.front()[0] == '+')
      result.push_back("  CHECK_TRACE_CONTENTS(\""+expected_in_trace(lines)+"\");");
    while (!lines.empty() && lines.front()[0] == '-') {
      result.push_back("  CHECK_TRACE_DOESNT_CONTAIN(\""+expected_not_in_trace(lines.front())+"\");");
      lines.pop_front();
    }
    if (!lines.empty() && lines.front() == "===") {
      result.push_back("  CLEAR_TRACE;");
      lines.pop_front();
    }
    if (!lines.empty() && lines.front() == "?") {
      result.push_back("  DUMP(\"\");");
      lines.pop_front();
    }
  }
  result.push_back("}");

  while (!lines.empty() &&
         (trim(lines.front()).empty() || starts_with(lines.front(), "//")))
    lines.pop_front();
  if (!lines.empty()) {
    cerr << lines.size() << " unprocessed lines in scenario.\n";
    exit(1);
  }
}

bool is_input(const string& line) {
  return line != "===" && line[0] != '+' && line[0] != '-' && !starts_with(line, "=>");
}

bool is_warn(const string& line) {
  return line == "hide warnings";
}

string input_lines(list<string>& hunk) {
  string result;
  while (!hunk.empty() && is_input(hunk.front())) {
    result += hunk.front()+"";  // temporary delimiter; replace with escaped newline after escaping other backslashes
    hunk.pop_front();
  }
  return escape(result);
}

string expected_in_trace(list<string>& hunk) {
  string result;
  while (!hunk.empty() && hunk.front()[0] == '+') {
    hunk.front().erase(0, 1);
    result += hunk.front()+"";
    hunk.pop_front();
  }
  return escape(result);
}

string expected_not_in_trace(const string& line) {
  return escape(line.substr(1));
}

list<string>::iterator find_substr(list<string>& in, const string& pat) {
  for (list<string>::iterator p = in.begin(); p != in.end(); ++p)
    if (p->find(pat) != NOT_FOUND)
      return p;
  return in.end();
}

list<string>::iterator find_substr(list<string>& in, list<string>::iterator p, const string& pat) {
  for (; p != in.end(); ++p)
    if (p->find(pat) != NOT_FOUND)
      return p;
  return in.end();
}

list<string>::iterator find_trim(list<string>& in, const string& pat) {
  for (list<string>::iterator p = in.begin(); p != in.end(); ++p)
    if (trim(*p) == pat)
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
  for (size_t pos = s.find(a); pos != NOT_FOUND; pos = s.find(a, pos+b.size()))
    s = s.replace(pos, a.size(), b);
  return s;
}

bool any_line_starts_with(const list<string>& lines, const string& pat) {
  for (list<string>::const_iterator p = lines.begin(); p != lines.end(); ++p)
    if (starts_with(*p, pat)) return true;
  return false;
}

bool any_non_input_line(const list<string>& lines) {
  for (list<string>::const_iterator p = lines.begin(); p != lines.end(); ++p)
    if (!is_input(*p)) return true;
  return false;
}

#include <locale>
using std::isspace;  // unicode-aware

// does s start with pat, after skipping whitespace?
// pat can't start with whitespace
bool starts_with(const string& s, const string& pat) {
  for (size_t pos = 0; pos < s.size(); ++pos)
    if (!isspace(s[pos]))
      return s.compare(pos, pat.size(), pat) == 0;
  return false;
}

string indent(const string& s) {
  for (size_t pos = 0; pos < s.size(); ++pos)
    if (!isspace(s[pos]))
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

string line_directive(size_t line_number, string filename) {
  ostringstream result;
  if (filename.empty())
    result << "#line " << line_number;
  else
    result << "#line " << line_number << " \"" << filename << '"';
  return result.str();
}

void scan_up_to_last_line_directive(list<string>::iterator p, list<string>::iterator begin, size_t& line_number, string& filename) {
//?   cout << "scan: " << *p << " until " << *begin << '\n'; //? 1
  int delta = 0;
  if (p != begin) {
    for (--p; p != begin; --p) {
//?       cout << "  " << *p << ' ' << delta << '\n'; //? 1
      if (starts_with(*p, "#line")) continue;
//?       cout << "incrementing\n"; //? 1
      ++delta;
    }
//?     cout << "delta: " << delta << '\n'; //? 1
  }
  if (p == begin) {
    assert(starts_with(*p, "#line"));
//?     cout << "hit begin\n";
//?     line_number = delta;
//?     return;
  }
  istringstream in(*p);
  string directive_;
  in >> directive_;
  assert(directive_ == "#line");
  in >> line_number;
  line_number += delta;
//?   cout << line_number << '\n'; //? 1
  if (in.eof()) return;
  in >> filename;
  if (filename[0] == '"') filename.erase(0, 1);
  if (filename[filename.size()-1] == '"') filename.erase(filename.size()-1);
//?   cout << filename << '\n'; //? 1
}
