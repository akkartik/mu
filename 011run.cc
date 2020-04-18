//: Running SubX programs on the VM.

//: (Not to be confused with the 'run' subcommand for running ELF binaries on
//: the VM. That comes later.)

:(before "End Help Texts")
put_new(Help, "syntax",
  "SubX programs consist of segments, each segment in turn consisting of lines.\n"
  "Line-endings are significant; each line should contain a single\n"
  "instruction, macro or directive.\n"
  "\n"
  "Comments start with the '#' character. It should be at the start of a word\n"
  "(start of line, or following a space).\n"
  "\n"
  "Each segment starts with a header line: a '==' delimiter followed by the name of\n"
  "the segment and a (sometimes approximate) starting address in memory.\n"
  "The name 'code' is special; instructions to execute should always go here.\n"
  "\n"
  "The resulting binary starts running code from a label called 'Entry'\n"
  "in the code segment.\n"
  "\n"
  "Segments with the same name get merged together. This rule helps keep functions\n"
  "and their data close together in .subx files.\n"
  "You don't have to specify the starting address after the first time.\n"
  "\n"
  "Lines consist of a series of words. Words can contain arbitrary metadata\n"
  "after a '/', but they can never contain whitespace. Metadata has no effect\n"
  "at runtime, but can be handy when rewriting macros.\n"
  "\n"
  "Check out the example programs in the apps/ directory, particularly apps/ex*.\n"
);
:(before "End Help Contents")
cerr << "  syntax\n";

:(code)
void test_copy_imm32_to_EAX() {
  // At the lowest level, SubX programs are a series of hex bytes, each
  // (variable-length) instruction on one line.
  run(
      // Comments start with '#' and are ignored.
      "# comment\n"
      // Segment headers start with '==', a name and a starting hex address.
      // There's usually one code and one data segment. The code segment
      // always comes first.
      "== code 0x1\n"  // code segment

      // After the header, each segment consists of lines, and each line
      // consists of words separated by whitespace.
      //
      // All words can have metadata after a '/'. No spaces allowed in
      // metadata, of course.
      // Unrecognized metadata never causes errors, so you can use it for
      // documentation.
      //
      // Within the code segment in particular, x86 instructions consist of
      // some number of the following parts and sub-parts (see the Readme and
      // cheatsheet.pdf for details):
      //   opcodes: 1-3 bytes
      //   ModR/M byte
      //   SIB byte
      //   displacement: 0/1/2/4 bytes
      //   immediate: 0/1/2/4 bytes
      // opcode        ModR/M                    SIB                   displacement    immediate
      // instruction   mod, reg, Reg/Mem bits    scale, index, base
      // 1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
      "  b8            .                         .                     .               0a 0b 0c 0d\n"  // copy 0x0d0c0b0a to EAX
      // The periods are just to help the eye track long gaps between columns,
      // and are otherwise ignored.
  );
  // This program, when run, causes the following events in the trace:
  CHECK_TRACE_CONTENTS(
      "load: 0x00000001 -> b8\n"
      "load: 0x00000002 -> 0a\n"
      "load: 0x00000003 -> 0b\n"
      "load: 0x00000004 -> 0c\n"
      "load: 0x00000005 -> 0d\n"
      "run: copy imm32 0x0d0c0b0a to EAX\n"
  );
}

// top-level helper for tests: parse the input, load the hex bytes into memory, run
void run(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  // Loading Test Program
  parse(in, p);
  if (trace_contains_errors()) return;  // if any stage raises errors, stop immediately
  // Running Test Program
  load(p);
  if (trace_contains_errors()) return;
  // convenience to keep tests concise: 'Entry' label need not be provided
  // not allowed in real programs
  if (p.entry)
    EIP = p.entry;
  else
    EIP = find(p, "code")->start;
  while (EIP < End_of_program)
    run_one_instruction();
}

//:: core data structures

:(before "End Types")
struct program {
  uint32_t entry;
  vector<segment> segments;
  program() { entry = 0; }
};
:(before "struct program")
struct segment {
  string name;
  uint32_t start;
  vector<line> lines;
  // End segment Fields
  segment() {
    start = 0;
    // End segment Constructor
  }
};
:(before "struct segment")
struct line {
  vector<word> words;
  vector<string> metadata;
  string original;
};
:(before "struct line")
struct word {
  string original;
  string data;
  vector<string> metadata;
};

