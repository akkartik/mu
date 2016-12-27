void test_trace_check_compares() {
  CHECK_TRACE_CONTENTS("test layer", "");
  trace("test layer") << "foo";
  CHECK_TRACE_CONTENTS("test layer", "foo");
}

void test_trace_check_filters_layers() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  CHECK_TRACE_CONTENTS("test layer 1", "foo");
}

void test_trace_check_ignores_other_lines() {
  trace("test layer 1") << "foo";
  trace("test layer 1") << "bar";
  CHECK_TRACE_CONTENTS("test layer 1", "foo");
}

void test_trace_check_always_finds_empty_lines() {
  CHECK_TRACE_CONTENTS("test layer 1", "");
}

void test_trace_check_treats_empty_layers_as_wildcards() {
  trace("test layer 1") << "foo";
  CHECK_TRACE_CONTENTS("", "foo");
}

void test_trace_check_multiple_lines_at_once() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  CHECK_TRACE_CONTENTS("", "foobar");
}

void test_trace_check_always_finds_empty_lines2() {
  CHECK_TRACE_CONTENTS("test layer 1", "");
}

void test_trace_orders_across_layers() {
  trace("test layer 1") << "foo";
  trace("test layer 2") << "bar";
  trace("test layer 1") << "qux";
  CHECK_TRACE_CONTENTS("", "foobarqux");
}

void test_trace_supports_count() {
  trace("test layer 1") << "foo";
  trace("test layer 1") << "foo";
  CHECK_EQ(trace_count("test layer 1", "foo"), 2);
}

//// helpers

// can't check trace because trace methods call 'split'

void test_split_returns_at_least_one_elem() {
  vector<string> result = split("", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result[0], "");
}

void test_split_returns_entire_input_when_no_delim() {
  vector<string> result = split("abc", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result[0], "abc");
}

void test_split_works() {
  vector<string> result = split("abc,def", ",");
  CHECK_EQ(result.size(), 2);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
}

void test_split_works2() {
  vector<string> result = split("abc,def,ghi", ",");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
  CHECK_EQ(result[2], "ghi");
}

void test_split_handles_multichar_delim() {
  vector<string> result = split("abc,,def,,ghi", ",,");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result[0], "abc");
  CHECK_EQ(result[1], "def");
  CHECK_EQ(result[2], "ghi");
}
