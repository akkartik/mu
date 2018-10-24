//:: call

:(before "End Initialize Op Names")
put_new(Name, "e8", "call disp32 (call)");

:(scenario call_disp32)
% Reg[ESP].u = 0x64;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  e8                              a0 00 00 00  # call function offset at 0x000000a0
  # next EIP is 6
+run: call imm32 0x000000a0
+run: decrementing ESP to 0x00000060
+run: pushing value 0x00000006
+run: jumping to 0x000000a6

:(before "End Single-Byte Opcodes")
case 0xe8: {  // call disp32 relative to next EIP
  const int32_t offset = next32();
  trace(90, "run") << "call imm32 0x" << HEXWORD << offset << end();
//?   cerr << "push: EIP: " << EIP << " => " << Reg[ESP].u << '\n';
  push(EIP);
  EIP += offset;
  trace(90, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}

//:

:(scenario call_r32)
% Reg[ESP].u = 0x64;
% Reg[EBX].u = 0x000000a0;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  ff  d3                                       # call function offset at EBX
  # next EIP is 3
+run: call to r/m32
+run: r/m32 is EBX
+run: decrementing ESP to 0x00000060
+run: pushing value 0x00000003
+run: jumping to 0x000000a3

:(before "End Op ff Subops")
case 2: {  // call function pointer at r/m32
  trace(90, "run") << "call to r/m32" << end();
  const int32_t* offset = effective_address(modrm);
  push(EIP);
  EIP += *offset;
  trace(90, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}

:(scenario call_mem_at_r32)
% Reg[ESP].u = 0x64;
% Reg[EBX].u = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  13                                       # call function offset at *EBX
  # next EIP is 3
== 0x2000  # data segment
a0 00 00 00  # 0xa0
+run: call to r/m32
+run: effective address is 0x00002000 (EBX)
+run: decrementing ESP to 0x00000060
+run: pushing value 0x00000003
+run: jumping to 0x000000a3

//:: ret

:(before "End Initialize Op Names")
put_new(Name, "c3", "return from most recent unfinished call (ret)");

:(scenario ret)
% Reg[ESP].u = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  c3
== 0x2000  # data segment
10 00 00 00  # 0x10
+run: return
+run: popping value 0x00000010
+run: jumping to 0x00000010

:(before "End Single-Byte Opcodes")
case 0xc3: {  // return from a call
  trace(90, "run") << "return" << end();
  EIP = pop();
  trace(90, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}
