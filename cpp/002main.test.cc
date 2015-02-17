TEST(parse)
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  CHECK_TRACE_CONTENTS("parse", "instruction: 1  ingredient: {name: \"23\", type: 0}  product: {name: \"1\", type: 1}");
}

TEST(parse_label)
  compile("recipe main [\n"
          "  foo:\n"
          "]\n");
  CHECK_TRACE_CONTENTS("parse", "label: foo");
  CHECK_TRACE_DOESNT_CONTAIN("parse", "instruction: 1");
}

TEST(parse2)
  compile("recipe main [\n"
          "  1:integer, 2:integer <- copy 23:literal\n"
          "]\n");
  CHECK_TRACE_CONTENTS("parse", "instruction: 1  ingredient: {name: \"23\", type: 0}  product: {name: \"1\", type: 1}  product: {name: \"2\", type: 1}");
}

TEST(literal)
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  run("main");
  CHECK_EQ(Memory[1], 23);
}
