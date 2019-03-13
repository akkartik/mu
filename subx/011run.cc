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
  "the segment.\n"
  "\n"
  "The first segment contains code and should be called 'code'.\n"
  "The second segment should be called 'data'.\n"
  "The resulting binary starts running from the start of the code segment by default.\n"
  "To start elsewhere in the code segment, define a special label called 'Entry'.\n"
  "\n"
  "Segments with the same name get merged together. This rule helps keep functions and\n"
  "their data close together in .subx files.\n"
  "\n"
  "Lines consist of a series of words. Words can contain arbitrary metadata\n"
  "after a '/', but they can never contain whitespace. Metadata has no effect\n"
  "at runtime, but can be handy when rewriting macros.\n"
  "\n"
  "Check out the examples in the examples/ directory.\n"
  "Programming in machine code can be annoying, but let's see if we can make\n"
  "it nice enough to be able to write a compiler in it.\n"
);
:(before "End Help Contents")
cerr << "  syntax\n";

:(code)
void test_add_imm32_to_eax() {
  // At the lowest level, SubX programs are a series of hex bytes, each
  // (variable-length) instruction on one line.
  run(
      // Comments start with '#' and are ignored.
      "# comment\n"
      // Segment headers start with '==' and a name or starting hex address.
      // There's usually one code and one data segment. The code segment
      // always comes first.
      "== 0x1\n"  // code segment

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
      "  05            .                         .                     .               0a 0b 0c 0d\n"  // add 0x0d0c0b0a to EAX
      // The periods are just to help the eye track long gaps between columns,
      // and are otherwise ignored.
  );
  // This program, when run, causes the following events in the trace:
  CHECK_TRACE_CONTENTS(
      "load: 0x00000001 -> 05\n"
      "load: 0x00000002 -> 0a\n"
      "load: 0x00000003 -> 0b\n"
      "load: 0x00000004 -> 0c\n"
      "load: 0x00000005 -> 0d\n"
      "run: add imm32 0x0d0c0b0a to reg EAX\n"
      "run: storing 0x0d0c0b0a\n"
  );
}

// top-level helper for scenarios: parse the input, transform any macros, load
// the final hex bytes into memory, run it
void run(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;  // if any stage raises errors, stop immediately
  transform(p);
  if (trace_contains_errors()) return;
  load(p);
  if (trace_contains_errors()) return;
  while (EIP < End_of_program)
    run_one_instruction();
}

//:: core data structures

:(before "End Types")
struct program {
  vector<segment> segments;
  // random ideas for other things we may eventually need
  //map<name, address> globals;
  //vector<recipe> recipes;
  //map<string, type_info> types;
};
:(before "struct program")
struct segment {
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
        flush(out, l);
        string segment_title;
        lin >> segment_title;
        if (starts_with(segment_title, "0x")) {
          segment s;
          s.start = parse_int(segment_title);
          sanity_check_program_segment(out, s.start);
          if (trace_contains_errors()) continue;
          trace(3, "parse") << "new segment from 0x" << HEXWORD << s.start << end();
          out.segments.push_back(s);
        }
        // End Segment Parsing Special-cases(segment_title)
        // todo: segment segment metadata
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
  flush(out, l);
  trace(99, "parse") << "done" << end();
}

void flush(program& p, vector<line>& lines) {
  if (lines.empty()) return;
  if (p.segments.empty()) {
    raise << "input does not start with a '==' section header\n" << end();
    return;
  }
  // End flush(p, lines) Special-cases
  trace(99, "parse") << "flushing segment" << end();
  p.segments.back().lines.swap(lines);
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
      "== 0xee\n"
      "ab\n"
      "== 0xee\n"
      "cd\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: can't have multiple segments starting at address 0x000000ee\n"
  );
}

//:: transform

:(before "End Types")
typedef void (*transform_fn)(program&);
:(before "End Globals")
vector<transform_fn> Transform;

:(code)
void transform(program& p) {
  for (int t = 0;  t < SIZE(Transform);  ++t)
    (*Transform.at(t))(p);
}

//:: load

void load(const program& p) {
  if (p.segments.empty()) {
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
    if (i == 0) End_of_program = addr;
  }
  EIP = p.segments.at(0).start;
  // End Initialize EIP
}

uint8_t hex_byte(const string& s) {
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
      "== 0x1\n"
      "05 cab\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token 'cab' is not a hex byte\n"
  );
}

void test_invalid_hex() {
  Hide_errors = true;
  parse_and_load(
      "== 0x1\n"
      "05 cx\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token 'cx' is not a hex byte\n"
  );
}

void test_negative_number() {
  parse_and_load(
      "== 0x1\n"
      "05 -12\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_negative_number_too_small() {
  Hide_errors = true;
  parse_and_load(
      "== 0x1\n"
      "05 -12345\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: token '-12345' is not a hex byte\n"
  );
}

void test_hex_prefix() {
  parse_and_load(
      "== 0x1\n"
      "0x05 -0x12\n"
  );
  CHECK_TRACE_COUNT("error", 0);
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
put_new(Name, "05", "add imm32 to EAX (add)");

//: our first opcode
:(before "End Single-Byte Opcodes")
case 0x05: {  // add imm32 to EAX
  int32_t arg2 = next32();
  trace(Callstack_depth+1, "run") << "add imm32 0x" << HEXWORD << arg2 << " to reg EAX" << end();
  BINARY_ARITHMETIC_OP(+, Reg[EAX].i, arg2);
  break;
}

:(code)
// read a 32-bit int in little-endian order from the instruction stream
int32_t next32() {
  int32_t result = next();
  result |= (next()<<8);
  result |= (next()<<16);
  result |= (next()<<24);
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

int32_t parse_int(const string& s) {
  if (s.empty()) return 0;
  istringstream in(s);
  in >> std::hex;
  if (s.at(0) == '-') {
    int32_t result = 0;
    in >> result;
    if (!in || !in.eof()) {
      raise << "not a number: " << s << '\n' << end();
      return 0;
    }
    return result;
  }
  uint32_t uresult = 0;
  in >> uresult;
  if (!in || !in.eof()) {
    raise << "not a number: " << s << '\n' << end();
    return 0;
  }
  return static_cast<int32_t>(uresult);
}
:(before "End Unit Tests")
void test_parse_int() {
  CHECK_EQ(0, parse_int("0"));
  CHECK_EQ(0, parse_int("0x0"));
  CHECK_EQ(0, parse_int("0x0"));
  CHECK_EQ(16, parse_int("10"));  // hex always
  CHECK_EQ(-1, parse_int("-1"));
  CHECK_EQ(-1, parse_int("0xffffffff"));
}
