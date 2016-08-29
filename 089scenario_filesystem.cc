//: Clean syntax to manipulate and check the file system in scenarios.
//: Instructions 'assume-filesystem' and 'filesystem-should-contain' implicitly create
//: a variable called 'filesystem' that is accessible to later instructions in
//: the scenario. 'filesystem-should-contain' can check unicode characters in
//: the fake filesystem

:(scenarios run_mu_scenario)
:(scenario simple_filesystem)
scenario assume-filesystem [
  local-scope
  assume-filesystem [
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
  data:address:array:file-mapping <- get *filesystem:address:filesystem, data:offset
  file1:file-mapping <- index *data, 0
  file1-name:address:array:character <- get file1, name:offset
  10:array:character/raw <- copy *file1-name
  file1-contents:address:array:character <- get file1, contents:offset
  100:array:character/raw <- copy *file1-contents
  file2:file-mapping <- index *data, 1
  file2-name:address:array:character <- get file2, name:offset
  30:array:character/raw <- copy *file2-name
  file2-contents:address:array:character <- get file2, contents:offset
  40:array:character/raw <- copy *file2-contents
  file3:file-mapping <- index *data, 2
  file3-name:address:array:character <- get file3, name:offset
  50:array:character/raw <- copy *file3-name
  file3-contents:address:array:character <- get file3, contents:offset
  60:array:character/raw <- copy *file3-contents
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
scenario assume-filesystem [
  local-scope
  assume-filesystem [
    # file 'a' containing a '|'
    # need to escape '\' once for each block
    [a] <- [
      |x\\\\|yz|
    ]
  ]
  data:address:array:file-mapping <- get *filesystem:address:filesystem, data:offset
  file1:file-mapping <- index *data, 0
  file1-name:address:array:character <- get file1, name:offset
  10:array:character/raw <- copy *file1-name
  file1-contents:address:array:character <- get file1, contents:offset
  20:array:character/raw <- copy *file1-contents
  memory-should-contain [
    10:array:character <- [a]
    20:array:character <- [x|yz
]
  ]
]

:(before "End Globals")
extern const int FILESYSTEM = Next_predefined_global_for_scenarios++;
//: give 'filesystem' a fixed location in scenarios
:(before "End Special Scenario Variable Names(r)")
Name[r]["filesystem"] = FILESYSTEM;
//: make 'filesystem' always a raw location in scenarios
:(before "End is_special_name Cases")
if (s == "filesystem") return true;

:(before "End initialize_transform_rewrite_literal_string_to_text()")
recipes_taking_literal_strings.insert("assume-filesystem");

//: screen-should-contain is a regular instruction
:(before "End Primitive Recipe Declarations")
ASSUME_FILESYSTEM,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "assume-filesystem", ASSUME_FILESYSTEM);
:(before "End Primitive Recipe Checks")
case ASSUME_FILESYSTEM: {
  break;
}
:(before "End Primitive Recipe Implementations")
case ASSUME_FILESYSTEM: {
  assert(scalar(ingredients.at(0)));
  assume_filesystem(current_instruction().ingredients.at(0).name, current_recipe_name());
  break;
}

:(code)
void assume_filesystem(const string& data, const string& caller) {
  map<string, string> contents;
  parse_filesystem(data, contents, caller);
  construct_filesystem_object(contents);
}

void parse_filesystem(const string& data, map<string, string>& out, const string& caller) {
  istringstream in(data);
  in >> std::noskipws;
  while (true) {
    if (!has_data(in)) break;
    skip_whitespace_and_comments(in);
    if (!has_data(in)) break;
    string filename = next_filesystem_word(in);
    if (*filename.begin() != '[') {
      raise << caller << ": assume-filesystem: filename '" << filename << "' must begin with a '['\n" << end();
      break;
    }
    if (*filename.rbegin() != ']') {
      raise << caller << ": assume-filesystem: filename '" << filename << "' must end with a ']'\n" << end();
      break;
    }
    filename.erase(0, 1);
    filename.erase(SIZE(filename)-1);
    if (!has_data(in)) {
      raise << caller << ": assume-filesystem: no data for filename '" << filename << "'\n" << end();
      break;
    }
    string arrow = next_filesystem_word(in);
    if (arrow != "<-") {
      raise << caller << ": assume-filesystem: expected '<-' after filename '" << filename << "' but got '" << arrow << "'\n" << end();
      break;
    }
    if (!has_data(in)) {
      raise << caller << ": assume-filesystem: no data for filename '" << filename << "' after '<-'\n" << end();
      break;
    }
    string contents = next_filesystem_word(in);
    if (*contents.begin() != '[') {
      raise << caller << ": assume-filesystem: file contents '" << contents << "' for filename '" << filename << "' must begin with a '['\n" << end();
      break;
    }
    if (*contents.rbegin() != ']') {
      raise << caller << ": assume-filesystem: file contents '" << contents << "' for filename '" << filename << "' must end with a ']'\n" << end();
      break;
    }
    contents.erase(0, 1);
    contents.erase(SIZE(contents)-1);
    put(out, filename, munge_filesystem_contents(contents, filename, caller));
  }
}

string munge_filesystem_contents(const string& data, const string& filename, const string& caller) {
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
      raise << caller << ": assume-filesystem: file contents for filename '" << filename << "' must be delimited in '|'s\n" << end();
      break;
    }
    in.get();  // skip leading '|'
    string line;
    getline(in, line);
    for (int i = 0; i < SIZE(line); ++i) {
      if (line.at(i) == '|') break;
      if (line.at(i) == '\\') {
        ++i;  // skip
        if (i == SIZE(line)) {
          raise << caller << ": assume-filesystem: file contents can't end a line with '\\'\n" << end();
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

void construct_filesystem_object(const map<string, string>& contents) {
  int filesystem_data_address = allocate(SIZE(contents)*2 + /*array length*/1);
  int curr = filesystem_data_address + /*skip refcount and length*/2;
  for (map<string, string>::const_iterator p = contents.begin(); p != contents.end(); ++p) {
    put(Memory, curr, new_mu_string(p->first));
    trace(9999, "mem") << "storing file name " << get(Memory, curr) << " in location " << curr << end();
    put(Memory, get(Memory, curr), 1);
    trace(9999, "mem") << "storing refcount 1 in location " << get(Memory, curr) << end();
    ++curr;
    put(Memory, curr, new_mu_string(p->second));
    trace(9999, "mem") << "storing file contents " << get(Memory, curr) << " in location " << curr << end();
    put(Memory, get(Memory, curr), 1);
    trace(9999, "mem") << "storing refcount 1 in location " << get(Memory, curr) << end();
    ++curr;
  }
  curr = filesystem_data_address+/*skip refcount*/1;
  put(Memory, curr, SIZE(contents));  // size of array
  trace(9999, "mem") << "storing filesystem size " << get(Memory, curr) << " in location " << curr << end();
  put(Memory, filesystem_data_address, 1);  // initialize refcount
  trace(9999, "mem") << "storing refcount 1 in location " << filesystem_data_address << end();
  // wrap the filesystem data in a filesystem object
  int filesystem_address = allocate(size_of_filesystem());
  curr = filesystem_address+/*skip refcount*/1;
  put(Memory, curr, filesystem_data_address);
  trace(9999, "mem") << "storing filesystem data address " << filesystem_data_address << " in location " << curr << end();
  put(Memory, filesystem_address, 1);  // initialize refcount
  trace(9999, "mem") << "storing refcount 1 in location " << filesystem_address << end();
  // save in product
  put(Memory, FILESYSTEM, filesystem_address);
  trace(9999, "mem") << "storing filesystem address " << filesystem_address << " in location " << FILESYSTEM << end();
}

int size_of_filesystem() {
  // memoize result if already computed
  static int result = 0;
  if (result) return result;
  assert(get(Type_ordinal, "filesystem"));
  type_tree* type = new type_tree("filesystem");
  result = size_of(type)+/*refcount*/1;
  delete type;
  return result;
}

string next_filesystem_word(istream& in) {
  skip_whitespace_and_comments(in);
  if (in.peek() == '[') {
    string result = slurp_quoted(in);
    skip_whitespace_and_comments_but_not_newline(in);
    return result;
  }
  ostringstream out;
  slurp_word(in, out);
  skip_whitespace_and_comments(in);
  return out.str();
}

void skip_whitespace(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    if (isspace(in.peek())) in.get();
    else break;
  }
}
