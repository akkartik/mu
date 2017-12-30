//: jump to 16-bit offset

//:: jump

:(scenario jump_rel16)
# op  ModRM   SIB   displacement  immediate
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
  trace(2, "run") << "jump " << offset << end();
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

:(scenario je_rel16_success)
% ZF = true;
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario je_rel16_fail)
% ZF = false;
# op      ModRM   SIB   displacement  immediate
  0f 84                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if not equal/not zero

:(scenario jne_rel16_success)
% ZF = false;
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jne_rel16_fail)
% ZF = true;
# op      ModRM   SIB   displacement  immediate
  0f 85                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if greater

:(scenario jg_rel16_success)
% ZF = false;
% SF = false;
% OF = false;
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jg_rel16_fail)
% ZF = false;
% SF = true;
% OF = false;
# op      ModRM   SIB   displacement  immediate
  0f 8f                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if greater or equal

:(scenario jge_rel16_success)
% SF = false;
% OF = false;
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jge_rel16_fail)
% SF = true;
% OF = false;
# op      ModRM   SIB   displacement  immediate
  0f 8d                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if lesser

:(scenario jl_rel16_success)
% ZF = false;
% SF = true;
% OF = false;
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jl_rel16_fail)
% ZF = false;
% SF = false;
% OF = false;
# op      ModRM   SIB   displacement  immediate
  0f 8c                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5

//:: jump if lesser or equal

:(scenario jle_rel16_equal)
% ZF = true;
% SF = false;
% OF = false;
# op      ModRM   SIB   displacement  immediate
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
# op      ModRM   SIB   displacement  immediate
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
    trace(2, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jle_rel16_greater)
% ZF = false;
% SF = false;
% OF = false;
# op      ModRM   SIB   displacement  immediate
  0f 8e                 05 00                     # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000005
+run: inst: 0x0000000a
-run: jump 5
