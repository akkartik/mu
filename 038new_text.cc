//: Extend 'new' to handle a unicode string literal argument.

:(scenario new_string)
def main [
  1:address:array:character <- new [abc def]
  2:character <- index *1:address:array:character, 5
]
# number code for 'e'
+mem: storing 101 in location 2

:(scenario new_string_handles_unicode)
def main [
  1:address:array:character <- new [a«c]
  2:number <- length *1:address:array:character
  3:character <- index *1:address:array:character, 1
]
+mem: storing 3 in location 2
# unicode for '«'
+mem: storing 171 in location 3

:(before "End NEW Check Special-cases")
if (is_literal_string(inst.ingredients.at(0))) break;
:(before "Convert 'new' To 'allocate'")
if (inst.name == "new" && is_literal_string(inst.ingredients.at(0))) continue;
:(after "case NEW" following "Primitive Recipe Implementations")
  if (is_literal_string(current_instruction().ingredients.at(0))) {
    products.resize(1);
    products.at(0).push_back(new_mu_string(current_instruction().ingredients.at(0).name));
    trace(9999, "mem") << "new string alloc: " << products.at(0).at(0) << end();
    break;
  }

:(code)
int new_mu_string(const string& contents) {
  // allocate an array just large enough for it
  int string_length = unicode_length(contents);
//?   Total_alloc += string_length+1;
//?   Num_alloc++;
  ensure_space(string_length+1);  // don't forget the extra location for array size
  // initialize string
  int result = Current_routine->alloc;
  // initialize refcount
  put(Memory, Current_routine->alloc++, 0);
  // store length
  put(Memory, Current_routine->alloc++, string_length);
  int curr = 0;
  const char* raw_contents = contents.c_str();
  for (int i = 0; i < string_length; ++i) {
    uint32_t curr_character;
    assert(curr < SIZE(contents));
    tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
    put(Memory, Current_routine->alloc, curr_character);
    curr += tb_utf8_char_length(raw_contents[curr]);
    ++Current_routine->alloc;
  }
  // mu strings are not null-terminated in memory
  return result;
}

//: stash recognizes strings

:(scenario stash_string)
def main [
  1:address:array:character <- new [abc]
  stash [foo:], 1:address:array:character
]
+app: foo: abc

:(before "End print Special-cases(r, data)")
if (is_mu_string(r)) {
  assert(scalar(data));
  return read_mu_string(data.at(0));
}

:(scenario unicode_string)
def main [
  1:address:array:character <- new [♠]
  stash [foo:], 1:address:array:character
]
+app: foo: ♠

:(scenario stash_space_after_string)
def main [
  1:address:array:character <- new [abc]
  stash 1:address:array:character, [foo]
]
+app: abc foo

:(scenario stash_string_as_array)
def main [
  1:address:array:character <- new [abc]
  stash *1:address:array:character
]
+app: 3 97 98 99

//: fixes way more than just stash
:(after "Begin is_mu_string(x)")
if (!canonize_type(x)) return false;

//: Allocate more to routine when initializing a literal string
:(scenario new_string_overflow)
% Initial_memory_per_routine = 2;
def main [
  1:address:number/raw <- new number:type
  2:address:array:character/raw <- new [a]  # not enough room in initial page, if you take the array size into account
]
+new: routine allocated memory from 1000 to 1002
+new: routine allocated memory from 1002 to 1004

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

string read_mu_string(int address) {
  if (address == 0) return "";
  address++;  // skip refcount
  int size = get_or_insert(Memory, address);
  if (size == 0) return "";
  ostringstream tmp;
  for (int curr = address+1; curr <= address+size; ++curr) {
    tmp << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
  }
  return tmp.str();
}
