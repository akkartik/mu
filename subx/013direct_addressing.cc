//: operating directly on a register

:(before "End Initialize Op Names(name)")
put(name, "01", "add r32 to rm32 (add)");

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
  const uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  const uint8_t rm = modrm & 0x7;
  if (mod == 3) {
    // mod 3 is just register direct addressing
    trace(90, "run") << "r/m32 is " << rname(rm) << end();
    return &Reg[rm].i;
  }
  return mem_addr_i32(effective_address_number(modrm));
}

uint32_t effective_address_number(uint8_t modrm) {
  const uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  const uint8_t rm = modrm & 0x7;
  uint32_t addr = 0;
  switch (mod) {
  case 3:
    // mod 3 is just register direct addressing
    raise << "unexpected direct addressing mode\n" << end();
    return 0;
  // End Mod Special-cases(addr)
  default:
    cerr << "unrecognized mod bits: " << NUM(mod) << '\n';
    exit(1);
  }
  //: other mods are indirect, and they'll set addr appropriately
  return addr;
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
put(name, "29", "subtract r32 from rm32 (sub)");

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
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "subtract " << rname(arg2) << " from r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, *arg1, Reg[arg2].i);
  break;
}

//:: multiply

:(before "End Initialize Op Names(name)")
put(name, "f7", "negate/multiply rm32 (with EAX if necessary) depending on subop (neg/mul)");

:(scenario multiply_eax_by_r32)
% Reg[EAX].i = 4;
% Reg[ECX].i = 3;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  f7      e1                                      # multiply EAX by ECX
# ModR/M in binary: 11 (direct mode) 100 (subop mul) 001 (src ECX)
+run: operate on r/m32
+run: r/m32 is ECX
+run: subop: multiply EAX by r/m32
+run: storing 0x0000000c

:(before "End Single-Byte Opcodes")
case 0xf7: {  // xor r32 with r/m32
  const uint8_t modrm = next();
  trace(90, "run") << "operate on r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 4: {  // mul unsigned EAX by r/m32
    trace(90, "run") << "subop: multiply EAX by r/m32" << end();
    const uint64_t result = Reg[EAX].u * static_cast<uint32_t>(*arg1);
    Reg[EAX].u = result & 0xffffffff;
    Reg[EDX].u = result >> 32;
    OF = (Reg[EDX].u != 0);
    trace(90, "run") << "storing 0x" << HEXWORD << Reg[EAX].u << end();
    break;
  }
  // End Op f7 Subops
  default:
    cerr << "unrecognized sub-opcode after f7: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

//:

:(before "End Initialize Op Names(name)")
put(name_0f, "af", "multiply rm32 into r32 (imul)");

:(scenario multiply_r32_into_r32)
% Reg[EAX].i = 4;
% Reg[EBX].i = 2;
== 0x1
# op      ModR/M  SIB   displacement  immediate
  0f af   d8                                      # subtract EBX into EAX
# ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
+run: multiply r/m32 into EBX
+run: r/m32 is EAX
+run: storing 0x00000008

:(before "End Two-Byte Opcodes Starting With 0f")
case 0xaf: {  // multiply r32 into r/m32
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "multiply r/m32 into " << rname(arg2) << end();
  const int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(*, Reg[arg2].i, *arg1);
  break;
}

//:: and

:(before "End Initialize Op Names(name)")
put(name, "21", "rm32 = bitwise AND of r32 with rm32 (and)");

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
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "and " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(&, *arg1, Reg[arg2].u);
  break;
}

//:: or

:(before "End Initialize Op Names(name)")
put(name, "09", "rm32 = bitwise OR of r32 with rm32 (or)");

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
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "or " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(|, *arg1, Reg[arg2].u);
  break;
}

//:: xor

:(before "End Initialize Op Names(name)")
put(name, "31", "rm32 = bitwise XOR of r32 with rm32 (xor)");

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
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(90, "run") << "xor " << rname(arg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_BITWISE_OP(^, *arg1, Reg[arg2].u);
  break;
}

//:: not

