//: Everything this project/binary supports.
//: This should give you a sense for what to look forward to in later layers.

:(before "End Commandline Parsing")
if (argc <= 1 || is_equal(argv[1], "--help")) {
  //: this is the functionality later layers will provide
  // currently no automated tests for commandline arg parsing
  cerr << get(Help, "usage");
  return 0;
}

//: Support for option parsing.
//: Options always begin with '--' and are always the first arguments. An
//: option will never follow a non-option.
char** arg = &argv[1];
while (argc > 1 && starts_with(*arg, "--")) {
  if (false)
    ;  // no-op branch just so any further additions can consistently always start with 'else'
  // End Commandline Options(*arg)
  else
    cerr << "skipping unknown option " << *arg << '\n';
  --argc;  ++argv;  ++arg;
}

if (is_equal(argv[1], "help")) {
  if (argc == 2) {
    cerr << "help on what?\n";
    help_contents();
    return 0;
  }
  string key(argv[2]);
  // End Help Special-cases(key)
  if (contains_key(Help, key)) {
    cerr << get(Help, key);
    return 0;
  }
  else {
    cerr << "No help found for '" << key << "'\n";
    help_contents();
    cerr << "Please check your command for typos.\n";
    return 1;
  }
}

:(code)
void help_contents() {
  cerr << "Available top-level topics:\n";
  cerr << "  usage\n";
  // End Help Contents
}

:(before "End Globals")
map<string, string> Help;
:(before "End Includes")
#include <map>
using std::map;
:(before "End One-time Setup")
init_help();
:(code)
void init_help() {
  put(Help, "usage",
    "bootstrap: the bootstrap translator for SubX.\n"
    "This program also wraps some miscellaneous useful functionality:\n"
    "  - an x86 emulator: `bootstrap run`\n"
    "  - online help: `bootstrap help`\n"
    "\n"
    "== Ways to invoke bootstrap\n"
    "- See this message:\n"
    "    bootstrap --help\n"
    "- Convert a textual SubX program into a standard ELF binary that you can\n"
    "  run on your computer:\n"
    "    bootstrap translate input1.subx input2.subx ... -o <output ELF binary>\n"
    "- Run a SubX binary using SubX itself (for better error messages):\n"
    "    bootstrap run <ELF binary>\n"
    "- Run all bootstrap's unit tests:\n"
    "    bootstrap test\n"
    "- Run a single unit test:\n"
    "    bootstrap test <test name>\n"
    "     e.g. bootstrap test test_copy_imm32_to_EAX\n"
    "\n"
    "== Debugging aids\n"
    "- Add '--trace' to any of these commands to save a trace to disk at the end.\n"
    "  This can run out of memory for long-running commands.\n"
    "- Add '--debug' to emit additional debug information during translation.\n"
    "  'bootstrap --debug translate' will save metadata to disk that\n"
    "  'bootstrap --trace run' uses to make traces more informative.\n"
    "\n"
    "Options starting with '--' must always come before any other arguments.\n"
    "\n"
    "To start learning how to write SubX programs, see Readme.md (particularly\n"
    "the section on the x86 instruction set) and then run:\n"
    "  bootstrap help\n"
  );
  // End Help Texts
}

:(code)
bool is_equal(const char* s, const char* lit) {
  size_t len = strlen(lit);
  if (strlen(s) != len) return false;
  return strncmp(s, lit, len) == 0;
}

bool starts_with(const string& s, const string& pat) {
  string::const_iterator a=s.begin(), b=pat.begin();
  for (/*nada*/;  a!=s.end() && b!=pat.end();  ++a, ++b)
    if (*a != *b) return false;
  return b == pat.end();
}

