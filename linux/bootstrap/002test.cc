//: A simple test harness. To create new tests, define functions starting with
//: 'test_'. To run all tests so defined, run:
//:   $ ./bootstrap test
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
  #include "test_list"  // auto-generated; see 'build*' scripts
};

:(before "End Globals")
bool Run_tests = false;
bool Passed = true;  // set this to false inside any test to indicate failure

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

:(before "End Reset")
Passed = true;

:(before "End Commandline Parsing")
if (argc > 1 && is_equal(argv[1], "test")) {
  Run_tests = true;  --argc;  ++argv;  // shift 'test' out of commandline args
}

:(before "End Main")
if (Run_tests) {
  // Test Runs
  // we run some tests and then exit; assume no state need be maintained afterward

  long num_failures = 0;
  // End Test Run Initialization
  time_t t;  time(&t);
  cerr << "C tests: " << ctime(&t);
  for (size_t i=0;  i < sizeof(Tests)/sizeof(Tests[0]);  ++i) {
//?     cerr << "running " << Test_names[i] << '\n';
    run_test(i);
    if (Passed) cerr << '.';
    else ++num_failures;
  }
  cerr << '\n';
  // End Tests
  if (num_failures > 0) {
    cerr << num_failures << " failure"
         << (num_failures > 1 ? "s" : "")
         << '\n';
    return 1;
  }
  return 0;
}

:(after "End Main")
//: Raise other unrecognized sub-commands as errors.
//: We couldn't do this until now because we want `./bootstrap test` to always
//: succeed, no matter how many layers are included in the build.
cerr << "nothing to do\n";
return 1;

:(code)
void run_test(size_t i) {
  if (i >= sizeof(Tests)/sizeof(Tests[0])) {
    cerr << "no test " << i << '\n';
    return;
  }
  reset();
  // End Test Setup
  (*Tests[i])();
  // End Test Teardown
}

//: Convenience: run a single test
:(before "Globals")
// Names for each element of the 'Tests' global, respectively.
const string Test_names[] = {
  #include "test_name_list"  // auto-generated; see 'build*' scripts
};
:(after "Test Runs")
string maybe_single_test_to_run = argv[argc-1];
for (size_t i=0;  i < sizeof(Tests)/sizeof(Tests[0]);  ++i) {
  if (Test_names[i] == maybe_single_test_to_run) {
    run_test(i);
    if (Passed) cerr << ".\n";
    return 0;
  }
}

//: A pending test that also serves to put our test harness through its paces.

:(code)
void test_is_equal() {
  CHECK(is_equal("", ""));
  CHECK(!is_equal("", "foo"));
  CHECK(!is_equal("foo", ""));
  CHECK(!is_equal("f", "bar"));
  CHECK(!is_equal("bar", "f"));
  CHECK(!is_equal("bar", "ba"));
  CHECK(!is_equal("ba", "bar"));
  CHECK(is_equal("bar", "bar"));
}

:(before "End Includes")
#include <stdlib.h>
