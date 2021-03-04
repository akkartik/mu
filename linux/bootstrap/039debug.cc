//:: Some helpers for debugging.

//: Load the 'map' file generated during 'bootstrap --debug translate' when running
//: 'bootstrap --trace run'.
//: (It'll only affect the trace.)

:(before "End Globals")
map</*address*/uint32_t, string> Symbol_name;  // used only by 'bootstrap run'
map</*address*/uint32_t, string> Source_line;  // used only by 'bootstrap run'
:(before "End --trace Settings")
load_labels();
load_source_lines();
:(code)
void load_labels() {
  ifstream fin("labels");
  if (fin.fail()) return;
  fin >> std::hex;
  while (has_data(fin)) {
    uint32_t addr = 0;
    fin >> addr;
    string name;
    fin >> name;
    put(Symbol_name, addr, name);
  }
}

void load_source_lines() {
  ifstream fin("source_lines");
  if (fin.fail()) return;
  fin >> std::hex;
  while (has_data(fin)) {
    uint32_t addr = 0;
    fin >> addr;
    string line;
    getline(fin, line);
    put(Source_line, addr, hacky_squeeze_out_whitespace(line));
  }
}

:(after "Run One Instruction")
if (contains_key(Symbol_name, EIP))
  trace(Callstack_depth, "run") << "== label " << get(Symbol_name, EIP) << end();
if (contains_key(Source_line, EIP))
  trace(Callstack_depth, "run") << "inst: " << get(Source_line, EIP) << end();
else
  // no source line info; do what you can
  trace(Callstack_depth, "run") << "inst: " << debug_info(EIP) << end();

:(code)
string debug_info(uint32_t inst_address) {
  uint8_t op = read_mem_u8(inst_address);
  if (op != 0xe8) {
    ostringstream out;
    out << HEXBYTE << NUM(op);
    return out.str();
  }
  int32_t offset = read_mem_i32(inst_address+/*skip op*/1);
  uint32_t next_eip = inst_address+/*inst length*/5+offset;
  if (contains_key(Symbol_name, next_eip))
    return "e8/call "+get(Symbol_name, next_eip);
  ostringstream out;
  out << "e8/call 0x" << HEXWORD << next_eip;
  return out.str();
}

//: If a label starts with '$watch-', make a note of the effective address
//: computed by the next instruction. Start dumping out its contents to the
//: trace after every subsequent instruction.

:(after "Run One Instruction")
dump_watch_points();
:(before "End Globals")
map<string, uint32_t> Watch_points;
:(before "End Reset")
Watch_points.clear();
:(code)
void dump_watch_points() {
  if (Watch_points.empty()) return;
  trace(Callstack_depth, "dbg") << "watch points:" << end();
  for (map<string, uint32_t>::iterator p = Watch_points.begin();  p != Watch_points.end();  ++p)
    trace(Callstack_depth, "dbg") << "  " << p->first << ": " << HEXWORD << p->second << " -> " << HEXWORD << read_mem_u32(p->second) << end();
}

:(before "End Globals")
string Watch_this_effective_address;
:(after "Run One Instruction")
Watch_this_effective_address = "";
if (contains_key(Symbol_name, EIP) && starts_with(get(Symbol_name, EIP), "$watch-"))
  Watch_this_effective_address = get(Symbol_name, EIP);
:(after "Found effective_address(addr)")
if (!Watch_this_effective_address.empty()) {
  dbg << "now watching " << HEXWORD << addr << " for " << Watch_this_effective_address << end();
  put(Watch_points, Watch_this_effective_address, addr);
}

//: If a label starts with '$dump-stack', dump out to the trace n bytes on
//: either side of ESP.

:(after "Run One Instruction")
if (contains_key(Symbol_name, EIP) && starts_with(get(Symbol_name, EIP), "$dump-stack")) {
  dump_stack(64);
}
:(code)
void dump_stack(int n) {
  uint32_t stack_pointer = Reg[ESP].u;
  uint32_t start = ((stack_pointer-n)&0xfffffff0);
  dbg << "stack:" << end();
  for (uint32_t addr = start;  addr < start+n*2;  addr+=16) {
    if (addr >= AFTER_STACK) break;
    ostringstream out;
    out << HEXWORD << addr << ":";
    for (int i = 0;  i < 16;  i+=4) {
      out << ' ';
      out << ((addr+i == stack_pointer) ? '[' : ' ');
      out << HEXWORD << read_mem_u32(addr+i);
      out << ((addr+i == stack_pointer) ? ']' : ' ');
    }
    dbg << out.str() << end();
  }
}

//: Special label that dumps regions of memory.
//: Not a general mechanism; by the time you get here you're willing to hack
//: on the emulator.
:(after "Run One Instruction")
if (contains_key(Symbol_name, EIP) && get(Symbol_name, EIP) == "$dump-stream-at-EAX")
  dump_stream_at(Reg[EAX].u);
:(code)
void dump_stream_at(uint32_t stream_start) {
  int32_t stream_length = read_mem_i32(stream_start + 8);
  dbg << "stream length: " << std::dec << stream_length << end();
  for (int i = 0;  i < stream_length + 12;  ++i)
    dbg << "0x" << HEXWORD << (stream_start+i) << ": " << HEXBYTE << NUM(read_mem_u8(stream_start+i)) << end();
}

//: helpers

:(code)
string hacky_squeeze_out_whitespace(const string& s) {
  // strip whitespace at start
  string::const_iterator first = s.begin();
  while (first != s.end() && isspace(*first))
    ++first;
  if (first == s.end()) return "";

  // strip whitespace at end
  string::const_iterator last = --s.end();
  while (last != s.begin() && isspace(*last))
    --last;
  ++last;

  // replace runs of spaces/dots with single space until comment or string
  // TODO:
  //   leave alone dots not surrounded by whitespace
  //   leave alone '#' within word
  //   leave alone '"' within word
  //   squeeze spaces after end of string
  ostringstream out;
  bool previous_was_space = false;
  bool in_comment_or_string = false;
  for (string::const_iterator curr = first;  curr != last;  ++curr) {
    if (in_comment_or_string)
      out << *curr;
    else if (isspace(*curr) || *curr == '.')
      previous_was_space = true;
    else {
      if (previous_was_space)
        out << ' ';
      out << *curr;
      previous_was_space = false;
      if (*curr == '#' || *curr == '"') in_comment_or_string = true;
    }
  }
  return out.str();
}
