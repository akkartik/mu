//: Clean syntax to manipulate and check the file system in scenarios.
//: Instruction 'assume-resources' implicitly creates a variable called
//: 'resources' that is accessible to later instructions in the scenario.

:(scenarios run_mu_scenario)
:(scenario simple_filesystem)
scenario simple-filesystem [
  local-scope
  assume-resources [
    # file 'a' containing two lines of data
    [a] <- [
      |a bc|
      |de f|
    ]
    # directory 'b' containing two files, 'c' and 'd'
    [b/c] <- []
    [b/d] <- [
      |xyz|
    ]
  ]
  data:&:@:resource <- get *resources, data:offset
  file1:resource <- index *data, 0
  file1-name:text <- get file1, name:offset
  10:@:char/raw <- copy *file1-name
  file1-contents:text <- get file1, contents:offset
  100:@:char/raw <- copy *file1-contents
  file2:resource <- index *data, 1
  file2-name:text <- get file2, name:offset
  30:@:char/raw <- copy *file2-name
  file2-contents:text <- get file2, contents:offset
  40:@:char/raw <- copy *file2-contents
  file3:resource <- index *data, 2
  file3-name:text <- get file3, name:offset
  50:@:char/raw <- copy *file3-name
  file3-contents:text <- get file3, contents:offset
  60:@:char/raw <- copy *file3-contents
  memory-should-contain [
    10:array:character <- [a]
    100:array:character <- [a bc
de f
]
    30:array:character <- [b/c]
    40:array:character <- []
    50:array:character <- [b/d]
    60:array:character <- [xyz
]
  ]
]

:(scenario escaping_file_contents)
scenario escaping-file-contents [
  local-scope
  assume-resources [
    # file 'a' containing a '|'
    # need to escape '\' once for each block
    [a] <- [
      |x\\\\|yz|
    ]
  ]
  data:&:@:resource <- get *resources, data:offset
  file1:resource <- index *data, 0
  file1-name:text <- get file1, name:offset
  10:@:char/raw <- copy *file1-name
  file1-contents:text <- get file1, contents:offset
  20:@:char/raw <- copy *file1-contents
  memory-should-contain [
    10:array:character <- [a]
    20:array:character <- [x|yz
]
  ]
]

:(before "End Globals")
extern const int RESOURCES = Next_predefined_global_for_scenarios++;
//: give 'resources' a fixed location in scenarios
:(before "End Special Scenario Variable Names(r)")
Name[r]["resources"] = RESOURCES;
//: make 'resources' always a raw location in scenarios
:(before "End is_special_name Cases")
if (s == "resources") return true;
:(before "End Initialize Type Of Special Name In Scenario(r)")
if (r.name == "resources") r.type = new_type_tree("address:resources");

:(before "End initialize_transform_rewrite_literal_string_to_text()")
recipes_taking_literal_strings.insert("assume-resources");

//: screen-should-contain is a regular instruction
:(before "End Primitive Recipe Declarations")
ASSUME_RESOURCES,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "assume-resources", ASSUME_RESOURCES);
:(before "End Primitive Recipe Checks")
case ASSUME_RESOURCES: {
  break;
}
:(before "End Primitive Recipe Implementations")
case ASSUME_RESOURCES: {
  assert(scalar(ingredients.at(0)));
  assume_resources(current_instruction().ingredients.at(0).name, current_recipe_name());
  break;
}

:(code)
void assume_resources(const string& data, const string& caller) {
  map<string, string> contents;
  parse_resources(data, contents, caller);
  construct_resources_object(contents);
}

