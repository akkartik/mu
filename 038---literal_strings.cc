//: Allow instructions to mention literals directly.
//:
//: This layer will transparently move them to the global segment (assumed to
//: always be the second segment).

void test_transform_literal_string() {
  run(
      "== code 0x1\n"
      "b8/copy  \"test\"/imm32\n"
      "== data 0x2000\n"  // need an empty segment
  );
  CHECK_TRACE_CONTENTS(
      "transform: -- move literal strings to data segment\n"
      "transform: adding global variable '__subx_global_1' containing \"test\"\n"
      "transform: line after transform: 'b8 __subx_global_1'\n"
  );
}

//: We don't rely on any transforms running in previous layers, but this layer
//: knows about labels and global variables and will emit them for previous
//: layers to transform.
:(after "Begin Transforms")
Transform.push_back(transform_literal_strings);

:(before "End Globals")
int Next_auto_global = 1;
:(before "End Reset")
Next_auto_global = 1;
:(code)
void transform_literal_strings(program& p) {
  trace(3, "transform") << "-- move literal strings to data segment" << end();
  if (p.segments.empty()) return;
  vector<line> new_lines;
  for (int s = 0;  s < SIZE(p.segments);  ++s) {
    segment& seg = p.segments.at(s);
    trace(99, "transform") << "segment '" << seg.name << "'" << end();
    for (int i = 0;  i < SIZE(seg.lines);  ++i) {
//?       cerr << seg.name << '/' << i << '\n';
      line& line = seg.lines.at(i);
      for (int j = 0;  j < SIZE(line.words);  ++j) {
        word& curr = line.words.at(j);
        if (curr.data.at(0) != '"') continue;
        ostringstream global_name;
        global_name << "__subx_global_" << Next_auto_global;
        ++Next_auto_global;
        add_global_to_data_segment(global_name.str(), curr, new_lines);
        curr.data = global_name.str();
      }
      trace(99, "transform") << "line after transform: '" << data_to_string(line) << "'" << end();
    }
  }
  segment* data = find(p, "data");
  if (data)
    data->lines.insert(data->lines.end(), new_lines.begin(), new_lines.end());
}

void add_global_to_data_segment(const string& name, const word& value, vector<line>& out) {
  trace(99, "transform") << "adding global variable '" << name << "' containing " << value.data << end();
  // emit label
  out.push_back(label(name));
  // emit size for size-prefixed array
  out.push_back(line());
  emit_hex_bytes(out.back(), SIZE(value.data)-/*skip quotes*/2, 4/*bytes*/);
  // emit data byte by byte
  out.push_back(line());
  line& curr = out.back();
  for (int i = /*skip start quote*/1;  i < SIZE(value.data)-/*skip end quote*/1;  ++i) {
    char c = value.data.at(i);
    curr.words.push_back(word());
    curr.words.back().data = hex_byte_to_string(c);
    curr.words.back().metadata.push_back(string(1, c));
  }
}

//: Within strings, whitespace is significant. So we need to redo our instruction
//: parsing.

void test_instruction_with_string_literal() {
  parse_instruction_character_by_character(
      "a \"abc  def\" z\n"  // two spaces inside string
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: \"abc  def\"\n"
      "parse2: word: z\n"
  );
  // no other words
  CHECK_TRACE_COUNT("parse2", 3);
}

void test_string_literal_in_data_segment() {
  run(
      "== code 0x1\n"
      "b8/copy  X/imm32\n"
      "== data 0x2000\n"
      "X:\n"
      "\"test\"/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: -- move literal strings to data segment\n"
      "transform: adding global variable '__subx_global_1' containing \"test\"\n"
      "transform: line after transform: '__subx_global_1'\n"
  );
}

void test_string_literal_with_missing_quote() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "b8/copy  \"test/imm32\n"
      "== data 0x2000\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: unclosed string in: b8/copy  \"test/imm32"
  );
}

:(before "End Line Parsing Special-cases(line_data -> l)")
if (line_data.find('"') != string::npos) {  // can cause false-positives, but we can handle them
  parse_instruction_character_by_character(line_data, l);
  continue;
}

