void test_compile() {
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  CHECK(Recipe_number.find("main") != Recipe_number.end());
}

void test_literal() {
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  run("main");
  CHECK_EQ(Memory[1], 23);
}
