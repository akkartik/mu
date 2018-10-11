//: Some helpers for debugging.

// Load the 'map' file generated during 'subx --map translate' when running 'subx --map --dump run'.
// (It'll only affect the trace.)

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
