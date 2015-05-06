//: Everything this project/binary supports.
//: This should give you a sense for what to look forward to in later layers.

:(before "End Commandline Parsing")
if (argc <= 1 || is_equal(argv[1], "--help")) {
  // this is the functionality later layers will provide
  // currently no automated tests for commandline arg parsing
  cerr << "To load files and run 'main':\n"
       << "  mu file1.mu file2.mu ...\n"
       << "To run all tests:\n"
       << "  mu test\n"
       << "To load files and then run all tests:\n"
       << "  mu test file1.mu file2.mu ...\n"
       ;
  return 0;
}

//:: Helper function used by the above fragment of code (and later layers too,
//:: who knows?).
//: The :(code) directive appends function definitions to the end of the
//: project. Regardless of where functions are defined, we can call them
//: anywhere we like as long as we format the function header in a specific
//: way: put it all on a single line without indent, end the line with ') {'
//: and no trailing whitespace. As long as functions uniformly start this
//: way, our makefile contains a little command to automatically generate
//: declarations for them.
:(code)
bool is_equal(char* s, const char* lit) {
  return strncmp(s, lit, strlen(lit)) == 0;
}

:(before "End Includes")
#include<assert.h>

#include<iostream>
using std::istream;
using std::ostream;
using std::iostream;
using std::cin;
using std::cout;
using std::cerr;

#include<cstring>
#include<string>
using std::string;
typedef size_t index_t;
const index_t NOT_FOUND = string::npos;
:(after "int main(int argc, char* argv[])")
assert(sizeof(string::size_type) == sizeof(size_t));
assert(sizeof(index_t) == sizeof(size_t));