void parse_resources(const string& data, map<string, string>& out, const string& caller) {
  istringstream in(data);
  in >> std::noskipws;
  while (true) {
    if (!has_data(in)) break;
    skip_whitespace_and_comments(in);
    if (!has_data(in)) break;
    string filename = next_word(in);
    if (filename.empty()) {
      assert(!has_data(in));
      raise << "incomplete 'resources' block at end of file (0)\n" << end();
      return;
    }
    if (*filename.begin() != '[') {
      raise << caller << ": assume-resources: filename '" << filename << "' must begin with a '['\n" << end();
      break;
    }
    if (*filename.rbegin() != ']') {
      raise << caller << ": assume-resources: filename '" << filename << "' must end with a ']'\n" << end();
      break;
    }
    filename.erase(0, 1);
    filename.erase(SIZE(filename)-1);
    if (!has_data(in)) {
      raise << caller << ": assume-resources: no data for filename '" << filename << "'\n" << end();
      break;
    }
    string arrow = next_word(in);
    if (arrow.empty()) {
      assert(!has_data(in));
      raise << "incomplete 'resources' block at end of file (1)\n" << end();
      return;
    }
    if (arrow != "<-") {
      raise << caller << ": assume-resources: expected '<-' after filename '" << filename << "' but got '" << arrow << "'\n" << end();
      break;
    }
    if (!has_data(in)) {
      raise << caller << ": assume-resources: no data for filename '" << filename << "' after '<-'\n" << end();
      break;
    }
    string contents = next_word(in);
    if (contents.empty()) {
      assert(!has_data(in));
      raise << "incomplete 'resources' block at end of file (2)\n" << end();
      return;
    }
    if (*contents.begin() != '[') {
      raise << caller << ": assume-resources: file contents '" << contents << "' for filename '" << filename << "' must begin with a '['\n" << end();
      break;
    }
    if (*contents.rbegin() != ']') {
      raise << caller << ": assume-resources: file contents '" << contents << "' for filename '" << filename << "' must end with a ']'\n" << end();
      break;
    }
    contents.erase(0, 1);
    contents.erase(SIZE(contents)-1);
    put(out, filename, munge_resources_contents(contents, filename, caller));
  }
}

string munge_resources_contents(const string& data, const string& filename, const string& caller) {
  if (data.empty()) return "";
  istringstream in(data);
  in >> std::noskipws;
  skip_whitespace_and_comments(in);
  ostringstream out;
  while (true) {
    if (!has_data(in)) break;
    skip_whitespace(in);
    if (!has_data(in)) break;
    if (in.peek() != '|') {
      raise << caller << ": assume-resources: file contents for filename '" << filename << "' must be delimited in '|'s\n" << end();
      break;
    }
    in.get();  // skip leading '|'
    string line;
    getline(in, line);
    for (int i = 0;  i < SIZE(line);  ++i) {
      if (line.at(i) == '|') break;
      if (line.at(i) == '\\') {
        ++i;  // skip
        if (i == SIZE(line)) {
          raise << caller << ": assume-resources: file contents can't end a line with '\\'\n" << end();
          break;
        }
      }
      out << line.at(i);
    }
    // todo: some way to represent a file without a final newline
    out << '\n';
  }
  return out.str();
}

void construct_resources_object(const map<string, string>& contents) {
  int resources_data_address = allocate(SIZE(contents)*2 + /*array length*/1);
  int curr = resources_data_address + /*skip refcount and length*/2;
  for (map<string, string>::const_iterator p = contents.begin();  p != contents.end();  ++p) {
    put(Memory, curr, new_mu_text(p->first));
    trace(9999, "mem") << "storing file name " << get(Memory, curr) << " in location " << curr << end();
    put(Memory, get(Memory, curr), 1);
    trace(9999, "mem") << "storing refcount 1 in location " << get(Memory, curr) << end();
    ++curr;
    put(Memory, curr, new_mu_text(p->second));
    trace(9999, "mem") << "storing file contents " << get(Memory, curr) << " in location " << curr << end();
    put(Memory, get(Memory, curr), 1);
    trace(9999, "mem") << "storing refcount 1 in location " << get(Memory, curr) << end();
    ++curr;
  }
  curr = resources_data_address+/*skip refcount*/1;
  put(Memory, curr, SIZE(contents));  // size of array
  trace(9999, "mem") << "storing resources size " << get(Memory, curr) << " in location " << curr << end();
  put(Memory, resources_data_address, 1);  // initialize refcount
  trace(9999, "mem") << "storing refcount 1 in location " << resources_data_address << end();
  // wrap the resources data in a 'resources' object
  int resources_address = allocate(size_of_resources());
  curr = resources_address+/*skip refcount*/1+/*offset of 'data' element*/1;
  put(Memory, curr, resources_data_address);
  trace(9999, "mem") << "storing resources data address " << resources_data_address << " in location " << curr << end();
  put(Memory, resources_address, 1);  // initialize refcount
  trace(9999, "mem") << "storing refcount 1 in location " << resources_address << end();
  // save in product
  put(Memory, RESOURCES, resources_address);
  trace(9999, "mem") << "storing resources address " << resources_address << " in location " << RESOURCES << end();
}

int size_of_resources() {
  // memoize result if already computed
  static int result = 0;
  if (result) return result;
  assert(get(Type_ordinal, "resources"));
  type_tree* type = new type_tree("resources");
  result = size_of(type)+/*refcount*/1;
  delete type;
  return result;
}

void skip_whitespace(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    if (isspace(in.peek())) in.get();
    else break;
  }
}
