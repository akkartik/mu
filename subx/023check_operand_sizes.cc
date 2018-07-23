//:: Check that the different operands of an instruction aren't too large for their bitfields.

:(scenario check_bitfield_sizes)
% Hide_errors = true;
== 0x1
01/add 4/mod
+error: '4/mod' too large to fit in bitfield mod

:(before "End Globals")
map<string, uint32_t> Operand_bound;
:(before "End One-time Setup")
put(Operand_bound, "subop", 1<<3);
put(Operand_bound, "mod", 1<<2);
put(Operand_bound, "rm32", 1<<3);
put(Operand_bound, "base", 1<<3);
put(Operand_bound, "index", 1<<3);
put(Operand_bound, "scale", 1<<2);
put(Operand_bound, "r32", 1<<3);
put(Operand_bound, "disp8", 1<<8);
put(Operand_bound, "disp16", 1<<16);
// no bound needed for disp32
put(Operand_bound, "imm8", 1<<8);
// no bound needed for imm32

:(before "End One-time Setup")
Transform.push_back(check_operand_bounds);
:(code)
void check_operand_bounds(/*const*/ program& p) {
  if (p.segments.empty()) return;
  const segment& seg = p.segments.at(0);
  for (int i = 0;  i < SIZE(seg.lines);  ++i) {
    const line& inst = seg.lines.at(i);
    for (int i = first_operand(inst);  i < SIZE(inst.words);  ++i)
      check_operand_bounds(inst.words.at(i));
    if (trace_contains_errors()) return;  // stop at the first mal-formed instruction
  }
}

void check_operand_bounds(const word& w) {
  for (map<string, uint32_t>::iterator p = Operand_bound.begin();  p != Operand_bound.end();  ++p)
    if (has_metadata(w, p->first))
      if (parse_int(w.data) >= p->second)
        raise << "'" << w.original << "' too large to fit in bitfield " << p->first << '\n' << end();
}

int first_operand(const line& inst) {
  if (inst.words.at(0).data == "0f") return 2;
  if (inst.words.at(0).data == "f3") {
    if (inst.words.at(1).data == "0f")
      return 3;
    else
      return 2;
  }
  return 1;
}

uint32_t parse_int(const string& s) {
  istringstream in(s);
  uint32_t result = 0;
  if (starts_with(s, "0x"))
    in >> std::hex;
  in >> result;
  if (!in) {
    raise << "not a number: " << s << '\n' << end();
    return 0;
  }
  return result;
}

void check_metadata_present(const line& inst, const string& type, uint8_t op) {
  if (!has_metadata(inst, type, op))
    raise << "'" << to_string(inst) << "' (" << get(name, op) << "): missing " << type << " operand\n" << end();
}

bool has_metadata(const line& inst, const string& m, uint8_t op) {
  bool result = false;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (!has_metadata(inst.words.at(i), m)) continue;
    if (result) {
      raise << "'" << to_string(inst) << "' has conflicting " << m << " operands\n" << end();
      return false;
    }
    result = true;
  }
  return result;
}

bool has_metadata(const word& w, const string& m) {
  bool result = false;
  bool metadata_found = false;
  for (int i = 0;  i < SIZE(w.metadata);  ++i) {
    const string& curr = w.metadata.at(i);
    if (!contains_key(Operand_bound, curr)) continue;  // ignore unrecognized metadata
    if (metadata_found) {
      raise << "'" << w.original << "' has conflicting operand types; it should have only one\n" << end();
      return false;
    }
    metadata_found = true;
    result = (curr == m);
  }
  return result;
}

word metadata(const line& inst, const string& m) {
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (has_metadata(inst.words.at(i), m))
      return inst.words.at(i);
  assert(false);
}
