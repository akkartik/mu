void test_trace_check_compares() {
  trace("test layer") << "foo" << end();
  CHECK_TRACE_CONTENTS("test layer: foo");
}

void test_trace_check_ignores_other_layers() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 2") << "bar" << end();
  CHECK_TRACE_CONTENTS("test layer 1: foo");
  CHECK_TRACE_DOESNT_CONTAIN("test layer 2: foo");
}

void test_trace_check_ignores_leading_whitespace() {
  trace("test layer 1") << " foo" << end();
  CHECK_EQ(trace_count("test layer 1", /*too little whitespace*/"foo"), 1);
  CHECK_EQ(trace_count("test layer 1", /*too much whitespace*/"  foo"), 1);
}

void test_trace_check_ignores_other_lines() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 1") << "bar" << end();
  CHECK_TRACE_CONTENTS("test layer 1: foo");
}

void test_trace_check_ignores_other_lines2() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 1") << "bar" << end();
  CHECK_TRACE_CONTENTS("test layer 1: bar");
}

void test_trace_ignores_trailing_whitespace() {
  trace("test layer 1") << "foo\n" << end();
  CHECK_TRACE_CONTENTS("test layer 1: foo");
}

void test_trace_ignores_trailing_whitespace2() {
  trace("test layer 1") << "foo " << end();
  CHECK_TRACE_CONTENTS("test layer 1: foo");
}

void test_trace_orders_across_layers() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 2") << "bar" << end();
  trace("test layer 1") << "qux" << end();
  CHECK_TRACE_CONTENTS("test layer 1: foo\n"
                       "test layer 2: bar\n"
                       "test layer 1: qux\n");
}

void test_trace_supports_count() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 1") << "foo" << end();
  CHECK_EQ(trace_count("test layer 1", "foo"), 2);
}

void test_trace_supports_count2() {
  trace("test layer 1") << "foo" << end();
  trace("test layer 1") << "bar" << end();
  CHECK_EQ(trace_count("test layer 1"), 2);
}

void test_trace_count_ignores_trailing_whitespace() {
  trace("test layer 1") << "foo\n" << end();
  CHECK_EQ(trace_count("test layer 1", "foo"), 1);
}

void test_trace_unescapes_newlines() {
  trace("test layer 1") << "f\no\no\n" << end();
  CHECK_TRACE_CONTENTS("test layer 1: f\\no\\no");
}

// pending: DUMP tests
// pending: readable_contents() adds newline if necessary.
// pending: raise also prints to stderr.
// pending: raise doesn't print to stderr if Hide_errors is set.
// pending: warn doesn't print to stderr if Hide_errors is set.
// pending: warn doesn't print to stderr if Hide_warnings is set.
// pending: raise doesn't have to be saved if Hide_errors is set, just printed.
// pending: raise prints to stderr if Trace_stream is NULL.
// pending: raise prints to stderr if Trace_stream is NULL even if Hide_errors is set.

// can't check trace because trace methods call 'split'

void test_split_returns_at_least_one_elem() {
  vector<string> result = split("", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result.at(0), "");
}

void test_split_returns_entire_input_when_no_delim() {
  vector<string> result = split("abc", ",");
  CHECK_EQ(result.size(), 1);
  CHECK_EQ(result.at(0), "abc");
}

void test_split_works() {
  vector<string> result = split("abc,def", ",");
  CHECK_EQ(result.size(), 2);
  CHECK_EQ(result.at(0), "abc");
  CHECK_EQ(result.at(1), "def");
}

void test_split_works2() {
  vector<string> result = split("abc,def,ghi", ",");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result.at(0), "abc");
  CHECK_EQ(result.at(1), "def");
  CHECK_EQ(result.at(2), "ghi");
}

void test_split_handles_multichar_delim() {
  vector<string> result = split("abc,,def,,ghi", ",,");
  CHECK_EQ(result.size(), 3);
  CHECK_EQ(result.at(0), "abc");
  CHECK_EQ(result.at(1), "def");
  CHECK_EQ(result.at(2), "ghi");
}

void test_trim() {
  CHECK_EQ(trim(""), "");
  CHECK_EQ(trim(" "), "");
  CHECK_EQ(trim("  "), "");
  CHECK_EQ(trim("a"), "a");
  CHECK_EQ(trim(" a"), "a");
  CHECK_EQ(trim("  a"), "a");
  CHECK_EQ(trim("  ab"), "ab");
  CHECK_EQ(trim("a "), "a");
  CHECK_EQ(trim("a  "), "a");
  CHECK_EQ(trim("ab  "), "ab");
  CHECK_EQ(trim(" a "), "a");
  CHECK_EQ(trim("  a  "), "a");
  CHECK_EQ(trim("  ab  "), "ab");
}
