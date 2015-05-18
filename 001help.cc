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
// behavior. So, conventions:

// 0. Initialize all primitive variables in methods and constructors.

// 1. Avoid 'new' and 'delete' as far as possible. Rely on STL to perform
// memory management to avoid use-after-free issues (and memory leaks).

// 2. Avoid arrays to avoid out-of-bounds access. Never use operator[] except
// with map. Use at() with STL vectors and so on.

// 3. Valgrind all the things.

// 4. Avoid unsigned numbers. Not strictly an undefined-behavior issue, but
// the extra range doesn't matter, and it's one less confusing category of
// interaction gotchas to worry about.
//
// We're screwed on overflow (undefined behavior). Use a decent compiler. But
// we're more likely to try to subtract unsigned 2 from 1 than we are to
// create integers that don't fit in 64 bits.
//
// Corollary: don't use the size() method on containers, since it returns an
// unsigned and that'll cause warnings about mixing signed and unsigned,
// yadda-yadda. Instead use this macro below to perform an unsafe cast to
// signed. We'll just give up immediately if a container's every too large.
:(before "End Includes")
#define SIZE(X) (assert(X.size() < 1LL<<62), static_cast<long long int>(X.size()))

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
