//: operating directly on a register

:(scenario add_r32_to_r32)
% Reg[0].i = 0x10;
% Reg[3].i = 1;
# op  ModR/M  SIB   displacement  immediate
  01  d8                                      # add EBX (reg 3) to EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is reg 0
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
  case 3:
    // mod 3 is just register direct addressing
    trace(2, "run") << "effective address is reg " << NUM(rm) << end();
    result = &Reg[rm].i;
    break;
  // End Mod Special-cases
  default:
    cerr << "unrecognized mod bits: " << NUM(mod) << '\n';
    exit(1);
  }
  return result;
}

//:: subtract

:(scenario subtract_r32_from_r32)
% Reg[0].i = 10;
% Reg[3].i = 1;
# op  ModR/M  SIB   displacement  immediate
  29  d8                                      # subtract EBX (reg 3) from EAX (reg 0)
+run: subtract reg 3 from effective address
+run: effective address is reg 0
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x29: {  // subtract r32 from r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "subtract reg " << NUM(arg2) << " from effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, *arg1, Reg[arg2].i);
  break;
}

//:: and

:(scenario and_r32_with_r32)
% Reg[0].i = 0x0a0b0c0d;
% Reg[3].i = 0x000000ff;
# op  ModR/M  SIB   displacement  immediate
  21  d8                                      # and EBX (reg 3) with destination EAX (reg 0)
+run: and reg 3 with effective address
+run: effective address is reg 0
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x21: {  // and r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "and reg " << NUM(arg2) << " with effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(&, *arg1, Reg[arg2].u);
  break;
}

//:: or

:(scenario or_r32_with_r32)
% Reg[0].i = 0x0a0b0c0d;
% Reg[3].i = 0xa0b0c0d0;
# op  ModR/M  SIB   displacement  immediate
  09  d8                                      # or EBX (reg 3) with destination EAX (reg 0)
+run: or reg 3 with effective address
+run: effective address is reg 0
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x09: {  // or r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "or reg " << NUM(arg2) << " with effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(|, *arg1, Reg[arg2].u);
  break;
}

//:: xor

:(scenario xor_r32_with_r32)
% Reg[0].i = 0x0a0b0c0d;
% Reg[3].i = 0xaabbc0d0;
# op  ModR/M  SIB   displacement  immediate
  31  d8                                      # xor EBX (reg 3) with destination EAX (reg 0)
+run: xor reg 3 with effective address
+run: effective address is reg 0
+run: storing 0xa0b0ccdd

:(before "End Single-Byte Opcodes")
case 0x31: {  // xor r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "xor reg " << NUM(arg2) << " with effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(^, *arg1, Reg[arg2].u);
  break;
}

//:: not

:(scenario not_r32)
% Reg[3].i = 0x0f0f00ff;
# op  ModR/M  SIB   displacement  immediate
  f7  c3                                      # not EBX (reg 3)
+run: 'not' of effective address
+run: effective address is reg 3
+run: storing 0xf0f0ff00

:(before "End Single-Byte Opcodes")
case 0xf7: {  // xor r32 with r/m32
  uint8_t modrm = next();
  trace(2, "run") << "'not' of effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  *arg1 = ~(*arg1);
  trace(2, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  SF = (*arg1 >> 31);
  ZF = (*arg1 == 0);
  OF = false;
  break;
}

//:: compare (cmp)

:(scenario compare_r32_with_r32_greater)
% Reg[0].i = 0x0a0b0c0d;
% Reg[3].i = 0x0a0b0c07;
# op  ModRM   SIB   displacement  immediate
  39  d8                                      # compare EBX (reg 3) with EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is reg 0
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x39: {  // set SF if r/m32 < r32
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(2, "run") << "compare reg " << NUM(reg2) << " with effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  int32_t arg2 = Reg[reg2].i;
  int32_t tmp1 = *arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = *arg1 - arg2;
  OF = (tmp1 != tmp2);
  trace(2, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_r32_with_r32_lesser)
% Reg[0].i = 0x0a0b0c07;
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  39  d8                                      # compare EBX (reg 3) with EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is reg 0
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_r32_equal)
% Reg[0].i = 0x0a0b0c0d;
% Reg[3].i = 0x0a0b0c0d;
# op  ModRM   SIB   displacement  immediate
  39  d8                                      # compare EBX (reg 3) with EAX (reg 0)
+run: compare reg 3 with effective address
+run: effective address is reg 0
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_r32_to_r32)
% Reg[3].i = 0xaf;
# op  ModRM   SIB   displacement  immediate
  89  d8                                      # copy EBX (reg 3) to EAX (reg 0)
+run: copy reg 3 to effective address
+run: effective address is reg 0
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x89: {  // copy r32 to r/m32
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(2, "run") << "copy reg " << NUM(reg2) << " to effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  *arg1 = Reg[reg2].i;
  trace(2, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

//:: push

:(scenario push_r32)
% Reg[ESP].u = 0x64;
% Reg[EBX].i = 10;
# op  ModRM   SIB   displacement  immediate
  50  03                                      # push EBX (reg 3) to stack
+run: push reg 3
+run: pushing value 0x0000000a
+run: ESP is now 0x00000060
+run: contents at ESP: 0x0000000a

:(before "End Single-Byte Opcodes")
case 0x50: {
  uint8_t modrm = next();
  uint8_t reg = modrm & 0x7;
  trace(2, "run") << "push reg " << NUM(reg) << end();
  const int32_t val = Reg[reg].u;
  trace(2, "run") << "pushing value 0x" << HEXWORD << val << end();
  Reg[ESP].u -= 4;
  *reinterpret_cast<uint32_t*>(&Mem.at(Reg[ESP].u)) = val;
  trace(2, "run") << "ESP is now 0x" << HEXWORD << Reg[ESP].u << end();
  trace(2, "run") << "contents at ESP: 0x" << HEXWORD << *reinterpret_cast<uint32_t*>(&Mem.at(Reg[ESP].u)) << end();
  break;
}
