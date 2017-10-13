//:: register indirect addressing

:(scenario add_r32_to_mem_at_r32)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
# word in addresses 0x60-0x63 has value 1
% Mem.at(0x60) = 1;
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX (reg 3) to *EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x01: {  // add r32 to r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "add reg " << NUM(arg2) << " to effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, *arg1, Reg[arg2].i);
  break;
}

:(code)
// Implement tables 2-2 and 2-3 in the Intel manual, Volume 2.
// We return a pointer so that instructions can write to multiple bytes in
// 'Mem' at once.
int32_t* effective_address(uint8_t modrm) {
  uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  uint8_t rm = modrm & 0x7;
  int32_t* result = 0;
  switch (mod) {
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
  // End Mod Special-cases
  default:
    cerr << "unrecognized mod bits: " << NUM(mod) << '\n';
    exit(1);
  }
  return result;
}

//:: register direct addressing

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

:(before "End Mod Special-cases")
case 3:
  // mod 3 is just register direct addressing
  trace(2, "run") << "effective address is reg " << NUM(rm) << end();
  result = &Reg[rm].i;
  break;

//:: lots more tests

:(scenario add_imm32_to_mem_at_r32)
% Reg[3].i = 0x60;
% Mem.at(0x60) = 1;
# op  ModR/M  SIB   displacement  immediate
  81  03                          0a 0b 0c 0d  # add 0x0d0c0b0a to *EBX (reg 3)
+run: combine imm32 0x0d0c0b0a with effective address
+run: effective address is mem at address 0x60 (reg 3)
+run: subop add
+run: storing 0x0d0c0b0b

//:

:(scenario add_mem_at_r32_to_r32)
% Reg[0].i = 0x60;
% Reg[3].i = 0x10;
% Mem.at(0x60) = 1;
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

//:

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
