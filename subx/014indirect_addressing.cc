//: operating on memory at the address provided by some register
//: we'll now start providing data in a separate segment

:(scenario add_r32_to_mem_at_r32)
% Reg[EBX].i = 0x10;
% Reg[EAX].i = 0x60;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 0:  // indirect addressing
  switch (rm) {
  default:  // address in register
    trace(90, "run") << "effective address is 0x" << std::hex << Reg[rm].u << " (" << rname(rm) << ")" << end();
    addr = Reg[rm].u;
    break;
  // End Mod 0 Special-cases(addr)
  }
  break;

//:

:(before "End Initialize Op Names(name)")
put(name, "03", "add rm32 to r32");

:(scenario add_mem_at_r32_to_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x10;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  03  18                                      # add *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add r/m32 to EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "add r/m32 to " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, Reg[arg1].i, *arg2);
  break;
}

//:: subtract

:(scenario subtract_r32_from_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 1;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  29  18                                      # subtract EBX from *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0a 00 00 00  # 10
+run: subtract EBX from r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x00000009

//:

:(before "End Initialize Op Names(name)")
put(name, "2b", "subtract rm32 from r32");

:(scenario subtract_mem_at_r32_from_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 10;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  2b  18                                      # subtract *EAX from EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: subtract r/m32 from EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "subtract r/m32 from " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, Reg[arg1].i, *arg2);
  break;
}

//:: and

:(scenario and_r32_with_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0xff;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  21  18                                      # and EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: and EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x0000000d

//:

:(before "End Initialize Op Names(name)")
put(name, "23", "r32 = bitwise AND of r32 with rm32");

:(scenario and_mem_at_r32_with_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  23  18                                      # and *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
ff 00 00 00  # 0xff
+run: and r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x23: {  // and r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "and r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(&, Reg[arg1].u, *arg2);
  break;
}

//:: or

:(scenario or_r32_with_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  09  18                                      # or EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: or EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

//:

:(before "End Initialize Op Names(name)")
put(name, "0b", "r32 = bitwise OR of r32 with rm32");

:(scenario or_mem_at_r32_with_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  0b  18                                      # or *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: or r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x0b: {  // or r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "or r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: xor

:(scenario xor_r32_with_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  31  18                                      # xor EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c bb aa  # 0xaabb0c0d
+run: xor EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x0a0bccdd

//:

:(before "End Initialize Op Names(name)")
put(name, "33", "r32 = bitwise XOR of r32 with rm32");

:(scenario xor_mem_at_r32_with_r32)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  33  18                                      # xor *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: xor r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x33: {  // xor r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "xor r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: not

:(scenario not_of_mem_at_r32)
% Reg[EBX].i = 0x60;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  f7  13                                      # negate *EBX
# ModR/M in binary: 00 (indirect mode) 010 (subop not) 011 (dest EBX)
== 0x60  # data segment
ff 00 0f 0f  # 0x0f0f00ff
+run: operate on r/m32
+run: effective address is 0x60 (EBX)
+run: subop: not
+run: storing 0xf0f0ff00

//:: compare (cmp)

:(scenario compare_mem_at_r32_with_r32_greater)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c07;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_lesser)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
07 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_equal)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=1; OF=0

//:

:(before "End Initialize Op Names(name)")
put(name, "3b", "set SF if rm32 > r32");

:(scenario compare_r32_with_mem_at_r32_greater)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
07 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3b: {  // set SF if r32 < r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(90, "run") << "compare r/m32 with " << rname(reg1) << end();
  int32_t arg1 = Reg[reg1].i;
  int32_t* arg2 = effective_address(modrm);
  int32_t tmp1 = arg1 - *arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = arg1 - *arg2;
  OF = (tmp1 != tmp2);
  trace(90, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_r32_with_mem_at_r32_lesser)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c07;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_mem_at_r32_equal)
% Reg[EAX].i = 0x60;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x60  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_r32_to_mem_at_r32)
% Reg[EBX].i = 0xaf;
% Reg[EAX].i = 0x60;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  89  18                                      # copy EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: copy EBX to r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x000000af

//:

:(before "End Initialize Op Names(name)")
put(name, "8b", "copy rm32 to r32");

:(scenario copy_mem_at_r32_to_r32)
% Reg[EAX].i = 0x60;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  8b  18                                      # copy *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
== 0x60  # data segment
af 00 00 00  # 0xaf
+run: copy r/m32 to EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x8b: {  // copy r32 to r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(90, "run") << "copy r/m32 to " << rname(reg1) << end();
  int32_t* arg2 = effective_address(modrm);
  Reg[reg1].i = *arg2;
  trace(90, "run") << "storing 0x" << HEXWORD << *arg2 << end();
  break;
}

//:

:(before "End Initialize Op Names(name)")
put(name, "88", "copy r8 (lowermost byte of r32) to r8/m8-at-r32");

:(scenario copy_r8_to_mem_at_r32)
% Reg[EBX].i = 0xafafafaf;
% Reg[EAX].i = 0x60;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  88  18                                      # copy just the lowermost byte of EBX to the byte at *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
+run: copy lowermost byte of EBX to r8/m8-at-r32
+run: effective address is 0x60 (EAX)
+run: storing 0xaf
% CHECK_EQ(0x000000af, read_mem_u32(0x60));

:(before "End Single-Byte Opcodes")
case 0x88: {  // copy r/m8 to r8
  uint8_t modrm = next();
  uint8_t reg2 = (modrm>>3)&0x7;
  trace(90, "run") << "copy lowermost byte of " << rname(reg2) << " to r8/m8-at-r32" << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* arg1 = reinterpret_cast<uint8_t*>(effective_address(modrm));
  *arg1 = Reg[reg2].u;
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*arg1) << end();
  break;
}

//:

:(before "End Initialize Op Names(name)")
put(name, "8a", "copy r8/m8-at-r32 to r8 (lowermost byte of r32)");

:(scenario copy_mem_at_r32_to_r8)
% Reg[EBX].i = 0xaf;
% Reg[EAX].i = 0x60;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  8a  18                                      # copy just the byte at *EAX to lowermost byte of EBX (clearing remaining bytes)
# ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
== 0x60  # data segment
af ff ff ff  # 0xaf with more data in following bytes
+run: copy r8/m8-at-r32 to lowermost byte of EBX
+run: effective address is 0x60 (EAX)
+run: storing 0xaf

:(before "End Single-Byte Opcodes")
case 0x8a: {  // copy r/m8 to r8
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(90, "run") << "copy r8/m8-at-r32 to lowermost byte of " << rname(reg1) << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* arg2 = reinterpret_cast<uint8_t*>(effective_address(modrm));
  Reg[reg1].u = static_cast<uint32_t>(*arg2);
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*arg2) << end();
  break;
}

//:: jump

:(before "End Initialize Op Names(name)")
put(name, "ff", "jump/push/call rm32 based on subop");

:(scenario jump_mem_at_r32)
% Reg[EAX].i = 0x60;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  20                                      # jump to *EAX
# ModR/M in binary: 00 (indirect mode) 100 (jump to r/m32) 000 (src EAX)
  05                              00 00 00 01
  05                              00 00 00 02
== 0x60  # data segment
08 00 00 00  # 8
+run: inst: 0x00000001
+run: jump to r/m32
+run: effective address is 0x60 (EAX)
+run: jumping to 0x00000008
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Single-Byte Opcodes")
case 0xff: {
  uint8_t modrm = next();
  uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
    case 4: {  // jump to r/m32
      trace(90, "run") << "jump to r/m32" << end();
      int32_t* arg2 = effective_address(modrm);
      EIP = *arg2;
      trace(90, "run") << "jumping to 0x" << HEXWORD << EIP << end();
      break;
    }
    // End Op ff Subops
  }
  break;
}