:(scenario not_r32)
% Reg[EBX].i = 0x0f0f00ff;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  f7  d3                                      # not EBX
# ModR/M in binary: 11 (direct mode) 010 (subop not) 011 (dest EBX)
+run: operate on r/m32
+run: r/m32 is EBX
+run: subop: not
+run: storing 0xf0f0ff00

:(before "End Op f7 Subops")
case 2: {  // not r/m32
  trace(90, "run") << "subop: not" << end();
  *arg1 = ~(*arg1);
  trace(90, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  SF = (*arg1 >> 31);
  ZF = (*arg1 == 0);
  OF = false;
  break;
}

//:: compare (cmp)

:(before "End Initialize Op Names(name)")
put(name, "39", "compare: set SF if rm32 < r32 (cmp)");

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
  const uint8_t modrm = next();
  const uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "compare " << rname(reg2) << " with r/m32" << end();
  const int32_t* arg1 = effective_address(modrm);
  const int32_t arg2 = Reg[reg2].i;
  const int32_t tmp1 = *arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  const int64_t tmp2 = *arg1 - arg2;
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
put(name, "89", "copy r32 to rm32 (mov)");

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
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(90, "run") << "copy " << rname(rsrc) << " to r/m32" << end();
  int32_t* dest = effective_address(modrm);
  *dest = Reg[rsrc].i;
  trace(90, "run") << "storing 0x" << HEXWORD << *dest << end();
  break;
}

//:: xchg

:(before "End Initialize Op Names(name)")
put(name, "87", "swap the contents of r32 and rm32 (xchg)");

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
  const uint8_t modrm = next();
  const uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "exchange " << rname(reg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const int32_t tmp = *arg1;
  *arg1 = Reg[reg2].i;
  Reg[reg2].i = tmp;
  trace(90, "run") << "storing 0x" << HEXWORD << *arg1 << " in r/m32" << end();
  trace(90, "run") << "storing 0x" << HEXWORD << Reg[reg2].i << " in " << rname(reg2) << end();
  break;
}

//:: increment

:(before "End Initialize Op Names(name)")
put(name, "40", "increment EAX (inc)");
put(name, "41", "increment ECX (inc)");
put(name, "42", "increment EDX (inc)");
put(name, "43", "increment EBX (inc)");
put(name, "44", "increment ESP (inc)");
put(name, "45", "increment EBP (inc)");
put(name, "46", "increment ESI (inc)");
put(name, "47", "increment EDI (inc)");

:(scenario increment_r32)
% Reg[ECX].u = 0x1f;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  41                                          # increment ECX
+run: increment ECX
+run: storing value 0x00000020

:(before "End Single-Byte Opcodes")
case 0x40:
case 0x41:
case 0x42:
case 0x43:
case 0x44:
case 0x45:
case 0x46:
case 0x47: {  // increment r32
  const uint8_t reg = op & 0x7;
  trace(90, "run") << "increment " << rname(reg) << end();
  ++Reg[reg].u;
  trace(90, "run") << "storing value 0x" << HEXWORD << Reg[reg].u << end();
  break;
}

:(before "End Initialize Op Names(name)")
put(name, "ff", "increment/decrement/jump/push/call rm32 based on subop (inc/dec/jmp/push/call)");

:(scenario increment_rm32)
% Reg[EAX].u = 0x20;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  c0                                      # increment EAX
# ModR/M in binary: 11 (direct mode) 000 (subop inc) 000 (EAX)
+run: increment r/m32
+run: r/m32 is EAX
+run: storing value 0x00000021

:(before "End Single-Byte Opcodes")
case 0xff: {
  const uint8_t modrm = next();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
    case 0: {  // increment r/m32
      trace(90, "run") << "increment r/m32" << end();
      int32_t* arg = effective_address(modrm);
      ++*arg;
      trace(90, "run") << "storing value 0x" << HEXWORD << *arg << end();
      break;
    }
    // End Op ff Subops
  }
  break;
}

//:: decrement

