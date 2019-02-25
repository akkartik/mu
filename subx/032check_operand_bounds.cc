//:: Check that the different operands of an instruction aren't too large for their bitfields.

:(scenario check_bitfield_sizes)
% Hide_errors = true;
== 0x1
01/add 4/mod 3/rm32 1/r32  # add ECX to EBX
+error: '4/mod' too large to fit in bitfield mod

:(before "End Globals")
map<string, uint32_t> Operand_bound;
:(before "End One-time Setup")
put_new(Operand_bound, "subop", 1<<3);
put_new(Operand_bound, "mod", 1<<2);
put_new(Operand_bound, "rm32", 1<<3);
put_new(Operand_bound, "base", 1<<3);
put_new(Operand_bound, "index", 1<<3);
put_new(Operand_bound, "scale", 1<<2);
put_new(Operand_bound, "r32", 1<<3);
put_new(Operand_bound, "disp8", 1<<8);
put_new(Operand_bound, "disp16", 1<<16);
// no bound needed for disp32
put_new(Operand_bound, "imm8", 1<<8);
// no bound needed for imm32

:(before "Pack Operands(segment code)")
check_operand_bounds(code);
if (trace_contains_errors()) return;
:(code)
void check_operand_bounds(const segment& code) {
  trace(3, "transform") << "-- check operand bounds" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    for (int j = first_operand(inst);  j < SIZE(inst.words);  ++j)
      check_operand_bounds(inst.words.at(j));
    if (trace_contains_errors()) return;  // stop at the first mal-formed instruction
  }
}

void check_operand_bounds(const word& w) {
  for (map<string, uint32_t>::iterator p = Operand_bound.begin();  p != Operand_bound.end();  ++p) {
    if (!has_operand_metadata(w, p->first)) continue;
    if (!looks_like_hex_int(w.data)) continue;  // later transforms are on their own to do their own bounds checking
    int32_t x = parse_int(w.data);
    if (x >= 0) {
      if (static_cast<uint32_t>(x) >= p->second)
        raise << "'" << w.original << "' too large to fit in bitfield " << p->first << '\n' << end();
    }
    else {
      // hacky? assuming bound is a power of 2
      if (x < -1*static_cast<int32_t>(p->second/2))
        raise << "'" << w.original << "' too large to fit in bitfield " << p->first << '\n' << end();
    }
  }
}
