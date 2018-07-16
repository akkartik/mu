//: Loading programs into the VM. 

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
    05                                                                            0a 0b 0c 0d  # add 0x0d0c0b0a to EAX

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
  if (p.segments.empty()) return;
  EIP = p.segments.at(0).start;
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
  segment() :start(0) {}
};
:(before "struct segment")
struct line {
  vector<word> words;
  vector<string> metadata;
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
    getline(fin, line_data);
    trace(99, "parse") << "line: " << line_data << end();
    istringstream lin(line_data);
    vector<word> w;
    while (has_data(lin)) {
      string word_data;
      lin >> word_data;
      if (word_data.empty()) continue;
      if (word_data == "==") {
        if (!l.empty()) {
          assert(!out.segments.empty());
          trace(99, "parse") << "flushing to segment" << end();
          out.segments.back().lines.swap(l);
        }
        segment s;
        lin >> std::hex >> s.start;
        trace(99, "parse") << "new segment from " << HEXWORD << s.start << end();
        out.segments.push_back(s);
        // todo?
        break;  // skip rest of line
      }
      if (word_data[0] == ':') {
        // todo: line metadata
        break;
      }
      if (word_data[0] == '#') {
        // comment
        break;
      }
      w.push_back(word());
      w.back().original = word_data;
      istringstream win(word_data);
      if (getline(win, w.back().data, '/')) {
        string m;
        while (getline(win, m, '/'))
          w.back().metadata.push_back(m);
      }
      trace(99, "parse") << "new word: " << w.back().data << end();
    }
    if (!w.empty()) {
      l.push_back(line());
      l.back().words.swap(w);
    }
  }
  if (!l.empty()) {
    assert(!out.segments.empty());
    trace(99, "parse") << "flushing to segment" << end();
    out.segments.back().lines.swap(l);
  }
}

//:: transform

:(before "End Types")
typedef void (*transform_fn)(program&);
:(before "End Globals")
vector<transform_fn> Transform;

void transform(program& p) {
  for (int t = 0;  t < SIZE(Transform);  ++t)
    (*Transform.at(t))(p);
}

//:: load

void load(const program& p) {
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
}

uint8_t hex_byte(const string& s) {
  istringstream in(s);
  int result = 0;
  in >> std::hex >> result;
  if (!in) {
    raise << "invalid hex " << s << '\n' << end();
    return '\0';
  }
  if (result > 0xff) {
    raise << "invalid hex byte " << std::hex << result << '\n' << end();
    return '\0';
  }
  return static_cast<uint8_t>(result);
}

//:: run

//: our first opcode
:(before "End Single-Byte Opcodes")
case 0x05: {  // add imm32 to EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "add imm32 0x" << HEXWORD << arg2 << " to reg EAX" << end();
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
