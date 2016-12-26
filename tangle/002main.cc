int main(int argc, const char* argv[]) {
  if (flag("test", argc, argv))
    return run_tests();
  return tangle(argc, argv);
}

bool flag(const string& flag, int argc, const char* argv[]) {
  for (int i = 1; i < argc; ++i)
    if (string(argv[i]) == flag)
      return true;
  return false;
}

string flag_value(const string& flag, int argc, const char* argv[]) {
  for (int i = 1; i < argc-1; ++i)
    if (string(argv[i]) == flag)
      return argv[i+1];
  return "";
}

//// test harness

int run_tests() {
  for (unsigned long i=0; i < sizeof(Tests)/sizeof(Tests[0]); ++i) {
    START_TRACING_UNTIL_END_OF_SCOPE;
    setup();
    (*Tests[i])();
    verify();
  }

  cerr << '\n';
  if (Num_failures > 0)
    cerr << Num_failures << " failure"
         << (Num_failures > 1 ? "s" : "")
         << '\n';
  return Num_failures;
}

void verify() {
  Hide_warnings = false;
  if (!Passed)
    ;
  else
    cerr << ".";
}

void setup() {
  Hide_warnings = false;
  Passed = true;
}
