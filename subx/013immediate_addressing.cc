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
% Mem.at(0x60) = 1;
# op  ModR/M  SIB   displacement  immediate
  81  03                          0a 0b 0c 0d  # add 0x0d0c0b0a to *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop add
+run: storing 0x0d0c0b0b

//:: subtract

:(scenario sub_imm32_from_eax)
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

:(scenario sub_imm32_from_mem_at_r32)
% Reg[3].i = 0x60;
% Mem.at(0x60) = 10;
# op  ModRM   SIB   displacement  immediate
  81  2b                          01 00 00 00  # subtract 1 from *EBX (reg 3)
+run: combine imm32 0x00000001 with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop subtract
+run: storing 0x00000009

//:

:(scenario sub_imm32_from_r32)
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
