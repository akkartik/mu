//: Extend 'new' to handle a unicode string literal argument or 'text'.

//: A Mu text is an address to an array of characters.
:(before "End Mu Types Initialization")
put(Type_abbreviations, "text", new_type_tree("address:array:character"));

:(scenario new_string)
def main [
  1:text <- new [abc def]
  2:char <- index *1:text, 5
]
# number code for 'e'
+mem: storing 101 in location 2

:(scenario new_string_handles_unicode)
def main [
  1:text <- new [a«c]
  2:num <- length *1:text
  3:char <- index *1:text, 1
]
+mem: storing 3 in location 2
# unicode for '«'
+mem: storing 171 in location 3

:(before "End NEW Check Special-cases")
if (is_literal_text(inst.ingredients.at(0))) break;
:(before "Convert 'new' To 'allocate'")
if (inst.name == "new" && is_literal_text(inst.ingredients.at(0))) continue;
:(after "case NEW" following "Primitive Recipe Implementations")
  if (is_literal_text(current_instruction().ingredients.at(0))) {
    products.resize(1);
    products.at(0).push_back(new_mu_text(current_instruction().ingredients.at(0).name));
    trace(9999, "mem") << "new string alloc: " << products.at(0).at(0) << end();
    break;
  }

:(code)
int new_mu_text(const string& contents) {
  // allocate an array just large enough for it
  int string_length = unicode_length(contents);
//?   Total_alloc += string_length+1;
//?   ++Num_alloc;
  int result = allocate(string_length+/*array length*/1);
  trace(9999, "mem") << "storing string refcount 0 in location " << result << end();
  put(Memory, result, 0);
  int curr_address = result+/*skip refcount*/1;
  trace(9999, "mem") << "storing string length " << string_length << " in location " << curr_address << end();
  put(Memory, curr_address, string_length);
  ++curr_address;  // skip length
  int curr = 0;
  const char* raw_contents = contents.c_str();
  for (int i = 0;  i < string_length;  ++i) {
    uint32_t curr_character;
    assert(curr < SIZE(contents));
    tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
    trace(9999, "mem") << "storing string character " << curr_character << " in location " << curr_address << end();
    put(Memory, curr_address, curr_character);
    curr += tb_utf8_char_length(raw_contents[curr]);
    ++curr_address;
  }
  // Mu strings are not null-terminated in memory.
  return result;
}

//: a new kind of typo

:(scenario string_literal_without_instruction)
% Hide_errors = true;
def main [
  [abc]
]
+error: main: instruction '[abc]' has no recipe in '[abc]'

//: stash recognizes strings

:(scenario stash_string)
def main [
  1:text <- new [abc]
  stash [foo:], 1:text
]
+app: foo: abc

:(before "End inspect Special-cases(r, data)")
if (is_mu_text(r)) {
  assert(scalar(data));
  return read_mu_text(data.at(0));
}

:(before "End $print Special-cases")
else if (is_mu_text(current_instruction().ingredients.at(i))) {
  cout << read_mu_text(ingredients.at(i).at(0));
}

:(scenario unicode_string)
def main [
  1:text <- new [♠]
  stash [foo:], 1:text
]
+app: foo: ♠

:(scenario stash_space_after_string)
def main [
  1:text <- new [abc]
  stash 1:text, [foo]
]
+app: abc foo

:(scenario stash_string_as_array)
def main [
  1:text <- new [abc]
  stash *1:text
]
+app: 3 97 98 99

//: fixes way more than just stash
:(before "End Preprocess is_mu_text(reagent x)")
if (!canonize_type(x)) return false;

//: Allocate more to routine when initializing a literal string
:(scenario new_string_overflow)
% Initial_memory_per_routine = 3;
def main [
  1:address:num/raw <- new number:type
  2:text/raw <- new [a]  # not enough room in initial page, if you take the refcount and array length into account
]
+new: routine allocated memory from 1000 to 1003
+new: routine allocated memory from 1003 to 1006

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
  ++address;  // skip refcount
  int size = get_or_insert(Memory, address);
  if (size == 0) return "";
  ostringstream tmp;
  for (int curr = address+1;  curr <= address+size;  ++curr) {
    tmp << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
  }
  return tmp.str();
}

//:: some miscellaneous helpers now that we have text

//: assert: perform sanity checks at runtime

:(scenario assert)
% Hide_errors = true;  // '%' lines insert arbitrary C code into tests before calling 'run' with the lines below. Must be immediately after :(scenario) line.
def main [
  assert 0, [this is an assert in Mu]
]
+error: this is an assert in Mu

:(before "End Primitive Recipe Declarations")
ASSERT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "assert", ASSERT);
:(before "End Primitive Recipe Checks")
case ASSERT: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'assert' takes exactly two ingredients rather than '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_scalar(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'assert' requires a boolean for its first ingredient, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
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
  if (!ingredients.at(0).at(0)) {
    if (is_literal_text(current_instruction().ingredients.at(1)))
      raise << current_instruction().ingredients.at(1).name << '\n' << end();
    else
      raise << read_mu_text(ingredients.at(1).at(0)) << '\n' << end();
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
