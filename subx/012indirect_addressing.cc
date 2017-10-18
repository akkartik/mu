//: operating on memory at the address provided by some register

:(scenario add_r32_to_mem_at_r32)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX (reg 3) to *EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000011

:(before "End Mod Special-cases")
case 0:
  // mod 0 is usually indirect addressing
  switch (rm) {
  default:
    trace(2, "run") << "effective address is mem at address 0x" << std::hex << Reg[rm].u << " (reg " << NUM(rm) << ")" << end();
    assert(Reg[rm].u + sizeof(int32_t) <= Mem.size());
    result = reinterpret_cast<int32_t*>(&Mem.at(Reg[rm].u));  // rely on the host itself being in little-endian order
    break;
  // End Mod 0 Special-cases
  }
  break;

//:

:(scenario add_mem_at_r32_to_r32)
% Reg[0].i = 0x60;
% Reg[3].i = 0x10;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  03  18                                      # add *EAX (reg 0) to EBX (reg 3)
+run: add effective address to reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "add effective address to reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, Reg[arg1].i, *arg2);
  break;
}

//:: subtract

:(scenario subtract_r32_from_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 10);
% Reg[3].i = 1;
# op  ModRM   SIB   displacement  immediate
  29  18                                      # subtract EBX (reg 3) from *EAX (reg 0)
+run: subtract reg 3 from effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000009

//:

:(scenario subtract_mem_at_r32_from_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
% Reg[3].i = 10;
# op  ModRM   SIB   displacement  immediate
  2b  18                                      # subtract *EAX (reg 0) from EBX (reg 3)
+run: subtract effective address from reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "subtract effective address from reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, Reg[arg1].i, *arg2);
  break;
}

//:: and

:(scenario and_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xff;
# op  ModRM   SIB   displacement  immediate
  21  18                                      # and EBX (reg 3) with *EAX (reg 0)
+run: and reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x0000000d

//:

:(scenario and_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000ff);
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  23  18                                      # and *EAX (reg 0) with EBX (reg 3)
+run: and effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x23: {  // and r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "and effective address with reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(&, Reg[arg1].u, *arg2);
  break;
}

//:: or

:(scenario or_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModRM   SIB   displacement  immediate
  09  18                                      # or EBX (reg 3) with *EAX (reg 0)
+run: or reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0xaabbccdd

//:

:(scenario or_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModRM   SIB   displacement  immediate
  0b  18                                      # or *EAX (reg 0) with EBX (reg 3)
+run: or effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x0b: {  // or r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "or effective address with reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: xor

:(scenario xor_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0xaabb0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModRM   SIB   displacement  immediate
  31  18                                      # xor EBX (reg 3) with *EAX (reg 0)
+run: xor reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x0a0bccdd

//:

:(scenario xor_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModRM   SIB   displacement  immediate
  33  18                                      # xor *EAX (reg 0) with EBX (reg 3)
+run: xor effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x33: {  // xor r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "xor effective address with reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: not

:(scenario not_r32_with_mem_at_r32)
% Reg[3].i = 0x60;
# word at 0x60 is 0x0f0f00ff
% SET_WORD_IN_MEM(0x60, 0x0f0f00ff);
# op  ModRM   SIB   displacement  immediate
  f7  03                                      # negate *EBX (reg 3)
+run: 'not' of effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: storing 0xf0f0ff00

//:: compare (cmp)

:(scenario compare_mem_at_r32_with_r32_greater)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c07;
# op  ModRM   SIB   displacement  immediate
  39  18                                      # compare EBX (reg 3) with *EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=0; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_lesser)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c07);
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  39  18                                      # compare EBX (reg 3) with *EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=1; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_equal)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  39  18                                      # compare EBX (reg 3) with *EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=0; ZF=1; OF=0

//:

:(scenario compare_r32_with_mem_at_r32_greater)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c07);
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  3b  18                                      # compare *EAX (reg 0) with EBX (reg 3)
+run: compare effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3b: {  // set SF if r32 < r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(2, "run") << "compare effective address with reg " << NUM(reg1) << end();
  int32_t arg1 = Reg[reg1].i;
  int32_t* arg2 = effective_address(modrm);
  int32_t tmp1 = arg1 - *arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = arg1 - *arg2;
  OF = (tmp1 != tmp2);
  trace(2, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_r32_with_mem_at_r32_lesser)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c07;
# op  ModRM   SIB   displacement  immediate
  3b  18                                      # compare *EAX (reg 0) with EBX (reg 3)
+run: compare effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_mem_at_r32_equal)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  3b  18                                      # compare *EAX (reg 0) with EBX (reg 3)
+run: compare effective address with reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_r32_to_mem_at_r32)
% Reg[3].i = 0xaf;
% Reg[0].i = 0x60;
# op  ModRM   SIB   displacement  immediate
  89  18                                      # copy EBX (reg 3) to *EAX (reg 0)
+run: copy reg 3 to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x000000af

//:

:(scenario copy_mem_at_r32_to_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000af);
# op  ModRM   SIB   displacement  immediate
  8b  18                                      # copy *EAX (reg 0) to EBX (reg 3)
+run: copy effective address to reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x8b: {  // copy r32 to r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(2, "run") << "copy effective address to reg " << NUM(reg1) << end();
  int32_t* arg2 = effective_address(modrm);
  Reg[reg1].i = *arg2;
  trace(2, "run") << "storing 0x" << HEXWORD << *arg2 << end();
  break;
}

//:: jump

:(scenario jump_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 8);
# op  ModRM   SIB   displacement  immediate
  ff  20                                      # jump to *EAX (reg 0)
  05                              00 00 00 01
  05                              00 00 00 02
+run: inst: 0x00000001
+run: jump to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: jumping to 0x00000008
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0xff: {  // jump to r/m32
  uint8_t modrm = next();
  uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
    case 4: {
      trace(2, "run") << "jump to effective address" << end();
      int32_t* arg2 = effective_address(modrm);
      EIP = *arg2;
      trace(2, "run") << "jumping to 0x" << HEXWORD << EIP << end();
      break;
    }
    // End Op ff Subops
  }
  break;
}

//:: push

:(scenario push_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000af);
% Reg[ESP].u = 0x14;
# op  ModRM   SIB   displacement  immediate
  ff  30                                      # push *EAX (reg 0) to stack
+run: push effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: decrementing ESP to 0x00000010
+run: pushing value 0x000000af

:(before "End Op ff Subops")
case 6: {
  trace(2, "run") << "push effective address" << end();
  const int32_t* val = effective_address(modrm);
  push(*val);
  break;
}

//:: pop

:(scenario pop_mem_at_r32)
% Reg[0].i = 0x60;
% Reg[ESP].u = 0x10;
% SET_WORD_IN_MEM(0x10, 0x00000030);
# op  ModRM   SIB   displacement  immediate
  8f  00                                      # pop stack into *EAX (reg 0)
+run: pop into effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: popping value 0x00000030
+run: incrementing ESP to 0x00000014

:(before "End Single-Byte Opcodes")
case 0x8f: {  // pop stack into r/m32
  uint8_t modrm = next();
  uint8_t subop = (modrm>>3)&0x7;
  switch (subop) {
    case 0: {
      trace(2, "run") << "pop into effective address" << end();
      int32_t* dest = effective_address(modrm);
      *dest = pop();
      break;
    }
  }
  break;
}