//:: parse

:(code)
void parse(istream& fin, program& out) {
  segment* curr_segment = NULL;
  vector<line> l;
  while (has_data(fin)) {
    string line_data;
    line curr;
    getline(fin, line_data);
    curr.original = line_data;
    trace(99, "parse") << "line: " << line_data << end();
    // End Line Parsing Special-cases(line_data -> l)
    istringstream lin(line_data);
    while (has_data(lin)) {
      string word_data;
      lin >> word_data;
      if (word_data.empty()) continue;
      if (word_data[0] == '#') break;  // comment
      if (word_data == ".") continue;  // comment token
      if (word_data == "==") {
        flush(curr_segment, l);
        string segment_name;
        lin >> segment_name;
        curr_segment = find(out, segment_name);
        if (curr_segment != NULL) {
          trace(3, "parse") << "appending to segment '" << segment_name << "'" << end();
        }
        else {
          trace(3, "parse") << "new segment '" << segment_name << "'" << end();
          uint32_t seg_start = 0;
          lin >> std::hex >> seg_start;
          sanity_check_program_segment(out, seg_start);
          out.segments.push_back(segment());
          curr_segment = &out.segments.back();
          curr_segment->name = segment_name;
          curr_segment->start = seg_start;
          if (trace_contains_errors()) continue;
          trace(3, "parse") << "starts at address 0x" << HEXWORD << curr_segment->start << end();
        }
        break;  // skip rest of line
      }
      if (word_data[0] == ':') {
        // todo: line metadata
        break;
      }
      curr.words.push_back(word());
      parse_word(word_data, curr.words.back());
      trace(99, "parse") << "word: " << to_string(curr.words.back());
    }
    if (!curr.words.empty())
      l.push_back(curr);
  }
  flush(curr_segment, l);
  trace(99, "parse") << "done" << end();
}

segment* find(program& p, const string& segment_name) {
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    if (p.segments.at(i).name == segment_name)
      return &p.segments.at(i);
  }
  return NULL;
}

void flush(segment* s, vector<line>& lines) {
  if (lines.empty()) return;
  if (s == NULL) {
    raise << "input does not start with a '==' section header\n" << end();
    return;
  }
  trace(3, "parse") << "flushing segment" << end();
  s->lines.insert(s->lines.end(), lines.begin(), lines.end());
  lines.clear();
}

void parse_word(const string& data, word& out) {
  out.original = data;
  istringstream win(data);
  if (getline(win, out.data, '/')) {
    string m;
    while (getline(win, m, '/'))
      out.metadata.push_back(m);
  }
}

void sanity_check_program_segment(const program& p, uint32_t addr) {
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    if (p.segments.at(i).start == addr)
      raise << "can't have multiple segments starting at address 0x" << HEXWORD << addr << '\n' << end();
  }
}

// helper for tests
void parse(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
}

void test_detect_duplicate_segments() {
  Hide_errors = true;
  parse(
      "== segment1 0xee\n"
      "ab\n"
      "== segment2 0xee\n"
      "cd\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: can't have multiple segments starting at address 0x000000ee\n"
  );
}

//:: load

void load(const program& p) {
  if (find(p, "code") == NULL) {
    raise << "no code to run\n" << end();
    return;
  }
  // Ensure segments are disjoint.
  set<uint32_t> overlap;
  for (int i = 0;   i < SIZE(p.segments);  ++i) {
    const segment& seg = p.segments.at(i);
    uint32_t addr = seg.start;
    if (!already_allocated(addr))
      Mem.push_back(vma(seg.start));
    trace(99, "load") << "loading segment " << i << " from " << HEXWORD << addr << end();
    for (int j = 0;  j < SIZE(seg.lines);  ++j) {
      const line& l = seg.lines.at(j);
      for (int k = 0;  k < SIZE(l.words);  ++k) {
        const word& w = l.words.at(k);
        uint8_t val = hex_byte(w.data);
        if (trace_contains_errors()) return;
        assert(overlap.find(addr) == overlap.end());
        write_mem_u8(addr, val);
        overlap.insert(addr);
        trace(99, "load") << "0x" << HEXWORD << addr << " -> " << HEXBYTE << NUM(read_mem_u8(addr)) << end();
        ++addr;
      }
    }
    if (seg.name == "code") {
      End_of_program = addr;
    }
  }
}