//: I'll throw some style conventions here for want of a better place for them.
//: As a rule I hate style guides. Do what you want, that's my motto. But since
//: we're dealing with C/C++, the one big thing we want to avoid is undefined
//: behavior. If a compiler ever encounters undefined behavior it can make
//: your program do anything it wants.
//:
//: For reference, my checklist of undefined behaviors to watch out for:
//:   out-of-bounds access
//:   uninitialized variables
//:   use after free
//:   dereferencing invalid pointers: null, a new of size 0, others
//:
//:   casting a large number to a type too small to hold it
//:
//:   integer overflow
//:   division by zero and other undefined expressions
//:   left-shift by negative count
//:   shifting values by more than or equal to the number of bits they contain
//:   bitwise operations on signed numbers
//:
//:   Converting pointers to types of different alignment requirements
//:     T* -> void* -> T*: defined
//:     T* -> U* -> T*: defined if non-function pointers and alignment requirements are same
//:     function pointers may be cast to other function pointers
//:
//:       Casting a numeric value into a value that can't be represented by the target type (either directly or via static_cast)
//:
//: To guard against these, some conventions:
//:
//: 0. Initialize all primitive variables in functions and constructors.
//:
//: 1. Minimize use of pointers and pointer arithmetic. Avoid 'new' and
//: 'delete' as far as possible. Rely on STL to perform memory management to
//: avoid use-after-free issues (and memory leaks).
//:
//: 2. Avoid naked arrays to avoid out-of-bounds access. Never use operator[]
//: except with map. Use at() with STL vectors and so on.
//:
//: 3. Valgrind all the things.
//:
//: 4. Avoid unsigned numbers. Not strictly an undefined-behavior issue, but
//: the extra range doesn't matter, and it's one less confusing category of
//: interaction gotchas to worry about.
//:
//: Corollary: don't use the size() method on containers, since it returns an
//: unsigned and that'll cause warnings about mixing signed and unsigned,
//: yadda-yadda. Instead use this macro below to perform an unsafe cast to
//: signed. We'll just give up immediately if a container's ever too large.
//: Basically, Mu is not concerned about this being a little slower than it
//: could be. (https://gist.github.com/rygorous/e0f055bfb74e3d5f0af20690759de5a7)
//:
//: Addendum to corollary: We're going to uniformly use int everywhere, to
//: indicate that we're oblivious to number size, and since Clang on 32-bit
//: platforms doesn't yet support multiplication over 64-bit integers, and
//: since multiplying two integers seems like a more common situation to end
//: up in than integer overflow.
:(before "End Includes")
#define SIZE(X) (assert((X).size() < (1LL<<(sizeof(int)*8-2))), static_cast<int>((X).size()))

//: 5. Integer overflow is guarded against at runtime using the -ftrapv flag
//: to the compiler, supported by Clang (GCC version only works sometimes:
//: http://stackoverflow.com/questions/20851061/how-to-make-gcc-ftrapv-work).
:(before "atexit(reset)")
initialize_signal_handlers();  // not always necessary, but doesn't hurt
//? cerr << INT_MAX+1 << '\n';  // test overflow
//? assert(false);  // test SIGABRT
:(code)
// based on https://spin.atomicobject.com/2013/01/13/exceptions-stack-traces-c
void initialize_signal_handlers() {
  struct sigaction action;
  bzero(&action, sizeof(action));
  action.sa_sigaction = dump_and_exit;
  sigemptyset(&action.sa_mask);
  sigaction(SIGABRT, &action, NULL);  // assert() failure or integer overflow on linux (with -ftrapv)
  sigaction(SIGILL,  &action, NULL);  // integer overflow on OS X (with -ftrapv)
}
void dump_and_exit(int sig, siginfo_t* /*unused*/, void* /*unused*/) {
  switch (sig) {
    case SIGABRT:
      #ifndef __APPLE__
        cerr << "SIGABRT: might be an integer overflow if it wasn't an assert() failure\n";
        _Exit(1);
      #endif
      break;
    case SIGILL:
      #ifdef __APPLE__
        cerr << "SIGILL: most likely caused by integer overflow\n";
        _Exit(1);
      #endif
      break;
    default:
      break;
  }
}
:(before "End Includes")
#include <signal.h>

//: 6. Map's operator[] being non-const is fucking evil.
:(before "Globals")  // can't generate prototypes for these
// from http://stackoverflow.com/questions/152643/idiomatic-c-for-reading-from-a-const-map
template<typename T> typename T::mapped_type& get(T& map, typename T::key_type const& key) {
  typename T::iterator iter(map.find(key));
  if (iter == map.end()) {
    cerr << "get couldn't find key '" << key << "'\n";
    assert(iter != map.end());
  }
  return iter->second;
}
template<typename T> typename T::mapped_type const& get(const T& map, typename T::key_type const& key) {
  typename T::const_iterator iter(map.find(key));
  if (iter == map.end()) {
    cerr << "get couldn't find key '" << key << "'\n";
    assert(iter != map.end());
  }
  return iter->second;
}
template<typename T> typename T::mapped_type const& put(T& map, typename T::key_type const& key, typename T::mapped_type const& value) {
  map[key] = value;
  return map[key];
}
template<typename T> bool contains_key(T& map, typename T::key_type const& key) {
  return map.find(key) != map.end();
}
template<typename T> typename T::mapped_type& get_or_insert(T& map, typename T::key_type const& key) {
  return map[key];
}
template<typename T> typename T::mapped_type const& put_new(T& map, typename T::key_type const& key, typename T::mapped_type const& value) {
  assert(map.find(key) == map.end());
  map[key] = value;
  return map[key];
}
//: The contract: any container that relies on get_or_insert should never call
//: contains_key.

//: 7. istreams are a royal pain in the arse. You have to be careful about
//: what subclass you try to putback into. You have to watch out for the pesky
//: failbit and badbit. Just avoid eof() and use this helper instead.
:(code)
bool has_data(istream& in) {
  return in && !in.eof();
}

:(before "End Includes")
#include <assert.h>

#include <iostream>
using std::istream;
using std::ostream;
using std::iostream;
using std::cin;
using std::cout;
using std::cerr;
#include <iomanip>

#include <string.h>
#include <string>
using std::string;

#include <algorithm>
using std::min;
using std::max;
