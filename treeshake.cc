// Read a set of lines on stdin of the following form:
//  definition:
//    ...
//    ...
//
// Delete all 'dead' definitions with following indented lines that aren't
// used outside their bodies.
//
// This can be transitive; deleting one definition may cause other definitions
// to become dead.
//
// Also assorts segments as a side-effect.
//
// Like linkify, treeshake is a hack.

#include<assert.h>

#include<map>
using std::map;
#include<vector>
using std::vector;
#define SIZE(X) (assert((X).size() < (1LL<<(sizeof(int)*8-2))), static_cast<int>((X).size()))

#include<string>
using std::string;

#include<iostream>
using std::cin;
using std::cout;
using std::cerr;

#include<sstream>
using std::istringstream;

bool starts_with(const string& s, const string& pat) {
  string::const_iterator a=s.begin(), b=pat.begin();
  for (/*nada*/;  a!=s.end() && b!=pat.end();  ++a, ++b)
    if (*a != *b) return false;
  return b == pat.end();
}

// input

void read_body(string name, string definition_line, map<string, vector<string> >& segment) {
  // last definition wins; this only matters for the 'Entry' label in the code segment
  segment[name] = vector<string>();
  segment[name].push_back(definition_line);
  while (!cin.eof()) {
    if (cin.peek() != ' ' && cin.peek() != '$') break;  // assumes: no whitespace but spaces; internal labels start with '$'
    string line;
    getline(cin, line);
    segment[name].push_back(line);
  }
}

void read_lines(string segment_header, map<string, vector<string> >& segment) {
  // first segment header wins
  if (segment.empty())
    segment["=="].push_back(segment_header);  // '==' is a special key containing the segment header
  while (!cin.eof()) {
    if (cin.peek() == '=') break;  // assumes: no line can start with '=' except a segment header
    assert(cin.peek() != ' ');  // assumes: no whitespace but spaces
    string line;
    getline(cin, line);
    istringstream lstream(line);
    string name;
    getline(lstream, name, ' ');
    assert(name[SIZE(name)-1] == ':');
    name.erase(--name.end());
    read_body(name, line, segment);
  }
}

void read_lines(map<string, vector<string> >& code, map<string, vector<string> >& data) {
  while (!cin.eof()) {
    string line;
    getline(cin, line);
    assert(starts_with(line, "== "));
    map<string, vector<string> >& curr = (line.substr(3, 4) == "code") ? code : data;  // HACK: doesn't support segments except 'code' and 'data'
    read_lines(line, curr);
  }
}

// treeshake

bool any_line_matches(string pat, const vector<string>& lines) {
  for (int i = 0;  i < SIZE(lines);  ++i)
    if (lines.at(i).find(pat) != string::npos)  // conservative: confused by word boundaries, comments and string literals
      return true;
  return false;
}

bool is_dead(string key, const map<string, vector<string> >& code, const map<string, vector<string> >& data) {
  if (key == "Entry") return false;
  if (key == "==") return false;
  for (map<string, vector<string> >::const_iterator p = code.begin();  p != code.end();  ++p) {
    if (p->first == key) continue;
    if (any_line_matches(key, p->second)) return false;
  }
  for (map<string, vector<string> >::const_iterator p = data.begin();  p != data.end();  ++p) {
    if (p->first == key) continue;
    if (any_line_matches(key, p->second)) return false;
  }
  return true;
}

void treeshake(map<string, vector<string> >& code, map<string, vector<string> >& data) {
  for (map<string, vector<string> >::iterator p = code.begin();  p != code.end();  ++p) {
    if (is_dead(p->first, code, data)) {
//?       cerr << "  erasing " << p->first << '\n';
      code.erase(p);
      return;
    }
  }
  for (map<string, vector<string> >::iterator p = data.begin();  p != data.end();  ++p) {
    if (is_dead(p->first, code, data)) {
//?       cerr << "  erasing " << p->first << '\n';
      data.erase(p);
      return;
    }
  }
}

// output

void dump(const map<string, vector<string> > definitions) {
  // nothing special needed for segment headers, since '=' precedes all alphabet in ASCII
  for (map<string, vector<string> >::const_iterator p = definitions.begin();  p != definitions.end();  ++p) {
    const vector<string>& lines = p->second;
    for (int i = 0;  i < SIZE(lines);  ++i)
      cout << lines[i] << '\n';
  }
}

int main() {
  map<string, vector<string> > code, data;
  read_lines(code, data);
  for (int iter = 0;  ;  ++iter) {
//?     cerr << "iter: " << iter << '\n';
    int old_csize = SIZE(code), old_dsize = SIZE(data);
    treeshake(code, data);
    if (SIZE(code) == old_csize && SIZE(data) == old_dsize) break;
  }
  dump(code);
  dump(data);
  return 0;
}
