//: Automatically aggregate functions starting with 'test-' into a test suite
//: called 'run-tests'. Running this function will run all tests.
//:
//: This is actually SubX's first (trivial) compiler. We generate all the code
//: needed for the 'run-tests' function.
//:
//: By convention, temporary functions needed by tests will start with
//: '_test-'.

//: We don't rely on any transforms running in previous layers, but this layer
//: knows about labels and will emit labels for previous layers to transform.
:(after "Begin Transforms")
Transform.push_back(create_test_function);

:(code)
void test_run_test() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000100;
  run(
      "== code 0x1\n"  // code segment
      "main:\n"
      "  e8/call run-tests/disp32\n"  // 5 bytes
      "  f4/halt\n"                   // 1 byte
      "test-foo:\n"  // offset 7
      "  01 d8\n"  // just some unique instruction: add EBX to EAX
      "  c3/return\n"
  );
  // check that code in test-foo ran (implicitly called by run-tests)
  CHECK_TRACE_CONTENTS(
      "run: 0x00000007 opcode: 01\n"
  );
}

void create_test_function(program& p) {
  if (p.segments.empty()) return;
  segment& code = *find(p, "code");
  trace(3, "transform") << "-- create 'run-tests'" << end();
  vector<line> new_insts;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (*curr.data.rbegin() != ':') continue;  // not a label
      if (!starts_with(curr.data, "test-")) continue;
      string fn = drop_last(curr.data);
      new_insts.push_back(call(fn));
    }
  }
  if (new_insts.empty()) return;  // no tests found
  code.lines.push_back(label("run-tests"));
  code.lines.insert(code.lines.end(), new_insts.begin(), new_insts.end());
  code.lines.push_back(ret());
}

string to_string(const segment& s) {
  ostringstream out;
  for (int i = 0;  i < SIZE(s.lines);  ++i) {
    const line& l = s.lines.at(i);
    for (int j = 0;  j < SIZE(l.words);  ++j) {
      if (j > 0) out << ' ';
      out << to_string(l.words.at(j));
    }
    out << '\n';
  }
  return out.str();
}

line call(string s) {
  line result;
  result.words.push_back(call());
  result.words.push_back(disp32(s));
  return result;
}

word call() {
  word result;
  result.data = "e8";
  result.metadata.push_back("call");
  return result;
}

word disp32(string s) {
  word result;
  result.data = s;
  result.metadata.push_back("disp32");
  return result;
}

line ret() {
  line result;
  result.words.push_back(word());
  result.words.back().data = "c3";
  result.words.back().metadata.push_back("return");
  return result;
}