const segment* find(const program& p, const string& segment_name) {
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    if (p.segments.at(i).name == segment_name)
      return &p.segments.at(i);
  }
  return NULL;
}

uint8_t hex_byte(const string& s) {
  if (contains_uppercase(s)) {
    raise << "uppercase hex not allowed: " << s << '\n' << end();
    return 0;
  }
  istringstream in(s);
  int result = 0;
  in >> std::hex >> result;
  if (!in || !in.eof()) {
    raise << "token '" << s << "' is not a hex byte\n" << end();
    return '\0';
  }
  if (result > 0xff || result < -0x8f) {
    raise << "token '" << s << "' is not a hex byte\n" << end();
    return '\0';
  }
  return static_cast<uint8_t>(result);
}

void test_number_too_large() {
  Hide_errors = true;
  parse_and_load(
      "== code 0x1\n"
      "01 cab\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token 'cab' is not a hex byte\n"
  );
}

void test_invalid_hex() {
  Hide_errors = true;
  parse_and_load(
      "== code 0x1\n"
      "01 cx\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token 'cx' is not a hex byte\n"
  );
}

void test_negative_number() {
  parse_and_load(
      "== code 0x1\n"
      "01 -02\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_negative_number_too_small() {
  Hide_errors = true;
  parse_and_load(
      "== code 0x1\n"
      "01 -12345\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token '-12345' is not a hex byte\n"
  );
}

void test_hex_prefix() {
  parse_and_load(
      "== code 0x1\n"
      "0x01 -0x02\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_repeated_segment_merges_data() {
  parse_and_load(
      "== code 0x1\n"
      "11 22\n"
      "== code\n"  // again
      "33 44\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse: new segment 'code'\n"
      "parse: appending to segment 'code'\n"
      // first segment
      "load: 0x00000001 -> 11\n"
      "load: 0x00000002 -> 22\n"
      // second segment
      "load: 0x00000003 -> 33\n"
      "load: 0x00000004 -> 44\n"
  );
}

void test_error_on_missing_segment_header() {
  Hide_errors = true;
  parse_and_load(
      "01 02\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: input does not start with a '==' section header\n"
  );
}

void test_error_on_uppercase_hex() {
  Hide_errors = true;
  parse_and_load(
      "== code\n"
      "01 Ab\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: uppercase hex not allowed: Ab\n"
  );
}

//: helper for tests
void parse_and_load(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;  // if any stage raises errors, stop immediately
  load(p);
}

//:: run

:(before "End Initialize Op Names")
put_new(Name, "b8", "copy imm32 to EAX (mov)");

//: our first opcode

:(before "End Single-Byte Opcodes")
case 0xb8: {  // copy imm32 to EAX
  const int32_t src = next32();
  trace(Callstack_depth+1, "run") << "copy imm32 0x" << HEXWORD << src << " to EAX" << end();
  Reg[EAX].i = src;
  break;
}

:(code)
void test_copy_imm32_to_EAX_again() {
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  b8                                 0a 0b 0c 0d \n"  // copy 0x0d0c0b0a to EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: copy imm32 0x0d0c0b0a to EAX\n"
  );
}

// read a 32-bit int in little-endian order from the instruction stream
int32_t next32() {
  int32_t result = read_mem_i32(EIP);
  EIP+=4;
  return result;
}

//:: helpers

string to_string(const word& w) {
  ostringstream out;
  out << w.data;
  for (int i = 0;  i < SIZE(w.metadata);  ++i)
    out << " /" << w.metadata.at(i);
  return out.str();
}

bool contains_uppercase(const string& s) {
  for (int i = 0;  i < SIZE(s);  ++i)
    if (isupper(s.at(i))) return true;
  return false;
}
