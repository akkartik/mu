// Read a single-file C++ program having a very specific structure, and split
// it up into multiple separate compilation units to reduce the work needed to
// rebuild after a small change. Write each compilation unit only if it has
// changed from what was on disk before.
//
// This tool is tightly coupled with the build system for this project. The
// makefile already auto-generates various things; we only do here what
// standard unix tools can't easily do.
//
// Usage:
//  cleave [input C++ file] [existing output directory]
//
// The input C++ file has the following structure:
//   [#includes]
//   [type definitions]
//   // Globals
//   [global variable definitions]
//   // End Globals
//   [function definitions]
//
// Afterwards, the output directory contains:
//   header -- everything before the '// Globals' delimiter
//   global_definitions_list -- everything between '// Globals' and '// End Globals' delimiters
//   [.cc files partitioning function definitions]
//
// Each output function definition file contains:
//   #include "header"
//   #include "global_declarations_list"
//   [function definitions]
//
// We'll chunk the files at boundaries where we encounter a '#line ' directive
// between functions.
//
// One exception: the first file emitted #includes "global_definitions_list" instead
// of "global_declarations_list"

// Tune this parameter to balance time for initial vs incremental build.
//
//   Larger numbers -> larger/fewer compilation units -> faster initial build
//   Smaller numbers -> smaller compilation units -> faster incremental build
int Compilation_unit_size = 200;

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
using std::ofstream;

#include <locale>
using std::isspace;  // unicode-aware

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

bool starts_with(const string& s, const string& pat) {
  return s.substr(0, pat.size()) == pat;
}

bool has_data(istream& in) {
  return in && !in.eof();
}

void slurp(const string/*copy*/ filename, vector<string>& lines) {
  lines.clear();
  ifstream in(filename.c_str());
  while (has_data(in)) {
    string curr_line;
    getline(in, curr_line);
    lines.push_back(curr_line);
  }
}

size_t slurp_some_functions(const vector<string>& in, size_t start, vector<string>& out, bool first) {
  out.clear();
  if (start >= in.size()) return start;
  out.push_back("#include \"header\"");
  if (first)
    out.push_back("#include \"global_definitions_list\"");
  else
    out.push_back("#include \"global_declarations_list\"");
  out.push_back("");
  size_t curr = start;
  for (int i = 0; i < Compilation_unit_size; ++i) {
    while (curr < in.size()) {
      // read functions -- lines until unindented '}'
      while (curr < in.size()) {
        const string& line = in.at(curr);
//?         cerr << curr << ": adding to function: " << line << '\n';
        out.push_back(line);  ++curr;
        if (!line.empty() && line.at(0) == '}') break;
      }
      // now look for a '#line' directive before the next non-comment non-empty
      // line
      while (curr < in.size()) {
        const string& line = in.at(curr);
        if (starts_with(line, "#line ")) goto try_return;
        out.push_back(line);   ++curr;
        if (trim(line).empty()) continue;
        if (starts_with(trim(line), "//")) continue;
        break;
      }
    }
    try_return:;
  }

  // Idea: Increase the number of functions to include in the next call to
  // slurp_some_functions.
  // Early functions are more likely to be larger because later layers added
  // to them.
//?   Compilation_unit_size *= 1.5;
  return curr;
}

// compare contents of a file with a list of lines, ignoring #line directives
// on both sides
bool no_change(const vector<string>& lines, const string& output_filename) {
  vector<string> old_lines;
  slurp(output_filename, old_lines);
  size_t l=0, o=0;
  while (true) {
    while (l < lines.size() &&
            (lines.at(l).empty() || starts_with(lines.at(l), "#line "))) {
      ++l;
    }
    while (o < old_lines.size() &&
            (old_lines.at(o).empty() || starts_with(old_lines.at(o), "#line "))) {
      ++o;
    }
    if (l >= lines.size() && o >= old_lines.size()) return true;  // no change
    if (l >= lines.size() || o >= old_lines.size()) return false;  // contents changed
//?     cerr << "comparing\n";
//?     cerr << o << ": " << old_lines.at(o) << '\n';
//?     cerr << l << ": " << lines.at(l) << '\n';
    if (lines.at(l) != old_lines.at(o)) return false;  // contents changed
    ++l;  ++o;
  }
  assert(false);
}

string next_output_filename(const string& output_directory) {
  static int file_count = 0;
  ostringstream out;
  out << output_directory << "/mu_" << file_count << ".cc";
  file_count++;
  return out.str();
}

void emit_file(const vector<string>& lines, const string& output_filename) {
  if (no_change(lines, output_filename)) return;
  cerr << "  updating " << output_filename << '\n';
  ofstream out(output_filename.c_str());
  for (size_t i = 0; i < lines.size(); ++i)
    out << lines.at(i) << '\n';
}

void emit_compilation_unit(const vector<string>& lines, const string& output_directory) {
  string output_filename = next_output_filename(output_directory);
  emit_file(lines, output_filename);
}

int main(int argc, const char* argv[]) {
  if (argc != 3) {
    cerr << "usage: cleave [input .cc file] [output directory]\n";
    exit(0);
  }

  vector<string> lines;

  // read input
  slurp(argv[1], lines);

  string output_directory = argv[2];

  // write header until but excluding '// Global' delimiter
  size_t line_num = 0;
  {
    vector<string> out;
    while (line_num < lines.size()) {
      const string& line = lines.at(line_num);
      if (trim(line) == "// Globals") break;  // todo: #line directive for delimiters
      out.push_back(line);
      ++line_num;
    }
    emit_file(out, output_directory+"/header");
  }

  // write global_definitions_list (including delimiters)
  {
    vector<string> out;
    while (line_num < lines.size()) {
      const string& line = lines.at(line_num);
      out.push_back(line);
      ++line_num;
      if (trim(line) == "// End Globals") break;
    }
    emit_file(out, output_directory+"/global_definitions_list");
  }

  // segment functions
  // first one is special
  if (line_num < lines.size()) {
    vector<string> function;
    line_num = slurp_some_functions(lines, line_num, function, true);
    emit_compilation_unit(function, output_directory);
  }
  while (line_num < lines.size()) {
    vector<string> function;
    line_num = slurp_some_functions(lines, line_num, function, false);
    emit_compilation_unit(function, output_directory);
  }
}
