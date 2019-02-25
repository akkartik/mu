//: jump to 32-bit offset

//:: jump

:(before "End Initialize Op Names")
put_new(Name, "e9", "jump disp32 bytes away (jmp)");

:(scenario jump_disp32)
== 0x1
# op  ModR/M  SIB   displacement  immediate
  e9                05 00 00 00               # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: 0x00000001 opcode: e9
+run: jump 5
+run: 0x0000000b opcode: 05
-run: 0x00000006 opcode: 05

:(before "End Single-Byte Opcodes")
case 0xe9: {  // jump disp32
  const int32_t offset = next32();
  trace(Callstack_depth+1, "run") << "jump " << offset << end();
  EIP += offset;
  break;
}

//:: jump if equal/zero

:(before "End Initialize Op Names")
put_new(Name_0f, "84", "jump disp32 bytes away if equal, if ZF is set (jcc/jz/je)");

:(scenario je_disp32_success)
% ZF = true;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 84                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x84: {  // jump disp32 if ZF
  const int32_t offset = next32();
  if (ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario je_disp32_fail)
% ZF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 84                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5

//:: jump if not equal/not zero

:(before "End Initialize Op Names")
put_new(Name_0f, "85", "jump disp32 bytes away if not equal, if ZF is not set (jcc/jnz/jne)");

:(scenario jne_disp32_success)
% ZF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 85                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x85: {  // jump disp32 unless ZF
  const int32_t offset = next32();
  if (!ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jne_disp32_fail)
% ZF = true;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 85                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5

//:: jump if greater

:(before "End Initialize Op Names")
put_new(Name_0f, "8f", "jump disp32 bytes away if greater, if ZF is unset and SF == OF (jcc/jg/jnle)");

:(scenario jg_disp32_success)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8f                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8f: {  // jump disp32 if !SF and !ZF
  const int32_t offset = next32();
  if (!ZF && SF == OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jg_disp32_fail)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8f                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5

//:: jump if greater or equal

:(before "End Initialize Op Names")
put_new(Name_0f, "8d", "jump disp32 bytes away if greater or equal, if SF == OF (jcc/jge/jnl)");

:(scenario jge_disp32_success)
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8d                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8d: {  // jump disp32 if !SF
  const int32_t offset = next32();
  if (SF == OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jge_disp32_fail)
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8d                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5

//:: jump if lesser

:(before "End Initialize Op Names")
put_new(Name_0f, "8c", "jump disp32 bytes away if lesser, if SF != OF (jcc/jl/jnge)");

:(scenario jl_disp32_success)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8c                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8c: {  // jump disp32 if SF and !ZF
  const int32_t offset = next32();
  if (SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jl_disp32_fail)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8c                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5

//:: jump if lesser or equal

:(before "End Initialize Op Names")
put_new(Name_0f, "8e", "jump disp32 bytes away if lesser or equal, if ZF is set or SF != OF (jcc/jle/jng)");

:(scenario jle_disp32_equal)
% ZF = true;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(scenario jle_disp32_lesser)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: jump 5
+run: 0x0000000c opcode: 05
-run: 0x00000007 opcode: 05

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8e: {  // jump disp32 if SF or ZF
  const int32_t offset = next32();
  if (ZF || SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jle_disp32_greater)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f 8e                 05 00 00 00               # skip 1 instruction
  05                                  00 00 00 01
  05                                  00 00 00 02
+run: 0x00000001 opcode: 0f
+run: 0x00000007 opcode: 05
+run: 0x0000000c opcode: 05
-run: jump 5
