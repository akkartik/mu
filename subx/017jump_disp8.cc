//: jump to 8-bit offset

//:: jump

:(before "End Initialize Op Names")
put_new(Name, "eb", "jump disp8 bytes away (jmp)");

:(scenario jump_rel8)
== 0x1
# op  ModR/M  SIB   displacement  immediate
  eb                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0xeb: {  // jump rel8
  int8_t offset = static_cast<int>(next());
  trace(90, "run") << "jump " << NUM(offset) << end();
  EIP += offset;
  break;
}

//:: jump if equal/zero

:(before "End Initialize Op Names")
put_new(Name, "74", "jump disp8 bytes away if equal, if ZF is set (jcc/jz/je)");

:(scenario je_rel8_success)
% ZF = true;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  74                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x74: {  // jump rel8 if ZF
  const int8_t offset = static_cast<int>(next());
  if (ZF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario je_rel8_fail)
% ZF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  74                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5

//:: jump if not equal/not zero

:(before "End Initialize Op Names")
put_new(Name, "75", "jump disp8 bytes away if not equal, if ZF is not set (jcc/jnz/jne)");

:(scenario jne_rel8_success)
% ZF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  75                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x75: {  // jump rel8 unless ZF
  const int8_t offset = static_cast<int>(next());
  if (!ZF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jne_rel8_fail)
% ZF = true;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  75                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5

//:: jump if greater

:(before "End Initialize Op Names")
put_new(Name, "7f", "jump disp8 bytes away if greater, if ZF is unset and SF == OF (jcc/jg/jnle)");

:(scenario jg_rel8_success)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7f                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x7f: {  // jump rel8 if !SF and !ZF
  const int8_t offset = static_cast<int>(next());
  if (!ZF && SF == OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jg_rel8_fail)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7f                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5

//:: jump if greater or equal

:(before "End Initialize Op Names")
put_new(Name, "7d", "jump disp8 bytes away if greater or equal, if SF == OF (jcc/jge/jnl)");

:(scenario jge_rel8_success)
% SF = false;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7d                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x7d: {  // jump rel8 if !SF
  const int8_t offset = static_cast<int>(next());
  if (SF == OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jge_rel8_fail)
% SF = true;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7d                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5

//:: jump if lesser

:(before "End Initialize Op Names")
put_new(Name, "7c", "jump disp8 bytes away if lesser, if SF != OF (jcc/jl/jnge)");

:(scenario jl_rel8_success)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7c                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x7c: {  // jump rel8 if SF and !ZF
  const int8_t offset = static_cast<int>(next());
  if (SF != OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jl_rel8_fail)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7c                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5

//:: jump if lesser or equal

:(before "End Initialize Op Names")
put_new(Name, "7e", "jump disp8 bytes away if lesser or equal, if ZF is set or SF != OF (jcc/jle/jng)");

:(scenario jle_rel8_equal)
% ZF = true;
% SF = false;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7e                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(scenario jle_rel8_lesser)
% ZF = false;
% SF = true;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7e                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump 5
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0x7e: {  // jump rel8 if SF or ZF
  const int8_t offset = static_cast<int>(next());
  if (ZF || SF != OF) {
    trace(90, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(scenario jle_rel8_greater)
% ZF = false;
% SF = false;
% OF = false;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  7e                05                        # skip 1 instruction
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: inst: 0x00000003
+run: inst: 0x00000008
-run: jump 5
