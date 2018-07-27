//: jump to 16-bit offset

//:: jump

:(before "End Initialize Op Names(name)")
put(name, "e9", "jump disp16 bytes away");

:(scenario jump_rel16)
== 0x1
# op  ModR/M  SIB   displacement  immediate
  e9                05 00                     # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000009
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0xe9: {  // jump rel8
  int16_t offset = imm16();
  trace(90, "run") << "jump " << offset << end();
  EIP += offset;
  break;
}
:(code)
int16_t imm16() {
  int16_t result = next();
  result |= (next()<<8);
  return result;
}

//:: jump if equal/zero

:(before "End Initialize Op Names(name)")
put(name_0f, "84", "jump disp16 bytes away if ZF is set");

:(scenario je_rel16_success)
% ZF = true;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 84                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x84: {  // jump rel16 if ZF
  int8_t offset = imm16();
  if (ZF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario je_rel16_fail)
% ZF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 84                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if not equal/not zero

:(before "End Initialize Op Names(name)")
put(name_0f, "85", "jump disp16 bytes away if ZF is not set");

:(scenario jne_rel16_success)
% ZF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 85                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x85: {  // jump rel16 unless ZF
  int8_t offset = imm16();
  if (!ZF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jne_rel16_fail)
% ZF = true;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 85                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if greater

:(before "End Initialize Op Names(name)")
put(name_0f, "8f", "jump disp16 bytes away if greater (ZF is unset, SF == OF)");

:(scenario jg_rel16_success)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8f                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8f: {  // jump rel16 if !SF and !ZF
  int8_t offset = imm16();
  if (!ZF && SF == OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jg_rel16_fail)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8f                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if greater or equal

:(before "End Initialize Op Names(name)")
put(name_0f, "8d", "jump disp16 bytes away if greater or equal (SF == OF)");

:(scenario jge_rel16_success)
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8d                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8d: {  // jump rel16 if !SF
  int8_t offset = imm16();
  if (SF == OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jge_rel16_fail)
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8d                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if lesser

:(before "End Initialize Op Names(name)")
put(name_0f, "8c", "jump disp16 bytes away if lesser (SF != OF)");

:(scenario jl_rel16_success)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8c                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8c: {  // jump rel16 if SF and !ZF
  int8_t offset = imm16();
  if (SF != OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jl_rel16_fail)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8c                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if lesser or equal

:(before "End Initialize Op Names(name)")
put(name_0f, "8e", "jump disp16 bytes away if lesser or equal (ZF is set or SF != OF)");

:(scenario jle_rel16_equal)
% ZF = true;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(scenario jle_rel16_lesser)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x0000000a
-run: inst: 0x00000005

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8e: {  // jump rel16 if SF or ZF
  int8_t offset = imm16();
  if (ZF || SF != OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jle_rel16_greater)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5
