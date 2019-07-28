//: Extend 'new' to handle a unicode string literal argument or 'text'.

//: A Mu text is an address to an array of characters.
:(before "End Mu Types Initialization")
put(Type_abbreviations, "text", new_type_tree("&:@:character"));

:(code)
void test_new_string() {
  run(
      "def main [\n"
      "  10:text <- new [abc def]\n"
      "  20:char <- index *10:text, 5\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // number code for 'e'
      "mem: storing 101 in location 20\n"
  );
}

void test_new_string_handles_unicode() {
  run(
      "def main [\n"
      "  10:text <- new [a«c]\n"
      "  20:num <- length *10:text\n"
      "  21:char <- index *10:text, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 20\n"
      // unicode for '«'
      "mem: storing 171 in location 21\n"
  );
}

:(before "End NEW Check Special-cases")
if (is_literal_text(inst.ingredients.at(0))) break;
:(before "Convert 'new' To 'allocate'")
if (inst.name == "new" && !inst.ingredients.empty() && is_literal_text(inst.ingredients.at(0))) continue;
:(after "case NEW" following "Primitive Recipe Implementations")
  if (is_literal_text(current_instruction().ingredients.at(0))) {
    products.resize(1);
    products.at(0).push_back(/*alloc id*/0);
    products.at(0).push_back(new_mu_text(current_instruction().ingredients.at(0).name));
    trace(Callstack_depth+1, "mem") << "new string alloc: " << products.at(0).at(0) << end();
    break;
  }

:(code)
int new_mu_text(const string& contents) {
  // allocate an array just large enough for it
  int string_length = unicode_length(contents);
//?   Total_alloc += string_length+1;
//?   ++Num_alloc;
  int result = allocate(/*array length*/1 + string_length);
  int curr_address = result;
  ++curr_address;  // skip alloc id
  trace(Callstack_depth+1, "mem") << "storing string length " << string_length << " in location " << curr_address << end();
  put(Memory, curr_address, string_length);
  ++curr_address;  // skip length
  int curr = 0;
  const char* raw_contents = contents.c_str();
  for (int i = 0;  i < string_length;  ++i) {
    uint32_t curr_character;
    assert(curr < SIZE(contents));
    tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
    trace(Callstack_depth+1, "mem") << "storing string character " << curr_character << " in location " << curr_address << end();
    put(Memory, curr_address, curr_character);
    curr += tb_utf8_char_length(raw_contents[curr]);
    ++curr_address;
  }
  // Mu strings are not null-terminated in memory.
  return result;
}

//: a new kind of typo

void test_literal_text_without_instruction() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  [abc]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: instruction '[abc]' has no recipe in '[abc]'\n"
  );
}

//: stash recognizes texts

void test_stash_text() {
  run(
      "def main [\n"
      "  1:text <- new [abc]\n"
      "  stash [foo:], 1:text\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: foo: abc\n"
  );
}

:(before "End inspect Special-cases(r, data)")
if (is_mu_text(r)) {
  return read_mu_text(data.at(/*skip alloc id*/1));
}

:(before "End $print Special-cases")
else if (is_mu_text(current_instruction().ingredients.at(i))) {
  cout << read_mu_text(ingredients.at(i).at(/*skip alloc id*/1));
}

:(code)
void test_unicode_text() {
  run(
      "def main [\n"
      "  1:text <- new [♠]\n"
      "  stash [foo:], 1:text\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: foo: ♠\n"
  );
}

void test_stash_space_after_text() {
  run(
      "def main [\n"
      "  1:text <- new [abc]\n"
      "  stash 1:text, [foo]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: abc foo\n"
  );
}

void test_stash_text_as_array() {
  run(
      "def main [\n"
      "  1:text <- new [abc]\n"
      "  stash *1:text\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: 3 97 98 99\n"
  );
}

//: fixes way more than just stash
:(before "End Preprocess is_mu_text(reagent x)")
if (!canonize_type(x)) return false;

//: Allocate more to routine when initializing a literal text
:(code)
void test_new_text_overflow() {
  Initial_memory_per_routine = 3;
  run(
      "def main [\n"
      "  10:&:num/raw <- new number:type\n"
      "  20:text/raw <- new [a]\n"  // not enough room in initial page, if you take the array length into account
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "new: routine allocated memory from 1000 to 1003\n"
      "new: routine allocated memory from 1003 to 1006\n"
  );
}

//: helpers
:(code)
int unicode_length(const string& s) {
  const char* in = s.c_str();
  int result = 0;
  int curr = 0;
  while (curr < SIZE(s)) {  // carefully bounds-check on the string
    // before accessing its raw pointer
    ++result;
    curr += tb_utf8_char_length(in[curr]);
  }
  return result;
}

string read_mu_text(int address) {
  if (address == 0) return "";
  int length = get_or_insert(Memory, address+/*alloc id*/1);
  if (length == 0) return "";
  return read_mu_characters(address+/*alloc id*/1+/*length*/1, length);
}

string read_mu_characters(int start, int length) {
  ostringstream tmp;
  for (int curr = start;  curr < start+length;  ++curr)
    tmp << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
  return tmp.str();
}

//:: some miscellaneous helpers now that we have text

//: assert: perform sanity checks at runtime

void test_assert_literal() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  assert 0, [this is an assert in Mu]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: this is an assert in Mu\n"
  );
}

void test_assert() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:text <- new [this is an assert in Mu]\n"
      "  assert 0, 1:text\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: this is an assert in Mu\n"
  );
}

:(before "End Primitive Recipe Declarations")
ASSERT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "assert", ASSERT);
:(before "End Primitive Recipe Checks")
case ASSERT: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'assert' takes exactly two ingredients rather than '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_address(inst.ingredients.at(0)) && !is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'assert' requires a scalar or address for its first ingredient, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  if (!is_literal_text(inst.ingredients.at(1)) && !is_mu_text(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "'assert' requires a text as its second ingredient, but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ASSERT: {
  if (!scalar_ingredient(ingredients, 0)) {
    if (is_literal_text(current_instruction().ingredients.at(1)))
      raise << current_instruction().ingredients.at(1).name << '\n' << end();
    else
      raise << read_mu_text(ingredients.at(1).at(/*skip alloc id*/1)) << '\n' << end();
    if (!Hide_errors) exit(1);
  }
  break;
}

//: 'cheating' by using the host system

:(before "End Primitive Recipe Declarations")
_READ,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$read", _READ);
:(before "End Primitive Recipe Checks")
case _READ: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _READ: {
  skip_whitespace(cin);
  string result;
  if (has_data(cin))
    cin >> result;
  products.resize(1);
  products.at(0).push_back(new_mu_text(result));
  break;
}

:(code)
void skip_whitespace(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    if (isspace(in.peek())) in.get();
    else break;
  }
}
