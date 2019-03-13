void test_tangle() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_with_linenumber() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "#line 1\n"
                                 "a\n"
                                 "#line 5\n"
                                 "d\n"
                                 "#line 2\n"
                                 "b\n"
                                 "c\n");
  // no other #line directives
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "#line 3");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "#line 4");
}

void test_tangle_linenumbers_with_filename() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, "foo", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 5 \"foo\"\n"
                                 "d\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_line_numbers_with_multiple_filenames() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(before b)\n"
                    "d\n");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 2 \"foo\"\n"
                                 "b\n"
                                 "c\n");
}

void test_tangle_linenumbers_with_multiple_directives() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(before b)\n"
                    "d\n"
                    ":(before c)\n"
                    "e");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 2 \"foo\"\n"
                                 "b\n"
                                 "#line 4 \"bar\"\n"
                                 "e\n"
                                 "#line 3 \"foo\"\n"
                                 "c\n");
}

void test_tangle_with_multiple_filenames_after() {
  istringstream in1("a\n"
                    "b\n"
                    "c");
  list<Line> dummy;
  tangle(in1, "foo", dummy);
  CLEAR_TRACE;
  istringstream in2(":(after b)\n"
                    "d\n");
  tangle(in2, "bar", dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "#line 2 \"bar\"\n"
                                 "d\n"
                                 "#line 3 \"foo\"\n"
                                 "c\n");
}

void test_tangle_skip_tanglecomments() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   "//: 1\n"
                   "//: 2\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "c\n"
                                 "\n"
                                 "\n"
                                 "d\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_tanglecomments_and_directive() {
  istringstream in("a\n"
                   "//: 1\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n"
                   ":(code)\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 6\n"
                                 "d\n"
                                 "#line 3\n"
                                 "b\n"
                                 "c\n"
                                 "#line 8\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_tanglecomments_inside_directive() {
  istringstream in("a\n"
                   "//: 1\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "//: abc\n"
                   "d\n"
                   ":(code)\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "#line 7\n"
                                 "d\n"
                                 "#line 3\n"
                                 "b\n"
                                 "c\n"
                                 "#line 9\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_multiword_directives() {
  istringstream in("a b\n"
                   "c\n"
                   ":(after \"a b\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a b\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle_with_quoted_multiword_directives() {
  istringstream in("a \"b\"\n"
                   "c\n"
                   ":(after \"a \\\"b\\\"\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a \"b\"\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle2() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "d\n"
                                 "c\n");
}

void test_tangle_at_end() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after c)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "b\n"
                                 "c\n"
                                 "d\n");
}

void test_tangle_indents_hunks_correctly() {
  istringstream in("a\n"
                   "  b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "  b\n"
                                 "  d\n"
                                 "c\n");
}

void test_tangle_warns_on_missing_target() {
  Hide_warnings = true;
  istringstream in(":(before)\n"
                   "abc def\n");
  list<Line> lines;
  tangle(in, lines);
  CHECK_TRACE_WARNS();
}

void test_tangle_warns_on_unknown_target() {
  Hide_warnings = true;
  istringstream in(":(before \"foo\")\n"
                   "abc def\n");
  list<Line> lines;
  tangle(in, lines);
  CHECK_TRACE_WARNS();
}

void test_tangle_delete_range_of_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(delete{} \"b\")\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "c");
}

void test_tangle_replace() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(replace b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "c\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b");
}

void test_tangle_replace_range_of_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(replace{} \"b\")\n"
                   "d\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b {");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "c");
}

void test_tangle_replace_tracks_old_lines() {
  istringstream in("a\n"
                   "b {\n"
                   "c\n"
                   "}\n"
                   ":(replace{} \"b\")\n"
                   "d\n"
                   ":OLD_CONTENTS\n"
                   "e\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "d\n"
                                 "c\n"
                                 "e\n");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "b {");
}

void test_tangle_nested_patterns() {
  istringstream in("a\n"
                   "c\n"
                   "b\n"
                   "c\n"
                   "d\n"
                   ":(after \"b\" then \"c\")\n"
                   "e");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "c\n"
                                 "b\n"
                                 "c\n"
                                 "e\n"
                                 "d\n");
}

void test_tangle_nested_patterns2() {
  istringstream in("a\n"
                   "c\n"
                   "b\n"
                   "c\n"
                   "d\n"
                   ":(after \"c\" following \"b\")\n"
                   "e");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a\n"
                                 "c\n"
                                 "b\n"
                                 "c\n"
                                 "e\n"
                                 "d\n");
}

// todo: include line numbers in tangle errors

//// helpers

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

void test_strip_indent() {
  CHECK_EQ(strip_indent("", 0), "");
  CHECK_EQ(strip_indent("", 1), "");
  CHECK_EQ(strip_indent("", 3), "");
  CHECK_EQ(strip_indent(" ", 0), " ");
  CHECK_EQ(strip_indent(" a", 0), " a");
  CHECK_EQ(strip_indent(" ", 1), "");
  CHECK_EQ(strip_indent(" a", 1), "a");
  CHECK_EQ(strip_indent(" ", 2), "");
  CHECK_EQ(strip_indent(" a", 2), "a");
  CHECK_EQ(strip_indent("  ", 0), "  ");
  CHECK_EQ(strip_indent("  a", 0), "  a");
  CHECK_EQ(strip_indent("  ", 1), " ");
  CHECK_EQ(strip_indent("  a", 1), " a");
  CHECK_EQ(strip_indent("  ", 2), "");
  CHECK_EQ(strip_indent("  a", 2), "a");
  CHECK_EQ(strip_indent("  ", 3), "");
  CHECK_EQ(strip_indent("  a", 3), "a");
}
