int main(int argc, const char* argv[]) {
  if (argc == 2 && string(argv[1]) == "test") {
    run_tests();
    return 0;
  }

  for (int i = 1; i < argc; ++i) {
    load(argv[i]);
  }
  run("main");
}

void load(const char* filename) {
}

void run(const char* function_name) {
}



//// test harness

void run_tests() {
  for (unsigned long i=0; i < sizeof(Tests)/sizeof(Tests[0]); ++i) {
    START_TRACING_UNTIL_END_OF_SCOPE;
    setup();
    CLEAR_TRACE;
    (*Tests[i])();
    verify();
  }
  cerr << '\n';
  if (Num_failures > 0)
    cerr << Num_failures << " failure"
         << (Num_failures > 1 ? "s" : "")
         << '\n';
}

void verify() {
  if (!Passed)
    ;
  else
    cerr << ".";
}

void setup() {
  Passed = true;
}

string time_string() {
  time_t t;
  time(&t);
  char buffer[10];
  if (!strftime(buffer, 10, "%H:%M:%S", localtime(&t)))
    return "";
  return buffer;
}
