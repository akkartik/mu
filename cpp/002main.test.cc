void test_parse() {
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  CHECK(Recipe_number.find("main") != Recipe_number.end());
  recipe r = Recipe[Recipe_number["main"]];
  vector<instruction>::iterator i = r.step.begin();
  CHECK_EQ(i->is_label, false);
  CHECK_EQ(i->label, "");
  CHECK_EQ(i->operation, Recipe_number["copy"]);
  CHECK_EQ(i->ingredients.size(), 1);
  CHECK_EQ(i->ingredients[0].name, string("23"));
  CHECK_EQ(i->ingredients[0].types.size(), 1);
  CHECK_EQ(i->ingredients[0].types[0], Type_number["literal"]);
  CHECK_EQ(i->ingredients[0].properties.size(), 0);
  CHECK_EQ(i->products.size(), 1);
  CHECK_EQ(i->products[0].name, string("1"));
  CHECK_EQ(i->products[0].types.size(), 1);
  CHECK_EQ(i->products[0].types[0], Type_number["integer"]);
  CHECK_EQ(i->products[0].properties.size(), 0);
}

void test_parse2() {
  compile("recipe main [\n"
          "  1:integer, 2:integer <- copy 23:literal\n"
          "]\n");
  CHECK(Recipe_number.find("main") != Recipe_number.end());
  recipe r = Recipe[Recipe_number["main"]];
  vector<instruction>::iterator i = r.step.begin();
  CHECK_EQ(i->is_label, false);
  CHECK_EQ(i->label, "");
  CHECK_EQ(i->operation, Recipe_number["copy"]);
  CHECK_EQ(i->ingredients.size(), 1);
  CHECK_EQ(i->ingredients[0].name, string("23"));
  CHECK_EQ(i->ingredients[0].types.size(), 1);
  CHECK_EQ(i->ingredients[0].types[0], Type_number["literal"]);
  CHECK_EQ(i->ingredients[0].properties.size(), 0);
  CHECK_EQ(i->products.size(), 2);
  CHECK_EQ(i->products[0].name, string("1"));
  CHECK_EQ(i->products[0].types.size(), 1);
  CHECK_EQ(i->products[0].types[0], Type_number["integer"]);
  CHECK_EQ(i->products[0].properties.size(), 0);
  CHECK_EQ(i->products[1].name, string("2"));
  CHECK_EQ(i->products[1].types.size(), 1);
  CHECK_EQ(i->products[1].types[0], Type_number["integer"]);
  CHECK_EQ(i->products[1].properties.size(), 0);
}

void test_literal() {
  compile("recipe main [\n"
          "  1:integer <- copy 23:literal\n"
          "]\n");
  run("main");
  CHECK_EQ(Memory[1], 23);
}
