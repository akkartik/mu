//: Allow instructions to mention literals directly.
//:
//: This layer will transparently move them to the global segment (assumed to
//: always be the second segment).

:(scenario transform_literal_string)
== code
b8/copy  "test"/imm32
== data  # need to manually create this for now
+transform: -- move literal strings to data segment
+transform: adding global variable '__subx_global_1' containing "test"
+transform: instruction after transform: 'b8 __subx_global_1'

//: We don't rely on any transforms running in previous layers, but this layer
//: knows about labels and global variables and will emit them for previous
//: layers to transform.
:(after "Begin Transforms")
// Begin Level-3 Transforms
Transform.push_back(transform_literal_strings);
// End Level-3 Transforms

:(before "End Globals")
int Next_auto_global = 1;
:(code)
void transform_literal_strings(program& p) {
  trace(99, "transform") << "-- move literal strings to data segment" << end();
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  segment data;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      word& curr = inst.words.at(j);
      if (curr.data.at(0) != '"') continue;
      ostringstream global_name;
      global_name << "__subx_global_" << Next_auto_global;
      ++Next_auto_global;
      add_global_to_data_segment(global_name.str(), curr, data);
      curr.data = global_name.str();
    }
    trace(99, "transform") << "instruction after transform: '" << data_to_string(inst) << "'" << end();
  }
  if (data.lines.empty()) return;
  if (SIZE(p.segments) < 2) {
    p.segments.resize(2);
    p.segments.at(1).lines.swap(data.lines);
  }
  vector<line>& existing_data = p.segments.at(1).lines;
  existing_data.insert(existing_data.end(), data.lines.begin(), data.lines.end());
}

void add_global_to_data_segment(const string& name, const word& value, segment& data) {
  trace(99, "transform") << "adding global variable '" << name << "' containing " << value.data << end();
  // emit label
  data.lines.push_back(label(name));
  // emit size for size-prefixed array
  data.lines.push_back(line());
  emit_hex_bytes(data.lines.back(), SIZE(value.data)-/*skip quotes*/2, 4/*bytes*/);
  // emit data byte by byte
  data.lines.push_back(line());
  line& curr = data.lines.back();
  for (int i = /*skip start quote*/1;  i < SIZE(value.data)-/*skip end quote*/1;  ++i) {
    char c = value.data.at(i);
    curr.words.push_back(word());
    curr.words.back().data = hex_byte_to_string(c);
    curr.words.back().metadata.push_back(string(1, c));
  }
}

line label(string s) {
  line result;
  result.words.push_back(word());
  result.words.back().data = (s+":");
  return result;
}

//: Within strings, whitespace is significant. So we need to redo our instruction
//: parsing.

:(scenarios parse_instruction_character_by_character)
:(scenario instruction_with_string_literal)
a "abc  def" z  # two spaces inside string
+parse2: word: a
+parse2: word: "abc  def"
+parse2: word: z
# no other words
$parse2: 3

:(before "End Line Parsing Special-cases(line_data -> l)")
if (line_data.find('"') != string::npos) {  // can cause false-positives, but we can handle them
  parse_instruction_character_by_character(line_data, l);
  continue;
}

:(code)
void parse_instruction_character_by_character(const string& line_data, vector<line>& out) {
  // parse literals
  istringstream in(line_data);
  in >> std::noskipws;
  line result;
  // add tokens (words or strings) one by one
  while (has_data(in)) {
    skip_whitespace(in);
    if (!has_data(in)) break;
    char c = in.get();
    if (c == '#') break;  // comment; drop rest of line
    if (c == ':') break;  // line metadata; skip for now
    if (c == '.') {
      if (!has_data(in)) break;  // comment token at end of line
      if (isspace(in.peek()))
        continue;  // '.' followed by space is comment token; skip
    }
    ostringstream w;
    w << c;
    if (c == '"') {
      // slurp until '"'
      while (has_data(in)) {
        in >> c;
        w << c;
        if (c == '"') break;
      }
    }
    // slurp any remaining characters until whitespace
    while (!isspace(in.peek()) && has_data(in)) {  // peek can sometimes trigger eof(), so do it first
      in >> c;
      w << c;
    }
    result.words.push_back(word());
    parse_word(w.str(), result.words.back());
    trace(99, "parse2") << "word: " << to_string(result.words.back()) << end();
  }
  if (!result.words.empty())
    out.push_back(result);
}

void skip_whitespace(istream& in) {
  while (true) {
    if (has_data(in) && isspace(in.peek())) in.get();
    else break;
  }
}

void skip_comment(istream& in) {
  if (has_data(in) && in.peek() == '#') {
    in.get();
    while (has_data(in) && in.peek() != '\n') in.get();
  }
}

// helper for tests
void parse_instruction_character_by_character(const string& line_data) {
  vector<line> out;
  parse_instruction_character_by_character(line_data, out);
}

:(scenario parse2_comment_token_in_middle)
a . z
+parse2: word: a
+parse2: word: z
-parse2: word: .
# no other words
$parse2: 2

:(scenario parse2_word_starting_with_dot)
a .b c
+parse2: word: a
+parse2: word: .b
+parse2: word: c

:(scenario parse2_comment_token_at_start)
. a b
+parse2: word: a
+parse2: word: b
-parse2: word: .

:(scenario parse2_comment_token_at_end)
a b .
+parse2: word: a
+parse2: word: b
-parse2: word: .

:(scenario parse2_word_starting_with_dot_at_start)
.a b c
+parse2: word: .a
+parse2: word: b
+parse2: word: c

:(scenario parse2_metadata)
.a b/c d
+parse2: word: .a
+parse2: word: b /c
+parse2: word: d

:(scenario parse2_string_with_metadata)
a "bc  def"/disp32 g
+parse2: word: a
+parse2: word: "bc  def" /disp32
+parse2: word: g

:(scenario parse2_string_with_metadata_at_end)
a "bc  def"/disp32
+parse2: word: a
+parse2: word: "bc  def" /disp32

:(code)
void test_parse2_string_with_metadata_at_end_of_line_without_newline() {
  parse_instruction_character_by_character(
      "68/push \"test\"/f"  // no newline, which is how calls from parse() will look
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: 68 /push"
      "parse2: word: \"test\" /f"
  );
}
