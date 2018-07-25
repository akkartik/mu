void test_tangle() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "d"
                                 "b"
                                 "c");
}

void test_tangle_with_linenumber() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(before b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "#line 1"
                                 "a"
                                 "#line 5"
                                 "d"
                                 "#line 2"
                                 "b"
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "#line 5 \"foo\""
                                 "d"
                                 "b"
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "#line 2 \"bar\""
                                 "d"
                                 "#line 2 \"foo\""
                                 "b"
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "#line 2 \"bar\""
                                 "d"
                                 "#line 2 \"foo\""
                                 "b"
                                 "#line 4 \"bar\""
                                 "e"
                                 "#line 3 \"foo\""
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "b"
                                 "#line 2 \"bar\""
                                 "d"
                                 "#line 3 \"foo\""
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "b"
                                 "c"
                                 ""
                                 ""
                                 "d");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "#line 6"
                                 "d"
                                 "#line 3"
                                 "b"
                                 "c"
                                 "#line 8"
                                 "e");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "#line 7"
                                 "d"
                                 "#line 3"
                                 "b"
                                 "c"
                                 "#line 9"
                                 "e");
  CHECK_TRACE_DOESNT_CONTAIN("tangle", "//: 1");
}

void test_tangle_with_multiword_directives() {
  istringstream in("a b\n"
                   "c\n"
                   ":(after \"a b\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a b"
                                 "d"
                                 "c");
}

void test_tangle_with_quoted_multiword_directives() {
  istringstream in("a \"b\"\n"
                   "c\n"
                   ":(after \"a \\\"b\\\"\")\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a \"b\""
                                 "d"
                                 "c");
}

void test_tangle2() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "b"
                                 "d"
                                 "c");
}

void test_tangle_at_end() {
  istringstream in("a\n"
                   "b\n"
                   "c\n"
                   ":(after c)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "b"
                                 "c"
                                 "d");
}

void test_tangle_indents_hunks_correctly() {
  istringstream in("a\n"
                   "  b\n"
                   "c\n"
                   ":(after b)\n"
                   "d\n");
  list<Line> dummy;
  tangle(in, dummy);
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "  b"
                                 "  d"
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "d"
                                 "c");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "d"
                                 "e");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "d"
                                 "c"
                                 "e");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "c"
                                 "b"
                                 "c"
                                 "e"
                                 "d");
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
  CHECK_TRACE_CONTENTS("tangle", "a"
                                 "c"
                                 "b"
                                 "c"
                                 "e"
                                 "d");
}

// todo: include line numbers in tangle errors

//// scenarios

void test_tangle_supports_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "+layer1: pqr\n"
                   "+layer2: xyz");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: xyz\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_ignores_empty_lines_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "+layer1: pqr\n"
                   "  \n"
                   "+layer2: xyz");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: xyz\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_handles_empty_lines_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "\n"
                   "+layer1: pqr\n"
                   "+layer2: xyz");
  list<Line> lines;
  tangle(in, lines);
  // no infinite loop
}

void test_tangle_supports_configurable_toplevel() {
  istringstream in(":(scenarios foo)\n"
                   ":(scenario does_bar)\n"
                   "abc def\n"
                   "+layer1: pqr");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  foo(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());

  istringstream cleanup(":(scenarios run)\n");
  tangle(cleanup, lines);
}

void test_tangle_can_hide_warnings_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "% Hide_warnings = true;\n"
                   "abc def\n"
                   "+layer1: pqr\n"
                   "+layer2: xyz");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  Hide_warnings = true;");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: xyz\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_include_c_code_at_end_of_scenario() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "+layer1: pqr\n"
                   "+layer2: xyz\n"
                   "% int x = 1;");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: xyz\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  int x = 1;");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_include_c_code_at_end_of_scenario_without_trace_expectations() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "% int x = 1;");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  int x = 1;");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_supports_strings_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc \"def\"\n"
                   "+layer1: pqr\n"
                   "+layer2: \"xyz\"");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc \\\"def\\\"\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: \\\"xyz\\\"\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_supports_strings_in_scenarios2() {
  istringstream in(":(scenario does_bar)\n"
                   "abc \"\"\n"
                   "+layer1: pqr\n"
                   "+layer2: \"\"");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc \\\"\\\"\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: \\\"\\\"\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_supports_multiline_input_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "  efg\n"
                   "+layer1: pqr\n"
                   "+layer2: \"\"");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n  efg\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: \\\"\\\"\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_supports_reset_in_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "===\n"
                   "efg\n"
                   "+layer1: pqr\n"
                   "+layer2: \"\"");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CLEAR_TRACE;");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"efg\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer2: \\\"\\\"\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_check_for_absence_at_end_of_scenarios() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "  efg\n"
                   "+layer1: pqr\n"
                   "-layer1: xyz");
  list<Line> lines;
  tangle(in, lines);
//?   for (list<Line>::iterator p = lines.begin();  p != lines.end();  ++p)
//?     cerr << p->contents << '\n';
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n  efg\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_DOESNT_CONTAIN(\"layer1: xyz\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_check_for_absence_at_end_of_scenarios2() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "  efg\n"
                   "-layer1: pqr\n"
                   "-layer1: xyz");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n  efg\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_DOESNT_CONTAIN(\"layer1: pqr\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_DOESNT_CONTAIN(\"layer1: xyz\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_check_for_count_in_scenario() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "  efg\n"
                   "$layer1: 2");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n  efg\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_COUNT(\"layer1\", 2);");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

void test_tangle_can_handle_mu_comments_in_scenario() {
  istringstream in(":(scenario does_bar)\n"
                   "abc def\n"
                   "# comment1\n"
                   "  efg\n"
                   "  # indented comment 2\n"
                   "+layer1: pqr\n"
                   "# comment inside expected_trace\n"
                   "+layer1: xyz\n"
                   "# comment after expected trace\n"
                   "-layer1: z\n"
                   "# comment before trace count\n"
                   "$layer1: 2\n"
                   "# comment at end\n"
                   "\n");
  list<Line> lines;
  tangle(in, lines);
  CHECK_EQ(lines.front().contents, "void test_does_bar() {");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  run(\"abc def\\n# comment1\\n  efg\\n  # indented comment 2\\n\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_CONTENTS(");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: pqr\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "      \"layer1: xyz\"");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  );");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_DOESNT_CONTAIN(\"layer1: z\");");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "  CHECK_TRACE_COUNT(\"layer1\", 2);");  lines.pop_front();
  CHECK_EQ(lines.front().contents, "}");  lines.pop_front();
  CHECK(lines.empty());
}

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