:(code)
void parse_instruction_character_by_character(const string& line_data, vector<line>& out) {
  if (line_data.find('\n') != string::npos  && line_data.find('\n') != line_data.size()-1) {
    raise << "parse_instruction_character_by_character: should receive only a single line\n" << end();
    return;
  }
  // parse literals
  istringstream in(line_data);
  in >> std::noskipws;
  line result;
  result.original = line_data;
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
    result.words.push_back(word());
    if (c == '"') {
      // string literal; slurp everything between quotes into data
      ostringstream d;
      d << c;
      while (true) {
        if (!has_data(in)) {
          raise << "unclosed string in: " << line_data << end();
          return;
        }
        in >> c;
        if (c == '\\') {
          in >> c;
          if (c == 'n') d << '\n';
          else if (c == '"') d << '"';
          else if (c == '\\') d << '\\';
          else {
            raise << "parse_instruction_character_by_character: unknown escape sequence '\\" << c << "'\n" << end();
            return;
          }
          continue;
        } else {
          d << c;
        }
        if (c == '"') break;
      }
      result.words.back().data = d.str();
      result.words.back().original = d.str();
      // slurp metadata
      ostringstream m;
      while (!isspace(in.peek()) && has_data(in)) {  // peek can sometimes trigger eof(), so do it first
        in >> c;
        if (c == '/') {
          if (!m.str().empty()) result.words.back().metadata.push_back(m.str());
          m.str("");
        }
        else {
          m << c;
        }
      }
      if (!m.str().empty()) result.words.back().metadata.push_back(m.str());
    }
    else {
      // not a string literal; slurp all characters until whitespace
      ostringstream w;
      w << c;
      while (!isspace(in.peek()) && has_data(in)) {  // peek can sometimes trigger eof(), so do it first
        in >> c;
        w << c;
      }
      parse_word(w.str(), result.words.back());
    }
    trace(99, "parse2") << "word: " << to_string(result.words.back()) << end();
  }
  if (!result.words.empty())
    out.push_back(result);
}

void skip_whitespace(istream& in) {
  while (has_data(in) && isspace(in.peek())) {
    in.get();
  }
}

void skip_comment(istream& in) {
  if (has_data(in) && in.peek() == '#') {
    in.get();
    while (has_data(in) && in.peek() != '\n') in.get();
  }
}

line label(string s) {
  line result;
  result.words.push_back(word());
  result.words.back().data = (s+":");
  return result;
}

// helper for tests
void parse_instruction_character_by_character(const string& line_data) {
  vector<line> out;
  parse_instruction_character_by_character(line_data, out);
}

void test_parse2_comment_token_in_middle() {
  parse_instruction_character_by_character(
      "a . z\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: z\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("parse2: word: .");
  // no other words
  CHECK_TRACE_COUNT("parse2", 2);
}

void test_parse2_word_starting_with_dot() {
  parse_instruction_character_by_character(
      "a .b c\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: .b\n"
      "parse2: word: c\n"
  );
}

void test_parse2_comment_token_at_start() {
  parse_instruction_character_by_character(
      ". a b\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: b\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("parse2: word: .");
}

void test_parse2_comment_token_at_end() {
  parse_instruction_character_by_character(
      "a b .\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: b\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("parse2: word: .");
}

void test_parse2_word_starting_with_dot_at_start() {
  parse_instruction_character_by_character(
      ".a b c\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: .a\n"
      "parse2: word: b\n"
      "parse2: word: c\n"
  );
}

void test_parse2_metadata() {
  parse_instruction_character_by_character(
      ".a b/c d\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: .a\n"
      "parse2: word: b /c\n"
      "parse2: word: d\n"
  );
}

void test_parse2_string_with_metadata() {
  parse_instruction_character_by_character(
      "a \"bc  def\"/disp32 g\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: \"bc  def\" /disp32\n"
      "parse2: word: g\n"
  );
}

void test_parse2_string_with_metadata_at_end() {
  parse_instruction_character_by_character(
      "a \"bc  def\"/disp32\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: a\n"
      "parse2: word: \"bc  def\" /disp32\n"
  );
}

void test_parse2_string_with_metadata_at_end_of_line_without_newline() {
  parse_instruction_character_by_character(
      "68/push \"test\"/f"  // no newline, which is how calls from parse() will look
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: 68 /push\n"
      "parse2: word: \"test\" /f\n"
  );
}

//: Make sure slashes inside strings don't trigger adding stuff from inside the
//: string to metadata.

void test_parse2_string_containing_slashes() {
  parse_instruction_character_by_character(
      "a \"bc/def\"/disp32\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: \"bc/def\" /disp32\n"
  );
}

void test_instruction_with_string_literal_with_escaped_quote() {
  parse_instruction_character_by_character(
      "\"a\\\"b\"\n"  // escaped quote inside string
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: \"a\"b\"\n"
  );
  // no other words
  CHECK_TRACE_COUNT("parse2", 1);
}

void test_instruction_with_string_literal_with_escaped_backslash() {
  parse_instruction_character_by_character(
      "\"a\\\\b\"\n"  // escaped backslash inside string
  );
  CHECK_TRACE_CONTENTS(
      "parse2: word: \"a\\b\"\n"
  );
  // no other words
  CHECK_TRACE_COUNT("parse2", 1);
}
