//: Now that we have labels, using non-label offsets should be unnecessary.
//: While SubX will allow programmers to write raw machine code, that isn't
//: *recommended* once we have more ergonomic alternatives.

:(scenario warn_on_jump_offset)
== 0x1
7e/jump-if 1/disp8
+warn: '7e/jump-if 1/disp8': using raw offsets for jumps is not recommended; use labels instead

:(scenarios transform)
:(scenario warn_on_call_offset)
== 0x1
e8/call 1/disp32
+warn: 'e8/call 1/disp32': using raw offsets for calls is not recommended; use labels instead
:(scenarios run)

:(before "Rewrite Labels(segment code)")
recommend_labels(code);
if (trace_contains_errors()) return;
:(code)
void recommend_labels(const segment& code) {
  trace(99, "transform") << "-- check for numeric labels" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i)
    recommend_labels(code.lines.at(i));
}

void recommend_labels(const line& inst) {
  int idx = first_operand(inst);
  if (idx >= SIZE(inst.words)) return;
  if (!is_number(inst.words.at(idx).data)) return;
  if (is_jump(inst))
    warn << "'" << inst.original << "': using raw offsets for jumps is not recommended; use labels instead\n" << end();
  else if (is_call(inst))
    warn << "'" << inst.original << "': using raw offsets for calls is not recommended; use labels instead\n" << end();
}

bool is_jump(const line& inst) {
  string op1 = preprocess_op(inst.words.at(0)).data;
  if (op1 == "0f") {
    string op2 = preprocess_op(inst.words.at(1)).data;
    return Jump_opcodes_0f.find(op1) != Jump_opcodes_0f.end();
  }
  if (op1 == "ff") return subop(inst) == /*subop for opcode ff*/4;
  return Jump_opcodes.find(op1) != Jump_opcodes.end();
}

bool is_call(const line& inst) {
  string op1 = preprocess_op(inst.words.at(0)).data;
  if (op1 == "e8") return true;
  if (op1 == "ff") return subop(inst) == /*subop for opcode ff*/2;
  return false;  // no multi-byte call opcodes
}

int subop(const line& inst) {
  int idx = first_operand(inst);
  assert(idx < SIZE(inst.words));
  return (parse_int(inst.words.at(idx).data)>>3) & 0x7;
}

:(before "End Globals")
set<string> Jump_opcodes;
set<string> Jump_opcodes_0f;
:(before "End One-time Setup")
init_jump_opcodes();
:(code)
void init_jump_opcodes() {
  Jump_opcodes.insert("74");
  Jump_opcodes.insert("75");
  Jump_opcodes.insert("7c");
  Jump_opcodes.insert("7d");
  Jump_opcodes.insert("7e");
  Jump_opcodes.insert("7f");
  Jump_opcodes_0f.insert("84");
  Jump_opcodes_0f.insert("85");
  Jump_opcodes_0f.insert("8c");
  Jump_opcodes_0f.insert("8d");
  Jump_opcodes_0f.insert("8e");
  Jump_opcodes_0f.insert("8f");
  Jump_opcodes.insert("e9");
  Jump_opcodes.insert("eb");
}
