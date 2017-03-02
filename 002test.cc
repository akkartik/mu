//: A simple test harness. To create new tests, define functions starting with
//: 'test_'. To run all tests so defined, run:
//:   $ ./mu test
//:
//: Every layer should include tests, and can reach into previous layers.
//: However, it seems like a good idea never to reach into tests from previous
//: layers. Every test should be a contract that always passes as originally
//: written, regardless of any later layers. Avoid writing 'temporary' tests
//: that are only meant to work until some layer.

:(before "End Types")
typedef void (*test_fn)(void);
:(before "Globals")
// move a global ahead into types that we can't generate an extern declaration for
const test_fn Tests[] = {
  #include "test_list"  // auto-generated; see 'build' script
};

:(before "End Globals")
bool Run_tests = false;
bool Passed = true;  // set this to false inside any test to indicate failure
long Num_failures = 0;

:(before "End Includes")
#define CHECK(X) \
  if (Passed && !(X)) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << '\n'; \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

#define CHECK_EQ(X, Y) \
  if (Passed && (X) != (Y)) { \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << " == " << #Y << '\n'; \
    cerr << "  got " << (X) << '\n';  /* BEWARE: multiple eval */ \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

:(before "End Setup")
Passed = true;

:(before "End Commandline Parsing")
if (argc > 1 && is_equal(argv[1], "test")) {
  Run_tests = true;  --argc;  ++argv;  // shift 'test' out of commandline args
}

:(before "End Main")
if (Run_tests) {
  // Test Runs
  // we run some tests and then exit; assume no state need be maintained afterward

  // End Test Run Initialization
  time_t t;  time(&t);
  cerr << "C tests: " << ctime(&t);
  for (size_t i=0;  i < sizeof(Tests)/sizeof(Tests[0]);  ++i) {
//?     cerr << i << '\n';
    run_test(i);
  }
  cerr << '\n';
  // End Tests
  if (Num_failures > 0) {
    cerr << Num_failures << " failure"
         << (Num_failures > 1 ? "s" : "")
         << '\n';
    return 1;
  }
  return 0;
}

:(code)
void run_test(size_t i) {
  if (i >= sizeof(Tests)/sizeof(Tests[0])) {
    cerr << "no test " << i << '\n';
    return;
  }
  setup();
  // End Test Setup
  (*Tests[i])();
  // End Test Teardown
  teardown();
  if (Passed) cerr << '.';
  else ++Num_failures;
}

bool is_integer(const string& s) {
  return s.find_first_not_of("0123456789-") == string::npos  // no other characters
      && s.find_first_of("0123456789") != string::npos  // at least one digit
      && s.find('-', 1) == string::npos;  // '-' only at first position
}

int to_integer(string n) {
  char* end = NULL;
  // safe because string.c_str() is guaranteed to be null-terminated
  int result = strtoll(n.c_str(), &end, /*any base*/0);
  if (*end != '\0') cerr << "tried to convert " << n << " to number\n";
  assert(*end == '\0');
  return result;
}

void test_is_integer() {
  CHECK(is_integer("1234"));
  CHECK(is_integer("-1"));
  CHECK(!is_integer("234.0"));
  CHECK(is_integer("-567"));
  CHECK(!is_integer("89-0"));
  CHECK(!is_integer("-"));
  CHECK(!is_integer("1e3"));  // not supported
}

:(before "End Includes")
#include <stdlib.h>
