//: Running SubX programs on the VM.

//: (Not to be confused with the 'run' subcommand for running ELF binaries on
//: the VM. That comes later.)

:(before "End Help Texts")
put(Help, "syntax",
  "SubX programs consist of segments, each segment in turn consisting of lines.\n"
  "Line-endings are significant; each line should contain a single\n"
  "instruction, macro or directive.\n"
  "\n"
  "Comments start with the '#' character. It should be at the start of a word\n"
  "(start of line, or following a space).\n"
  "\n"
  "Each segment starts with a header line: a '==' delimiter followed by the\n"
  "starting address for the segment.\n"
  "\n"
  "The starting address for a segment has some finicky requirements. But just\n"
  "start with a round number, and `subx` will try to guide you to a valid\n"
  "configuration.\n"
  "A good rule of thumb is to try to start the first segment at the default\n"
  "address of 0x08048000, and to start each subsequent segment at least 0x1000\n"
  "(most common page size) bytes after the last.\n"
  "If a segment occupies than 0x1000 bytes you'll need to push subsequent\n"
  "segments further down.\n"
  "Currently only the first segment contains executable code (because it gets\n"
  "annoying to have to change addresses in later segments every time an earlier\n"
  "one changes length; one of those finicky requirements).\n"
  "\n"
  "Lines consist of a series of words. Words can contain arbitrary metadata\n"
  "after a '/', but they can never contain whitespace. Metadata has no effect\n"
  "at runtime, but can be handy when rewriting macros.\n"
  "\n"
  "Check out some examples in this directory (ex*.subx)\n"
  "Programming in machine code can be annoying, but let's see if we can make\n"
  "it nice enough to be able to write a compiler in it.\n"
);
:(before "End Help Contents")
cerr << "  syntax\n";

:(scenario add_imm32_to_eax)
# At the lowest level, SubX programs are a series of hex bytes, each
# (variable-length) instruction on one line.
#
# Later we'll make things nicer using macros. But you'll always be able to
# insert hex bytes out of instructions.
#
# As you can see, comments start with '#' and are ignored.

# Segment headers start with '==', specifying the hex address where they
# begin. The first segment is always assumed to be code.
== 0x1

# We don't show it here, but all lines can have metadata after a ':'.
# All words can have metadata after a '/'. No spaces allowed in word metadata, of course.
# Metadata doesn't directly form instructions, but some macros may look at it.
# Unrecognized metadata never causes errors, so you can also use it for
# documentation.

# Within the code segment, x86 instructions consist of the following parts (see cheatsheet.pdf):
#   opcode        ModR/M                    SIB                   displacement    immediate
#   instruction   mod, reg, Reg/Mem bits    scale, index, base
#   1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
    05            .                         .                     .               0a 0b 0c 0d  # add 0x0d0c0b0a to EAX
# (The single periods are just to help the eye track long gaps between
# columns, and are otherwise ignored.)

# This program, when run, causes the following events in the trace:
+load: 0x00000001 -> 05
+load: 0x00000002 -> 0a
+load: 0x00000003 -> 0b
+load: 0x00000004 -> 0c
+load: 0x00000005 -> 0d
+run: add imm32 0x0d0c0b0a to reg EAX
+run: storing 0x0d0c0b0a

