//: operating directly on a register

:(before "End Initialize Op Names(name)")
put(name, "01", "add r32 to rm32");

:(scenario add_r32_to_r32)
% Reg[EAX].i = 0x10;
% Reg[EBX].i = 1;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  01  d8                                      # add EBX to EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: add EBX to r/m32
+run: r/m32 is EAX
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x01: {  // add r32 to r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "add " << rname(arg2) << " to r/m32" << end();
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
  uint32_t addr = 0;
  switch (mod) {
  case 3:
    // mod 3 is just register direct addressing
    trace(90, "run") << "r/m32 is " << rname(rm) << end();
    return &Reg[rm].i;
  // End Mod Special-cases(addr)
  default:
    cerr << "unrecognized mod bits: " << NUM(mod) << '\n';
    exit(1);
  }
  //: other mods are indirect, and they'll set addr appropriately
  return mem_addr_i32(addr);
}

string rname(uint8_t r) {
  switch (r) {
  case 0: return "EAX";
  case 1: return "ECX";
  case 2: return "EDX";
  case 3: return "EBX";
  case 4: return "ESP";
  case 5: return "EBP";
  case 6: return "ESI";
  case 7: return "EDI";
  default: raise << "invalid register " << r << '\n' << end();  return "";
  }
}

//:: subtract

:(before "End Initialize Op Names(name)")
put(name, "29", "subtract r32 from rm32");

:(scenario subtract_r32_from_r32)
% Reg[EAX].i = 10;
% Reg[EBX].i = 1;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  29  d8                                      # subtract EBX from EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: subtract EBX from r/m32
+run: r/m32 is EAX
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x29: {  // subtract r32 from r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "subtract " << rname(arg2) << " from r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, *arg1, Reg[arg2].i);
  break;
}

//:: multiply

:(before "End Initialize Op Names(name)")
put(name_0f, "af", "multiply r32 into rm32");

:(scenario multiply_r32_into_r32)
% Reg[EAX].i = 4;
% Reg[EBX].i = 2;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f af   d8                                      # subtract EBX into EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: multiply EBX into r/m32
+run: r/m32 is EAX
+run: storing 0x00000008

:(before "End Two-Byte Opcodes Starting With 0f")
case 0xaf: {  // multiply r32 into r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "multiply " << rname(arg2) << " into r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(*, *arg1, Reg[arg2].i);
  break;
}

//:: and

:(before "End Initialize Op Names(name)")
put(name, "21", "rm32 = bitwise AND of r32 with rm32");

:(scenario and_r32_with_r32)
% Reg[EAX].i = 0x0a0b0c0d;
% Reg[EBX].i = 0x000000ff;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  21  d8                                      # and EBX with destination EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: and EBX with r/m32
+run: r/m32 is EAX
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x21: {  // and r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "and " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(&, *arg1, Reg[arg2].u);
  break;
}

//:: or

:(before "End Initialize Op Names(name)")
put(name, "09", "rm32 = bitwise OR of r32 with rm32");

:(scenario or_r32_with_r32)
% Reg[EAX].i = 0x0a0b0c0d;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  09  d8                                      # or EBX with destination EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: or EBX with r/m32
+run: r/m32 is EAX
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x09: {  // or r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "or " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(|, *arg1, Reg[arg2].u);
  break;
}

//:: xor

:(before "End Initialize Op Names(name)")
put(name, "31", "rm32 = bitwise XOR of r32 with rm32");

:(scenario xor_r32_with_r32)
% Reg[EAX].i = 0x0a0b0c0d;
% Reg[EBX].i = 0xaabbc0d0;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  31  d8                                      # xor EBX with destination EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: xor EBX with r/m32
+run: r/m32 is EAX
+run: storing 0xa0b0ccdd

:(before "End Single-Byte Opcodes")
case 0x31: {  // xor r32 with r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "xor " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(^, *arg1, Reg[arg2].u);
  break;
}

//:: not

:(before "End Initialize Op Names(name)")
put(name, "f7", "bitwise complement of rm32");

:(scenario not_r32)
% Reg[EBX].i = 0x0f0f00ff;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  f7  c3                                      # not EBX
# ModR/M in binary: 11 (direct mode) 000 (unused) 011 (dest EBX)
+run: 'not' of r/m32
+run: r/m32 is EBX
+run: storing 0xf0f0ff00

