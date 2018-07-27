//: Operands can refer to bitfields smaller than a byte. This layer packs
//: operands into their containing bytes in the right order.

:(scenario pack_immediate_constants)
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                      0x2a/imm32        # copy 42 to EBX
+transform: packing instruction 'bb 0x2a/imm32'
+transform: instruction after packing: 'bb 2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

:(scenario pack_disp8)
== 0x1
74 2/disp8  # jump 2 bytes away if ZF is set
+transform: packing instruction '74 2/disp8'
+transform: instruction after packing: '74 02'

:(scenarios transform)
:(scenario pack_disp8_negative)
== 0x1
# running this will cause an infinite loop
74 -1/disp8  # jump 1 byte before if ZF is set
+transform: packing instruction '74 -1/disp8'
+transform: instruction after packing: '74 ff'
:(scenarios run)

:(scenario pack_modrm_imm32)
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  81          0/add/subop         3/mod/direct    3/ebx/rm32                                                              1/imm32           # add 1 to EBX
+transform: packing instruction '81 0/add/subop 3/mod/direct 3/ebx/rm32 1/imm32'
+transform: instruction after packing: '81 c3 01 00 00 00'

:(scenario pack_imm32_large)
== 0x1
b9 0x080490a7/imm32  # copy to ECX
+transform: packing instruction 'b9 0x080490a7/imm32'
+transform: instruction after packing: 'b9 a7 90 04 08'

:(before "End One-time Setup")
Transform.push_back(pack_operands);

:(code)
void pack_operands(program& p) {
  trace(99, "transform") << "-- pack operands" << end();
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    if (all_hex_bytes(inst)) continue;
    trace(99, "transform") << "packing instruction '" << to_string(/*with metadata*/inst) << "'" << end();
    pack_operands(inst);
    trace(99, "transform") << "instruction after packing: '" << to_string(/*without metadata*/inst.words) << "'" << end();
  }
}

void pack_operands(line& inst) {
  line new_inst;
  add_opcodes(inst, new_inst);
  add_modrm_byte(inst, new_inst);
  add_sib_byte(inst, new_inst);
  add_disp_bytes(inst, new_inst);
  add_imm_bytes(inst, new_inst);
  inst.words.swap(new_inst.words);
}

void add_opcodes(const line& in, line& out) {
  out.words.push_back(in.words.at(0));
  if (in.words.at(0).data == "0f" || in.words.at(0).data == "f3")
    out.words.push_back(in.words.at(1));
  if (in.words.at(0).data == "f3" && in.words.at(1).data == "0f")
    out.words.push_back(in.words.at(2));
}

void add_modrm_byte(const line& in, line& out) {
  uint8_t mod=0, reg_subop=0, rm32=0;
  bool emit = false;
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_metadata(curr, "mod")) {
      mod = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "rm32")) {
      rm32 = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "r32")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "subop")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
  }
  if (emit)
    out.words.push_back(hex_byte_text((mod << 6) | (reg_subop << 3) | rm32));
}

void add_sib_byte(const line& in, line& out) {
  uint8_t scale=0, index=0, base=0;
  bool emit = false;
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_metadata(curr, "scale")) {
      scale = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "index")) {
      index = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "base")) {
      base = hex_byte(curr.data);
      emit = true;
    }
  }
  if (emit)
    out.words.push_back(hex_byte_text((scale << 6) | (index << 3) | base));
}

void add_disp_bytes(const line& in, line& out) {
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_metadata(curr, "disp8"))
      emit_hex_bytes(out, curr, 1);
    if (has_metadata(curr, "disp16"))
      emit_hex_bytes(out, curr, 2);
    else if (has_metadata(curr, "disp32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void add_imm_bytes(const line& in, line& out) {
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_metadata(curr, "imm8"))
      emit_hex_bytes(out, curr, 1);
    else if (has_metadata(curr, "imm32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void emit_hex_bytes(line& out, const word& w, int num) {
  assert(num <= 4);
  if (!is_hex_int(w.data)) {
    out.words.push_back(w);
    return;
  }
  emit_hex_bytes(out, static_cast<uint32_t>(parse_int(w.data)), num);
}

void emit_hex_bytes(line& out, uint32_t val, int num) {
  assert(num <= 4);
  for (int i = 0;  i < num;  ++i) {
    out.words.push_back(hex_byte_text(val & 0xff));
    val = val >> 8;
  }
}

word hex_byte_text(uint8_t val) {
  ostringstream out;
  out << HEXBYTE << NUM(val);
  word result;
  result.data = out.str();
  result.original = out.str()+"/auto";
  return result;
}

string to_string(const vector<word>& in) {
  ostringstream out;
  for (int i = 0;  i < SIZE(in);  ++i) {
    if (i > 0) out << ' ';
    out << in.at(i).data;
  }
  return out.str();
}

// helper
void transform(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;
  transform(p);
}

:(scenario pack_immediate_constants_hex)
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                      0x2a/imm32        # copy 42 to EBX
+transform: packing instruction 'bb 0x2a/imm32'
+transform: instruction after packing: 'bb 2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

:(scenarios transform)
:(scenario pack_silently_ignores_non_hex)
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                      foo/imm32         # copy foo to EBX
+transform: packing instruction 'bb foo/imm32'
# no change (we're just not printing metadata to the trace)
+transform: instruction after packing: 'bb foo'
$error: 0
:(scenarios run)