:(before "End Initialize Op Names(name)")
put(name, "48", "decrement EAX (dec)");
put(name, "49", "decrement ECX (dec)");
put(name, "4a", "decrement EDX (dec)");
put(name, "4b", "decrement EBX (dec)");
put(name, "4c", "decrement ESP (dec)");
put(name, "4d", "decrement EBP (dec)");
put(name, "4e", "decrement ESI (dec)");
put(name, "4f", "decrement EDI (dec)");

:(scenario decrement_r32)
% Reg[ECX].u = 0x1f;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  49                                          # decrement ECX
+run: decrement ECX
+run: storing value 0x0000001e

:(before "End Single-Byte Opcodes")
case 0x48:
case 0x49:
case 0x4a:
case 0x4b:
case 0x4c:
case 0x4d:
case 0x4e:
case 0x4f: {  // decrement r32
  const uint8_t reg = op & 0x7;
  trace(90, "run") << "decrement " << rname(reg) << end();
  --Reg[reg].u;
  trace(90, "run") << "storing value 0x" << HEXWORD << Reg[reg].u << end();
  break;
}

:(scenario decrement_rm32)
% Reg[EAX].u = 0x20;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  c8                                      # decrement EAX
# ModR/M in binary: 11 (direct mode) 001 (subop inc) 000 (EAX)
+run: decrement r/m32
+run: r/m32 is EAX
+run: storing value 0x0000001f

:(before "End Op ff Subops")
case 1: {  // decrement r/m32
  trace(90, "run") << "decrement r/m32" << end();
  int32_t* arg = effective_address(modrm);
  --*arg;
  trace(90, "run") << "storing value 0x" << HEXWORD << *arg << end();
  break;
}

//:: push

:(before "End Initialize Op Names(name)")
put(name, "50", "push EAX to stack (push)");
put(name, "51", "push ECX to stack (push)");
put(name, "52", "push EDX to stack (push)");
put(name, "53", "push EBX to stack (push)");
put(name, "54", "push ESP to stack (push)");
put(name, "55", "push EBP to stack (push)");
put(name, "56", "push ESI to stack (push)");
put(name, "57", "push EDI to stack (push)");

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
//?   cerr << "push: " << NUM(reg) << ": " << Reg[reg].u << " => " << Reg[ESP].u << '\n';
  push(Reg[reg].u);
  break;
}

//:: pop

:(before "End Initialize Op Names(name)")
put(name, "58", "pop top of stack to EAX (pop)");
put(name, "59", "pop top of stack to ECX (pop)");
put(name, "5a", "pop top of stack to EDX (pop)");
put(name, "5b", "pop top of stack to EBX (pop)");
put(name, "5c", "pop top of stack to ESP (pop)");
put(name, "5d", "pop top of stack to EBP (pop)");
put(name, "5e", "pop top of stack to ESI (pop)");
put(name, "5f", "pop top of stack to EDI (pop)");

:(scenario pop_r32)
% Reg[ESP].u = 0x2000;
% Mem.push_back(vma(0x2000));  // manually allocate memory
% write_mem_i32(0x2000, 0x0000000a);  // ..before this write
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  5b                                          # pop stack to EBX
== 0x2000  # data segment
0a 00 00 00  # 0x0a
+run: pop into EBX
+run: popping value 0x0000000a
+run: incrementing ESP to 0x00002004

:(before "End Single-Byte Opcodes")
case 0x58:
case 0x59:
case 0x5a:
case 0x5b:
case 0x5c:
case 0x5d:
case 0x5e:
case 0x5f: {  // pop stack into r32
  const uint8_t reg = op & 0x7;
  trace(90, "run") << "pop into " << rname(reg) << end();
//?   cerr << "pop from " << Reg[ESP].u << '\n';
  Reg[reg].u = pop();
//?   cerr << "=> " << NUM(reg) << ": " << Reg[reg].u << '\n';
  break;
}
:(code)
uint32_t pop() {
  const uint32_t result = read_mem_u32(Reg[ESP].u);
  trace(90, "run") << "popping value 0x" << HEXWORD << result << end();
  Reg[ESP].u += 4;
  trace(90, "run") << "incrementing ESP to 0x" << HEXWORD << Reg[ESP].u << end();
  return result;
}
