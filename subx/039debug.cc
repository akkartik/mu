//:: Some helpers for debugging.

//: Load the 'map' file generated during 'subx --map translate' when running 'subx --map --dump run'.
//: (It'll only affect the trace.)

:(before "End Globals")
map</*address*/uint32_t, string> Symbol_name;  // used only by 'subx run'
:(before "End --map Settings")
load_map("map");
:(code)
void load_map(const string& map_filename) {
  ifstream fin(map_filename.c_str());
  fin >> std::hex;
  while (has_data(fin)) {
    uint32_t addr = 0;
    fin >> addr;
    string name;
    fin >> name;
    put(Symbol_name, addr, name);
  }
}

:(after "Run One Instruction")
if (contains_key(Symbol_name, EIP))
  trace(90, "run") << "== label " << get(Symbol_name, EIP) << end();

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
  dbg << "watch points:" << end();
  for (map<string, uint32_t>::iterator p = Watch_points.begin();  p != Watch_points.end();  ++p)
    dbg << "  " << p->first << ": " << HEXWORD << p->second << " -> " << HEXWORD << read_mem_u32(p->second) << end();
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
  Watch_points[Watch_this_effective_address] = addr;
}
