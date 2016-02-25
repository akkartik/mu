//: A simple test harness. To create new tests define functions starting with
//: 'test_'. To run all tests so defined, run:
//:   $ wart test
//:
//: So far it seems tasteful for layers to never ever reach back to modify
//: previously-defined tests. Every test is a contract once written, and should
//: pass as-is if it is included, regardless of how much later layers change
//: the program. Avoid writing 'temporary' tests that only work with some
//: subsets of the program.

:(before "End Types")
typedef void (*test_fn)(void);

:(before "End Globals")
const test_fn Tests[] = {
  #include "test_list"  // auto-generated; see makefile
};

bool Run_tests = false;
bool Passed = true;  // set this to false inside any test to indicate failure
long Num_failures = 0;

#define CHECK(X) \
  if (!(X)) { \
    ++Num_failures; \
    cerr << "\nF - " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << '\n'; \
    Passed = false; \
    return;  /* Currently we stop at the very first failure. */ \
  }

#define CHECK_EQ(X, Y) \
  if ((X) != (Y)) { \
    ++Num_failures; \
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
  time_t t; time(&t);
  cerr << "C tests: " << ctime(&t);
  for (size_t i=0; i < sizeof(Tests)/sizeof(Tests[0]); ++i) {
//?     cerr << i << '\n';
    run_test(i);
  }
  // End Tests
  cerr << '\n';
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
  teardown();
  if (Passed) cerr << ".";
}

bool is_integer(const string& s) {
  return s.find_first_not_of("0123456789-") == string::npos  // no other characters
      && s.find_first_of("0123456789") != string::npos  // at least one digit
      && s.find('-', 1) == string::npos;  // '-' only at first position
}

long long int to_integer(string n) {
  char* end = NULL;
  // safe because string.c_str() is guaranteed to be null-terminated
  long long int result = strtoll(n.c_str(), &end, /*any base*/0);
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
#include<cstdlib>
