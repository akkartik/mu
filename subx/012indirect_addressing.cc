//: operating on memory at the address provided by some register

:(scenario add_r32_to_mem_at_r32)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: add EBX to r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x00000011

:(before "End Mod Special-cases")
case 0:
  switch (rm) {
  default:  // mod 0 is usually indirect addressing
    trace(2, "run") << "effective address is 0x" << std::hex << Reg[rm].u << " (" << rname(rm) << ")" << end();
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
  03  18                                      # add *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: add r/m32 to EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "add r/m32 to " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, Reg[arg1].i, *arg2);
  break;
}

//:: subtract

:(scenario subtract_r32_from_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 10);
% Reg[3].i = 1;
# op  ModR/M  SIB   displacement  immediate
  29  18                                      # subtract EBX from *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: subtract EBX from r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x00000009

//:

:(scenario subtract_mem_at_r32_from_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
% Reg[3].i = 10;
# op  ModR/M  SIB   displacement  immediate
  2b  18                                      # subtract *EAX from EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: subtract r/m32 from EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "subtract r/m32 from " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, Reg[arg1].i, *arg2);
  break;
}

//:: and

:(scenario and_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xff;
# op  ModR/M  SIB   displacement  immediate
  21  18                                      # and EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: and EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x0000000d

//:

:(scenario and_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000ff);
% Reg[3].i = 0x0a0b0c0d;
# op  ModR/M  SIB   displacement  immediate
  23  18                                      # and *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: and r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x23: {  // and r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "and r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(&, Reg[arg1].u, *arg2);
  break;
}

//:: or

:(scenario or_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModR/M  SIB   displacement  immediate
  09  18                                      # or EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: or EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

//:

:(scenario or_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModR/M  SIB   displacement  immediate
  0b  18                                      # or *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: or r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x0b: {  // or r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "or r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: xor

:(scenario xor_r32_with_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0xaabb0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModR/M  SIB   displacement  immediate
  31  18                                      # xor EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: xor EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x0a0bccdd

//:

:(scenario xor_mem_at_r32_with_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0xa0b0c0d0;
# op  ModR/M  SIB   displacement  immediate
  33  18                                      # xor *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: xor r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x33: {  // xor r/m32 with r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "xor r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: not

:(scenario not_r32_with_mem_at_r32)
% Reg[3].i = 0x60;
# word at 0x60 is 0x0f0f00ff
% SET_WORD_IN_MEM(0x60, 0x0f0f00ff);
# op  ModR/M  SIB   displacement  immediate
  f7  03                                      # negate *EBX
# ModR/M in binary: 00 (indirect mode) 000 (unused) 011 (dest EBX)
+run: 'not' of r/m32
+run: effective address is 0x60 (EBX)
+run: storing 0xf0f0ff00

//:: compare (cmp)

:(scenario compare_mem_at_r32_with_r32_greater)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c07;
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_lesser)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c07);
% Reg[3].i = 0x0a0b0c0d;
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_equal)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c0d;
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare EBX with r/m32
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=1; OF=0

//:

:(scenario compare_r32_with_mem_at_r32_greater)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c07);
% Reg[3].i = 0x0a0b0c0d;
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3b: {  // set SF if r32 < r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(2, "run") << "compare r/m32 with " << rname(reg1) << end();
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
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_mem_at_r32_equal)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x0a0b0c0d);
% Reg[3].i = 0x0a0b0c0d;
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: compare r/m32 with EBX
+run: effective address is 0x60 (EAX)
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_r32_to_mem_at_r32)
% Reg[3].i = 0xaf;
% Reg[0].i = 0x60;
# op  ModR/M  SIB   displacement  immediate
  89  18                                      # copy EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: copy EBX to r/m32
+run: effective address is 0x60 (EAX)
+run: storing 0x000000af

//:

:(scenario copy_mem_at_r32_to_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 0x000000af);
# op  ModR/M  SIB   displacement  immediate
  8b  18                                      # copy *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: copy r/m32 to EBX
+run: effective address is 0x60 (EAX)
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x8b: {  // copy r32 to r/m32
  uint8_t modrm = next();
  uint8_t reg1 = (modrm>>3)&0x7;
  trace(2, "run") << "copy r/m32 to " << rname(reg1) << end();
  int32_t* arg2 = effective_address(modrm);
  Reg[reg1].i = *arg2;
  trace(2, "run") << "storing 0x" << HEXWORD << *arg2 << end();
  break;
}

//:: jump

:(scenario jump_mem_at_r32)
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 8);
# op  ModR/M  SIB   displacement  immediate
  ff  20                                      # jump to *EAX
# ModR/M in binary: 00 (indirect mode) 100 (jump to r/m32) 000 (src EAX)
  05                              00 00 00 01
  05                              00 00 00 02
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
      trace(2, "run") << "jump to r/m32" << end();
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
# op  ModR/M  SIB   displacement  immediate
  ff  30                                      # push *EAX to stack
# ModR/M in binary: 00 (indirect mode) 110 (push r/m32) 000 (src EAX)
+run: push r/m32
+run: effective address is 0x60 (EAX)
+run: decrementing ESP to 0x00000010
+run: pushing value 0x000000af

:(before "End Op ff Subops")
case 6: {  // push r/m32 to stack
  trace(2, "run") << "push r/m32" << end();
  const int32_t* val = effective_address(modrm);
  push(*val);
  break;
}

//:: pop

:(scenario pop_mem_at_r32)
% Reg[0].i = 0x60;
% Reg[ESP].u = 0x10;
% SET_WORD_IN_MEM(0x10, 0x00000030);
# op  ModR/M  SIB   displacement  immediate
  8f  00                                      # pop stack into *EAX
# ModR/M in binary: 00 (indirect mode) 000 (pop r/m32) 000 (dest EAX)
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
      trace(2, "run") << "pop into r/m32" << end();
      int32_t* dest = effective_address(modrm);
      *dest = pop();
      break;
    }
  }
  break;
}

//:: special-case for loading address from disp32 rather than register

:(scenario add_r32_to_mem_at_displacement)
% Reg[3].i = 0x10;  // source
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  1d            60 00 00 00              # add EBX to *0x60
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 101 (dest in disp32)
+run: add EBX to r/m32
+run: effective address is 0x60 (disp32)
+run: storing 0x00000011

:(before "End Mod 0 Special-cases")
case 5: {  // exception: mod 0b00 rm 0b101 => incoming disp32
  uint32_t addr = imm32();
  result = reinterpret_cast<int32_t*>(&Mem.at(addr));
  trace(2, "run") << "effective address is 0x" << std::hex << addr << " (disp32)" << end();
  break;
}
