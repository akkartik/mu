//:: call

:(before "End Initialize Op Names")
put_new(Name, "e8", "call disp32 (call)");

:(code)
void test_call_disp32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000064;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  e8                                 a0 00 00 00 \n"  // call function offset at 0xa0
      // next EIP is 6
  );
  CHECK_TRACE_CONTENTS(
      "run: call imm32 0x000000a0\n"
      "run: decrementing ESP to 0xbd000060\n"
      "run: pushing value 0x00000006\n"
      "run: jumping to 0x000000a6\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xe8: {  // call disp32 relative to next EIP
  const int32_t offset = next32();
  ++Callstack_depth;
  trace(Callstack_depth+1, "run") << "call imm32 0x" << HEXWORD << offset << end();
//?   cerr << "push: EIP: " << EIP << " => " << Reg[ESP].u << '\n';
  push(EIP);
  EIP += offset;
  trace(Callstack_depth+1, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}

//:

:(code)
void test_call_r32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000064;
  Reg[EBX].u = 0x000000a0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  ff     d3                                      \n"  // call function offset at EBX
      // next EIP is 3
  );
  CHECK_TRACE_CONTENTS(
      "run: call to r/m32\n"
      "run: r/m32 is EBX\n"
      "run: decrementing ESP to 0xbd000060\n"
      "run: pushing value 0x00000003\n"
      "run: jumping to 0x000000a0\n"
  );
}

:(before "End Op ff Subops")
case 2: {  // call function pointer at r/m32
  trace(Callstack_depth+1, "run") << "call to r/m32" << end();
  const int32_t* offset = effective_address(modrm);
  push(EIP);
  EIP = *offset;
  trace(Callstack_depth+1, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  ++Callstack_depth;
  break;
}

:(code)
void test_call_mem_at_rm32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000064;
  Reg[EBX].u = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  ff     13                                      \n"  // call function offset at *EBX
      // next EIP is 3
      "== data 0x2000\n"
      "a0 00 00 00\n"  // 0xa0
  );
  CHECK_TRACE_CONTENTS(
      "run: call to r/m32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: decrementing ESP to 0xbd000060\n"
      "run: pushing value 0x00000003\n"
      "run: jumping to 0x000000a0\n"
  );
}

//:: ret

:(before "End Initialize Op Names")
put_new(Name, "c3", "return from most recent unfinished call (ret)");

:(code)
void test_ret() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000064;
  write_mem_u32(Reg[ESP].u, 0x10);
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c3                                           \n"  // return
      "== data 0x2000\n"
      "10 00 00 00\n"  // 0x10
  );
  CHECK_TRACE_CONTENTS(
      "run: return\n"
      "run: popping value 0x00000010\n"
      "run: jumping to 0x00000010\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xc3: {  // return from a call
  trace(Callstack_depth+1, "run") << "return" << end();
  --Callstack_depth;
  EIP = pop();
  trace(Callstack_depth+1, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}
