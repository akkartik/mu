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

// I'll throw some style conventions here for want of a better place for them.
// As a rule I hate style guides. Do what you want, that's my motto. But since
// we're dealing with C/C++, the one big thing we want to avoid is undefined
// behavior. If a compiler ever encounters undefined behavior it can make
// your program do anything it wants.
//
// For reference, my checklist of undefined behaviors to watch out for:
//   out-of-bounds access
//   uninitialized variables
//   use after free
//   dereferencing invalid pointers: null, a new of size 0, others
//
//   casting a large number to a type too small to hold it
//
//   integer overflow
//   division by zero and other undefined expressions
//   left-shift by negative count
//   shifting values by more than or equal to the number of bits they contain
//   bitwise operations on signed numbers
//
//   Converting pointers to types of different alignment requirements
//     T* -> void* -> T*: defined
//     T* -> U* -> T*: defined if non-function pointers and alignment requirements are same
//     function pointers may be cast to other function pointers
//
//       Casting a numeric value into a value that can't be represented by the target type (either directly or via static_cast)
//
// To guard against these, some conventions:
//
// 0. Initialize all primitive variables in functions and constructors.
//
// 1. Minimize use of pointers and pointer arithmetic. Avoid 'new' and
// 'delete' as far as possible. Rely on STL to perform memory management to
// avoid use-after-free issues (and memory leaks).
//
// 2. Avoid naked arrays to avoid out-of-bounds access. Never use operator[]
// except with map. Use at() with STL vectors and so on.
//
// 3. Valgrind all the things.
//
// 4. Avoid unsigned numbers. Not strictly an undefined-behavior issue, but
// the extra range doesn't matter, and it's one less confusing category of
// interaction gotchas to worry about.
//
// Corollary: don't use the size() method on containers, since it returns an
// unsigned and that'll cause warnings about mixing signed and unsigned,
// yadda-yadda. Instead use this macro below to perform an unsafe cast to
// signed. We'll just give up immediately if a container's every too large.
:(before "End Includes")
#define SIZE(X) (assert(X.size() < (1LL<<62)), static_cast<long long int>(X.size()))
//
// 5. Integer overflow is still impossible to guard against. Maybe after
// reading http://www.cs.utah.edu/~regehr/papers/overflow12.pdf

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