:(before "End Single-Byte Opcodes")
case 0xf7: {  // xor r32 with r/m32
  uint8_t modrm = next();
  trace(90, "run") << "'not' of r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  *arg1 = ~(*arg1);
  trace(90, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  SF = (*arg1 >> 31);
  ZF = (*arg1 == 0);
  OF = false;
  break;
}

//:: compare (cmp)

:(before "End Initialize Op Names(name)")
put(name, "39", "set SF if rm32 < r32");

:(scenario compare_r32_with_r32_greater)
% Reg[EAX].i = 0x0a0b0c0d;
% Reg[EBX].i = 0x0a0b0c07;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  39  d8                                      # compare EBX with EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: r/m32 is EAX
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x39: {  // set SF if r/m32 < r32
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "compare " << rname(reg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  int32_t arg2 = Reg[reg2].i;
  int32_t tmp1 = *arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = *arg1 - arg2;
  OF = (tmp1 != tmp2);
  trace(90, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_r32_with_r32_lesser)
% Reg[EAX].i = 0x0a0b0c07;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  39  d8                                      # compare EBX with EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: r/m32 is EAX
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_r32_equal)
% Reg[EAX].i = 0x0a0b0c0d;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  39  d8                                      # compare EBX with EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: r/m32 is EAX
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(before "End Initialize Op Names(name)")
put(name, "89", "copy r32 to rm32");

:(scenario copy_r32_to_r32)
% Reg[EBX].i = 0xaf;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  89  d8                                      # copy EBX to EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: copy EBX to r/m32
+run: r/m32 is EAX
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x89: {  // copy r32 to r/m32
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "copy " << rname(reg2) << " to r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  *arg1 = Reg[reg2].i;
  trace(90, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

//:: xchg

:(before "End Initialize Op Names(name)")
put(name, "87", "swap the contents of r32 and rm32");

:(scenario xchg_r32_with_r32)
% Reg[EBX].i = 0xaf;
% Reg[EAX].i = 0x2e;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  87  d8                                      # exchange EBX with EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: exchange EBX with r/m32
+run: r/m32 is EAX
+run: storing 0x000000af in r/m32
+run: storing 0x0000002e in EBX

:(before "End Single-Byte Opcodes")
case 0x87: {  // exchange r32 with r/m32
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "exchange " << rname(reg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  int32_t tmp = *arg1;
  *arg1 = Reg[reg2].i;
  Reg[reg2].i = tmp;
  trace(90, "run") << "storing 0x" << HEXWORD << *arg1 << " in r/m32" << end();
  trace(90, "run") << "storing 0x" << HEXWORD << Reg[reg2].i << " in " << rname(reg2) << end();
  break;
}

//:: push

:(before "End Initialize Op Names(name)")
put(name, "50", "push R0 (EAX) to stack");
put(name, "51", "push R1 (ECX) to stack");
put(name, "52", "push R2 (EDX) to stack");
put(name, "53", "push R3 (EBX) to stack");
put(name, "54", "push R4 (ESP) to stack");
put(name, "55", "push R5 (EBP) to stack");
put(name, "56", "push R6 (ESI) to stack");
put(name, "57", "push R7 (EDI) to stack");

:(scenario push_r32)
% Reg[ESP].u = 0x64;
% Reg[EBX].i = 0x0000000a;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  53                                          # push EBX to stack
+run: push EBX
+run: decrementing ESP to 0x00000060
+run: pushing value 0x0000000a

:(before "End Single-Byte Opcodes")
case 0x50:
case 0x51:
case 0x52:
case 0x53:
case 0x54:
case 0x55:
case 0x56:
case 0x57: {  // push r32 to stack
  uint8_t reg = op & 0x7;
  trace(90, "run") << "push " << rname(reg) << end();
  push(Reg[reg].u);
  break;
}
:(code)
void push(uint32_t val) {
  Reg[ESP].u -= 4;
  trace(90, "run") << "decrementing ESP to 0x" << HEXWORD << Reg[ESP].u << end();
  trace(90, "run") << "pushing value 0x" << HEXWORD << val << end();
  write_mem_u32(Reg[ESP].u, val);
}

//:: pop

:(before "End Initialize Op Names(name)")
put(name, "58", "pop top of stack to R0 (EAX)");
put(name, "59", "pop top of stack to R1 (ECX)");
put(name, "5a", "pop top of stack to R2 (EDX)");
put(name, "5b", "pop top of stack to R3 (EBX)");
put(name, "5c", "pop top of stack to R4 (ESP)");
put(name, "5d", "pop top of stack to R5 (EBP)");
put(name, "5e", "pop top of stack to R6 (ESI)");
put(name, "5f", "pop top of stack to R7 (EDI)");

:(scenario pop_r32)
% Reg[ESP].u = 0x60;
% write_mem_i32(0x60, 0x0000000a);
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  5b                                          # pop stack to EBX
== 0x60  # data segment
0a 00 00 00  # 0x0a
+run: pop into EBX
+run: popping value 0x0000000a
+run: incrementing ESP to 0x00000064

:(before "End Single-Byte Opcodes")
case 0x58:
case 0x59:
case 0x5a:
case 0x5b:
case 0x5c:
case 0x5d:
case 0x5e:
case 0x5f: {  // pop stack into r32
  uint8_t reg = op & 0x7;
  trace(90, "run") << "pop into " << rname(reg) << end();
  Reg[reg].u = pop();
  break;
}
:(code)
uint32_t pop() {
  uint32_t result = read_mem_u32(Reg[ESP].u);
  trace(90, "run") << "popping value 0x" << HEXWORD << result << end();
  Reg[ESP].u += 4;
  trace(90, "run") << "incrementing ESP to 0x" << HEXWORD << Reg[ESP].u << end();
  return result;
}