//:: push

:(scenario push_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[ESP].u = 0x14;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  30                                      # push *EAX to stack
# ModR/M in binary: 00 (indirect mode) 110 (push r/m32) 000 (src EAX)
== 0x60  # data segment
af 00 00 00  # 0xaf
+run: push r/m32
+run: effective address is 0x60 (EAX)
+run: decrementing ESP to 0x00000010
+run: pushing value 0x000000af

:(before "End Op ff Subops")
case 6: {  // push r/m32 to stack
  trace(90, "run") << "push r/m32" << end();
  const int32_t* val = effective_address(modrm);
  push(*val);
  break;
}

//:: pop

:(before "End Initialize Op Names(name)")
put(name, "8f", "pop top of stack to rm32");

:(scenario pop_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[ESP].u = 0x10;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  8f  00                                      # pop stack into *EAX
# ModR/M in binary: 00 (indirect mode) 000 (pop r/m32) 000 (dest EAX)
== 0x10  # data segment
30 00 00 00  # 0x30
+run: pop into r/m32
+run: effective address is 0x60 (EAX)
+run: popping value 0x00000030
+run: incrementing ESP to 0x00000014

:(before "End Single-Byte Opcodes")
case 0x8f: {  // pop stack into r/m32
  uint8_t modrm = next();
  uint8_t subop = (modrm>>3)&0x7;
  switch (subop) {
    case 0: {
      trace(90, "run") << "pop into r/m32" << end();
      int32_t* dest = effective_address(modrm);
      *dest = pop();
      break;
    }
  }
  break;
}

//:: special-case for loading address from disp32 rather than register

:(scenario add_r32_to_mem_at_displacement)
% Reg[EBX].i = 0x10;  // source
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  1d            60 00 00 00              # add EBX to *0x60
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 101 (dest in disp32)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is 0x60 (disp32)
+run: storing 0x00000011

:(before "End Mod 0 Special-cases(addr)")
case 5:  // exception: mod 0b00 rm 0b101 => incoming disp32
  addr = imm32();
  trace(90, "run") << "effective address is 0x" << std::hex << addr << " (disp32)" << end();
  break;

//:

:(scenario add_r32_to_mem_at_r32_plus_disp8)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x5e;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  58            02                       # add EBX to *(EAX+2)
# ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x5e (EAX)
+run: effective address is 0x60 (after adding disp8)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 1:  // indirect + disp8 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(90, "run") << "effective address is initially 0x" << std::hex << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 1 Special-cases(addr)
  }
  if (addr > 0) {
    addr += static_cast<int8_t>(next());
    trace(90, "run") << "effective address is 0x" << std::hex << addr << " (after adding disp8)" << end();
  }
  break;

:(scenario add_r32_to_mem_at_r32_plus_negative_disp8)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x61;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  58            ff                       # add EBX to *(EAX-1)
# ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x61 (EAX)
+run: effective address is 0x60 (after adding disp8)
+run: storing 0x00000011

//:

:(scenario add_r32_to_mem_at_r32_plus_disp32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x5e;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  98            02 00 00 00              # add EBX to *(EAX+2)
# ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x5e (EAX)
+run: effective address is 0x60 (after adding disp32)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 2:  // indirect + disp32 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(90, "run") << "effective address is initially 0x" << std::hex << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 2 Special-cases(addr)
  }
  if (addr > 0) {
    addr += imm32();
    trace(90, "run") << "effective address is 0x" << std::hex << addr << " (after adding disp32)" << end();
  }
  break;

:(scenario add_r32_to_mem_at_r32_plus_negative_disp32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x61;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  98            ff ff ff ff              # add EBX to *(EAX-1)
# ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
== 0x60  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x61 (EAX)
+run: effective address is 0x60 (after adding disp32)
+run: storing 0x00000011