:(code)
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
  trace(99, "parse") << "begin" << end();
  while (has_data(fin)) {
    string line_data;
    line curr;
    getline(fin, line_data);
    curr.original = line_data;
    trace(99, "parse") << "line: " << line_data << end();
    istringstream lin(line_data);
    while (has_data(lin)) {
      string word_data;
      lin >> word_data;
      if (word_data.empty()) continue;
      if (word_data[0] == '#') break;  // comment
      if (word_data == ".") continue;  // comment token
      if (word_data == "==") {
        if (!l.empty()) {
          assert(!out.segments.empty());
          trace(99, "parse") << "flushing to segment" << end();
          out.segments.back().lines.swap(l);
        }
        segment s;
        string segment_title;
        lin >> segment_title;
        if (starts_with(segment_title, "0x"))
          s.start = parse_int(segment_title);
        trace(99, "parse") << "new segment from " << HEXWORD << s.start << end();
        out.segments.push_back(s);
        // todo?
        break;  // skip rest of line
      }
      if (word_data[0] == ':') {
        // todo: line metadata
        break;
      }
      curr.words.push_back(word());
      curr.words.back().original = word_data;
      istringstream win(word_data);
      if (getline(win, curr.words.back().data, '/')) {
        string m;
        while (getline(win, m, '/'))
          curr.words.back().metadata.push_back(m);
      }
      trace(99, "parse") << "new word: " << curr.words.back().data << end();
    }
    if (!curr.words.empty())
      l.push_back(curr);
  }
  if (!l.empty()) {
    assert(!out.segments.empty());
    trace(99, "parse") << "flushing to segment" << end();
    out.segments.back().lines.swap(l);
  }
  trace(99, "parse") << "done" << end();
}

//:: transform

:(before "End Types")
typedef void (*transform_fn)(program&);
:(before "End Globals")
vector<transform_fn> Transform;

void transform(program& p) {
  trace(99, "transform") << "begin" << end();
  for (int t = 0;  t < SIZE(Transform);  ++t)
    (*Transform.at(t))(p);
  trace(99, "transform") << "done" << end();
}

//:: load

void load(const program& p) {
  trace(99, "load") << "begin" << end();
  if (p.segments.empty()) {
    raise << "no code to run\n" << end();
    return;
  }
  for (int i = 0;   i < SIZE(p.segments);  ++i) {
    const segment& seg = p.segments.at(i);
    uint32_t addr = seg.start;
    trace(99, "load") << "loading segment " << i << " from " << HEXWORD << addr << end();
    for (int j = 0;  j < SIZE(seg.lines);  ++j) {
      const line& l = seg.lines.at(j);
      for (int k = 0;  k < SIZE(l.words);  ++k) {
        const word& w = l.words.at(k);
        uint8_t val = hex_byte(w.data);
        if (trace_contains_errors()) return;
        write_mem_u8(addr, val);
        trace(99, "load") << "0x" << HEXWORD << addr << " -> " << HEXBYTE << NUM(read_mem_u8(addr)) << end();
        ++addr;
      }
    }
    if (i == 0) End_of_program = addr;
  }
  EIP = p.segments.at(0).start;
  trace(99, "load") << "done" << end();
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

:(scenarios parse_and_load)
:(scenario number_too_large)
% Hide_errors = true;
== 0x1
05 cab
+error: token 'cab' is not a hex byte

:(scenario invalid_hex)
% Hide_errors = true;
== 0x1
05 cx
+error: token 'cx' is not a hex byte

:(scenario negative_number)
== 0x1
05 -12
$error: 0

:(scenario negative_number_too_small)
% Hide_errors = true;
== 0x1
05 -12345
+error: token '-12345' is not a hex byte

:(scenario hex_prefix)
== 0x1
0x05 -0x12
$error: 0

//: helper for tests
:(code)
void parse_and_load(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;  // if any stage raises errors, stop immediately
  load(p);
}

//:: run

:(before "End Initialize Op Names(name)")
put(name, "05", "add imm32 to R0 (EAX)");

//: our first opcode
:(before "End Single-Byte Opcodes")
case 0x05: {  // add imm32 to EAX
  int32_t arg2 = imm32();
  trace(90, "run") << "add imm32 0x" << HEXWORD << arg2 << " to reg EAX" << end();
  BINARY_ARITHMETIC_OP(+, Reg[EAX].i, arg2);
  break;
}

:(code)
// read a 32-bit immediate in little-endian order from the instruction stream
int32_t imm32() {
  int32_t result = next();
  result |= (next()<<8);
  result |= (next()<<16);
  result |= (next()<<24);
  return result;
}

:(code)
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
