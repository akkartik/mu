//: instructions that (immediately) contain an argument to act with

:(scenario add_imm32_to_r32)
% Reg[3].i = 1;
# op  ModRM   SIB   displacement  immediate
  81  c3                          0a 0b 0c 0d  # add 0x0d0c0b0a to EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: subop add
+run: storing 0x0d0c0b0b

:(before "End Single-Byte Opcodes")
case 0x81: {  // combine imm32 with r/m32
  uint8_t modrm = next();
  int32_t arg2 = imm32();
  trace(2, "run") << "combine imm32 0x" << HEXWORD << arg2 << " with effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 0:
    trace(2, "run") << "subop add" << end();
    BINARY_ARITHMETIC_OP(+, *arg1, arg2);
    break;
  // End Op 81 Subops
  default:
    cerr << "unrecognized sub-opcode after 81: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

//:

:(scenario add_imm32_to_mem_at_r32)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  81  03                          0a 0b 0c 0d  # add 0x0d0c0b0a to *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop add
+run: storing 0x0d0c0b0b

//:: subtract

:(scenario subtract_imm32_from_eax)
% Reg[EAX].i = 0x0d0c0baa;
# op  ModR/M  SIB   displacement  immediate
  2d                              0a 0b 0c 0d  # subtract 0x0d0c0b0a from EAX (reg 0)
+run: subtract imm32 0x0d0c0b0a from reg EAX
+run: storing 0x000000a0

:(before "End Single-Byte Opcodes")
case 0x2d: {  // subtract imm32 from EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "subtract imm32 0x" << HEXWORD << arg2 << " from reg EAX" << end();
  BINARY_ARITHMETIC_OP(-, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario subtract_imm32_from_mem_at_r32)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 10);
# op  ModRM   SIB   displacement  immediate
  81  2b                          01 00 00 00  # subtract 1 from *EBX (reg 3)
+run: combine imm32 0x00000001 with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop subtract
+run: storing 0x00000009

//:

:(scenario subtract_imm32_from_r32)
% Reg[3].i = 10;
# op  ModRM   SIB   displacement  immediate
  81  eb                          01 00 00 00  # subtract 1 from EBX (reg 3)
+run: combine imm32 0x00000001 with effective address
+run: effective address is reg 3
+run: subop subtract
+run: storing 0x00000009

:(before "End Op 81 Subops")
case 5: {
  trace(2, "run") << "subop subtract" << end();
  BINARY_ARITHMETIC_OP(-, *arg1, arg2);
  break;
}

//:: and

:(scenario and_imm32_with_eax)
% Reg[EAX].i = 0xff;
# op  ModR/M  SIB   displacement  immediate
  25                              0a 0b 0c 0d  # and 0x0d0c0b0a with EAX (reg 0)
+run: and imm32 0x0d0c0b0a with reg EAX
+run: storing 0x0000000a

:(before "End Single-Byte Opcodes")
case 0x25: {  // and imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "and imm32 0x" << HEXWORD << arg2 << " with reg EAX" << end();
  BINARY_BITWISE_OP(&, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario and_imm32_with_mem_at_r32)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000ff);
# op  ModRM   SIB   displacement  immediate
  81  23                          0a 0b 0c 0d  # and 0x0d0c0b0a with *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop and
+run: storing 0x0000000a

//:

:(scenario and_imm32_with_r32)
% Reg[3].i = 0xff;
# op  ModRM   SIB   displacement  immediate
  81  e3                          0a 0b 0c 0d  # and 0x0d0c0b0a with EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: subop and
+run: storing 0x0000000a

:(before "End Op 81 Subops")
case 4: {
  trace(2, "run") << "subop and" << end();
  BINARY_BITWISE_OP(&, *arg1, arg2);
  break;
}

//:: or

:(scenario or_imm32_with_eax)
% Reg[EAX].i = 0xd0c0b0a0;
# op  ModR/M  SIB   displacement  immediate
  0d                              0a 0b 0c 0d  # or 0x0d0c0b0a with EAX (reg 0)
+run: or imm32 0x0d0c0b0a with reg EAX
+run: storing 0xddccbbaa

:(before "End Single-Byte Opcodes")
case 0x0d: {  // or imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "or imm32 0x" << HEXWORD << arg2 << " with reg EAX" << end();
  BINARY_BITWISE_OP(|, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario or_imm32_with_mem_at_r32)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0xd0c0b0a0);
# op  ModRM   SIB   displacement  immediate
  81  0b                          0a 0b 0c 0d  # or 0x0d0c0b0a with *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop or
+run: storing 0xddccbbaa

//:

:(scenario or_imm32_with_r32)
% Reg[3].i = 0xd0c0b0a0;
# op  ModRM   SIB   displacement  immediate
  81  cb                          0a 0b 0c 0d  # or 0x0d0c0b0a with EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: subop or
+run: storing 0xddccbbaa

:(before "End Op 81 Subops")
case 1: {
  trace(2, "run") << "subop or" << end();
  BINARY_BITWISE_OP(|, *arg1, arg2);
  break;
}

//:: xor

:(scenario xor_imm32_with_eax)
% Reg[EAX].i = 0xddccb0a0;
# op  ModR/M  SIB   displacement  immediate
  35                              0a 0b 0c 0d  # xor 0x0d0c0b0a with EAX (reg 0)
+run: xor imm32 0x0d0c0b0a with reg EAX
+run: storing 0xd0c0bbaa

:(before "End Single-Byte Opcodes")
case 0x35: {  // xor imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "xor imm32 0x" << HEXWORD << arg2 << " with reg EAX" << end();
  BINARY_BITWISE_OP(^, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario xor_imm32_with_mem_at_r32)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0xd0c0b0a0);
# op  ModRM   SIB   displacement  immediate
  81  33                          0a 0b 0c 0d  # xor 0x0d0c0b0a with *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop xor
+run: storing 0xddccbbaa

//:

:(scenario xor_imm32_with_r32)
% Reg[3].i = 0xd0c0b0a0;
# op  ModRM   SIB   displacement  immediate
  81  f3                          0a 0b 0c 0d  # xor 0x0d0c0b0a with EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: subop xor
+run: storing 0xddccbbaa

:(before "End Op 81 Subops")
case 6: {
  trace(2, "run") << "subop xor" << end();
  BINARY_BITWISE_OP(^, *arg1, arg2);
  break;
}

//:: compare

:(scenario compare_imm32_with_eax_greater)
% Reg[0].i = 0x0d0c0b0a;
# op  ModRM   SIB   displacement  immediate
  3d                              07 0b 0c 0d  # compare 0x0d0c0b07 with EAX (reg 0)
+run: compare reg EAX and imm32 0x0d0c0b07
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3d: {  // subtract imm32 from EAX
  int32_t arg1 = Reg[EAX].i;
  int32_t arg2 = imm32();
  trace(2, "run") << "compare reg EAX and imm32 0x" << HEXWORD << arg2 << end();
  int32_t tmp1 = arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = arg1 - arg2;
  OF = (tmp1 != tmp2);
  trace(2, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_imm32_with_eax_lesser)
% Reg[0].i = 0x0d0c0b07;
# op  ModRM   SIB   displacement  immediate
  3d                              0a 0b 0c 0d  # compare 0x0d0c0b0a with EAX (reg 0)
+run: compare reg EAX and imm32 0x0d0c0b0a
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_eax_equal)
% Reg[0].i = 0x0d0c0b0a;
# op  ModRM   SIB   displacement  immediate
  3d                              0a 0b 0c 0d  # compare 0x0d0c0b0a with EAX (reg 0)
+run: compare reg EAX and imm32 0x0d0c0b0a
+run: SF=0; ZF=1; OF=0

//:

:(scenario compare_imm32_with_r32_greater)
% Reg[3].i = 0x0d0c0b0a;
# op  ModRM   SIB   displacement  immediate
  81  fb                          07 0b 0c 0d  # compare 0x0d0c0b07 with EBX (reg 3)
+run: combine imm32 0x0d0c0b07 with effective address
+run: effective address is reg 3
+run: SF=0; ZF=0; OF=0

:(before "End Op 81 Subops")
case 7: {
  trace(2, "run") << "subop compare" << end();
  int32_t tmp1 = *arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = *arg1 - arg2;
  OF = (tmp1 != tmp2);
  trace(2, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_imm32_with_r32_lesser)
% Reg[3].i = 0x0d0c0b07;
# op  ModRM   SIB   displacement  immediate
  81  fb                          0a 0b 0c 0d  # compare 0x0d0c0b0a with EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_r32_equal)
% Reg[3].i = 0x0d0c0b0a;
# op  ModRM   SIB   displacement  immediate
  81  fb                          0a 0b 0c 0d  # compare 0x0d0c0b0a with EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is reg 3
+run: SF=0; ZF=1; OF=0

:(scenario compare_imm32_with_mem_at_r32_greater)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0d0c0b0a);
# op  ModRM   SIB   displacement  immediate
  81  3b                          07 0b 0c 0d  # compare 0x0d0c0b07 with *EBX (reg 3)
+run: combine imm32 0x0d0c0b07 with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: SF=0; ZF=0; OF=0

:(scenario compare_imm32_with_mem_at_r32_lesser)
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0d0c0b07);
# op  ModRM   SIB   displacement  immediate
  81  3b                          0a 0b 0c 0d  # compare 0x0d0c0b0a with *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_mem_at_r32_equal)
% Reg[3].i = 0x0d0c0b0a;
% Reg[3].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0d0c0b0a);
# op  ModRM   SIB   displacement  immediate
  81  3b                          0a 0b 0c 0d  # compare 0x0d0c0b0a with *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: SF=0; ZF=1; OF=0
