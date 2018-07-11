//: instructions that (immediately) contain an argument to act with

:(scenario add_imm32_to_r32)
% Reg[EBX].i = 1;
# op  ModR/M  SIB   displacement  immediate
  81  c3                          0a 0b 0c 0d  # add 0x0d0c0b0a to EBX
# ModR/M in binary: 11 (direct mode) 000 (add imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: subop add
+run: storing 0x0d0c0b0b

:(before "End Single-Byte Opcodes")
case 0x81: {  // combine imm32 with r/m32
  uint8_t modrm = next();
  int32_t arg2 = imm32();
  trace(2, "run") << "combine imm32 0x" << HEXWORD << arg2 << " with r/m32" << end();
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
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  03                          0a 0b 0c 0d  # add 0x0d0c0b0a to *EBX
# ModR/M in binary: 00 (indirect mode) 000 (add imm32) 011 (dest EBX)
== 0x60  # data segment
01 00 00 00  # 1
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: subop add
+run: storing 0x0d0c0b0b

//:: subtract

:(scenario subtract_imm32_from_eax)
% Reg[EAX].i = 0x0d0c0baa;
# op  ModR/M  SIB   displacement  immediate
  2d                              0a 0b 0c 0d  # subtract 0x0d0c0b0a from EAX
+run: subtract imm32 0x0d0c0b0a from EAX
+run: storing 0x000000a0

:(before "End Single-Byte Opcodes")
case 0x2d: {  // subtract imm32 from EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "subtract imm32 0x" << HEXWORD << arg2 << " from EAX" << end();
  BINARY_ARITHMETIC_OP(-, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario subtract_imm32_from_mem_at_r32)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  2b                          01 00 00 00  # subtract 1 from *EBX
# ModR/M in binary: 00 (indirect mode) 101 (subtract imm32) 011 (dest EBX)
== 0x60  # data segment
0a 00 00 00  # 10
+run: combine imm32 0x00000001 with r/m32
+run: effective address is 0x60 (EBX)
+run: subop subtract
+run: storing 0x00000009

:(before "End Op 81 Subops")
case 5: {
  trace(2, "run") << "subop subtract" << end();
  BINARY_ARITHMETIC_OP(-, *arg1, arg2);
  break;
}

//:

:(scenario subtract_imm32_from_r32)
% Reg[EBX].i = 10;
# op  ModR/M  SIB   displacement  immediate
  81  eb                          01 00 00 00  # subtract 1 from EBX
# ModR/M in binary: 11 (direct mode) 101 (subtract imm32) 011 (dest EBX)
+run: combine imm32 0x00000001 with r/m32
+run: r/m32 is EBX
+run: subop subtract
+run: storing 0x00000009

//:: and

:(scenario and_imm32_with_eax)
% Reg[EAX].i = 0xff;
# op  ModR/M  SIB   displacement  immediate
  25                              0a 0b 0c 0d  # and 0x0d0c0b0a with EAX
+run: and imm32 0x0d0c0b0a with EAX
+run: storing 0x0000000a

:(before "End Single-Byte Opcodes")
case 0x25: {  // and imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "and imm32 0x" << HEXWORD << arg2 << " with EAX" << end();
  BINARY_BITWISE_OP(&, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario and_imm32_with_mem_at_r32)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  23                          0a 0b 0c 0d  # and 0x0d0c0b0a with *EBX
# ModR/M in binary: 00 (indirect mode) 100 (and imm32) 011 (dest EBX)
== 0x60  # data segment
ff 00 00 00  # 0xff
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: subop and
+run: storing 0x0000000a

:(before "End Op 81 Subops")
case 4: {
  trace(2, "run") << "subop and" << end();
  BINARY_BITWISE_OP(&, *arg1, arg2);
  break;
}

//:

:(scenario and_imm32_with_r32)
% Reg[EBX].i = 0xff;
# op  ModR/M  SIB   displacement  immediate
  81  e3                          0a 0b 0c 0d  # and 0x0d0c0b0a with EBX
# ModR/M in binary: 11 (direct mode) 100 (and imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: subop and
+run: storing 0x0000000a

//:: or

:(scenario or_imm32_with_eax)
% Reg[EAX].i = 0xd0c0b0a0;
# op  ModR/M  SIB   displacement  immediate
  0d                              0a 0b 0c 0d  # or 0x0d0c0b0a with EAX
+run: or imm32 0x0d0c0b0a with EAX
+run: storing 0xddccbbaa

:(before "End Single-Byte Opcodes")
case 0x0d: {  // or imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "or imm32 0x" << HEXWORD << arg2 << " with EAX" << end();
  BINARY_BITWISE_OP(|, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario or_imm32_with_mem_at_r32)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  0b                          0a 0b 0c 0d  # or 0x0d0c0b0a with *EBX
# ModR/M in binary: 00 (indirect mode) 001 (or imm32) 011 (dest EBX)
== 0x60  # data segment
a0 b0 c0 d0  # 0xd0c0b0a0
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: subop or
+run: storing 0xddccbbaa

:(before "End Op 81 Subops")
case 1: {
  trace(2, "run") << "subop or" << end();
  BINARY_BITWISE_OP(|, *arg1, arg2);
  break;
}

:(scenario or_imm32_with_r32)
% Reg[EBX].i = 0xd0c0b0a0;
# op  ModR/M  SIB   displacement  immediate
  81  cb                          0a 0b 0c 0d  # or 0x0d0c0b0a with EBX
# ModR/M in binary: 11 (direct mode) 001 (or imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: subop or
+run: storing 0xddccbbaa

//:: xor

:(scenario xor_imm32_with_eax)
% Reg[EAX].i = 0xddccb0a0;
# op  ModR/M  SIB   displacement  immediate
  35                              0a 0b 0c 0d  # xor 0x0d0c0b0a with EAX
+run: xor imm32 0x0d0c0b0a with EAX
+run: storing 0xd0c0bbaa

:(before "End Single-Byte Opcodes")
case 0x35: {  // xor imm32 with EAX
  int32_t arg2 = imm32();
  trace(2, "run") << "xor imm32 0x" << HEXWORD << arg2 << " with EAX" << end();
  BINARY_BITWISE_OP(^, Reg[EAX].i, arg2);
  break;
}

//:

:(scenario xor_imm32_with_mem_at_r32)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  33                          0a 0b 0c 0d  # xor 0x0d0c0b0a with *EBX
# ModR/M in binary: 00 (indirect mode) 110 (xor imm32) 011 (dest EBX)
== 0x60  # data segment
a0 b0 c0 d0  # 0xd0c0b0a0
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: subop xor
+run: storing 0xddccbbaa

:(before "End Op 81 Subops")
case 6: {
  trace(2, "run") << "subop xor" << end();
  BINARY_BITWISE_OP(^, *arg1, arg2);
  break;
}

:(scenario xor_imm32_with_r32)
% Reg[EBX].i = 0xd0c0b0a0;
# op  ModR/M  SIB   displacement  immediate
  81  f3                          0a 0b 0c 0d  # xor 0x0d0c0b0a with EBX
# ModR/M in binary: 11 (direct mode) 110 (xor imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: subop xor
+run: storing 0xddccbbaa

//:: compare (cmp)

:(scenario compare_imm32_with_eax_greater)
% Reg[EAX].i = 0x0d0c0b0a;
# op  ModR/M  SIB   displacement  immediate
  3d                              07 0b 0c 0d  # compare 0x0d0c0b07 with EAX
+run: compare EAX and imm32 0x0d0c0b07
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3d: {  // subtract imm32 from EAX
  int32_t arg1 = Reg[EAX].i;
  int32_t arg2 = imm32();
  trace(2, "run") << "compare EAX and imm32 0x" << HEXWORD << arg2 << end();
  int32_t tmp1 = arg1 - arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = arg1 - arg2;
  OF = (tmp1 != tmp2);
  trace(2, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_imm32_with_eax_lesser)
% Reg[EAX].i = 0x0d0c0b07;
# op  ModR/M  SIB   displacement  immediate
  3d                              0a 0b 0c 0d  # compare 0x0d0c0b0a with EAX
+run: compare EAX and imm32 0x0d0c0b0a
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_eax_equal)
% Reg[EAX].i = 0x0d0c0b0a;
# op  ModR/M  SIB   displacement  immediate
  3d                              0a 0b 0c 0d  # compare 0x0d0c0b0a with EAX
+run: compare EAX and imm32 0x0d0c0b0a
+run: SF=0; ZF=1; OF=0

//:

:(scenario compare_imm32_with_r32_greater)
% Reg[EBX].i = 0x0d0c0b0a;
# op  ModR/M  SIB   displacement  immediate
  81  fb                          07 0b 0c 0d  # compare 0x0d0c0b07 with EBX
# ModR/M in binary: 11 (direct mode) 111 (compare imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b07 with r/m32
+run: r/m32 is EBX
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
% Reg[EBX].i = 0x0d0c0b07;
# op  ModR/M  SIB   displacement  immediate
  81  fb                          0a 0b 0c 0d  # compare 0x0d0c0b0a with EBX
# ModR/M in binary: 11 (direct mode) 111 (compare imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_r32_equal)
% Reg[EBX].i = 0x0d0c0b0a;
# op  ModR/M  SIB   displacement  immediate
  81  fb                          0a 0b 0c 0d  # compare 0x0d0c0b0a with EBX
# ModR/M in binary: 11 (direct mode) 111 (compare imm32) 011 (dest EBX)
+run: combine imm32 0x0d0c0b0a with r/m32
+run: r/m32 is EBX
+run: SF=0; ZF=1; OF=0

:(scenario compare_imm32_with_mem_at_r32_greater)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  3b                          07 0b 0c 0d  # compare 0x0d0c0b07 with *EBX
# ModR/M in binary: 00 (indirect mode) 111 (compare imm32) 011 (dest EBX)
== 0x60  # data segment
0a 0b 0c 0d  # 0x0d0c0b0a
+run: combine imm32 0x0d0c0b07 with r/m32
+run: effective address is 0x60 (EBX)
+run: SF=0; ZF=0; OF=0

:(scenario compare_imm32_with_mem_at_r32_lesser)
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  3b                          0a 0b 0c 0d  # compare 0x0d0c0b0a with *EBX
# ModR/M in binary: 00 (indirect mode) 111 (compare imm32) 011 (dest EBX)
== 0x60  # data segment
07 0b 0c 0d  # 0x0d0c0b07
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_imm32_with_mem_at_r32_equal)
% Reg[EBX].i = 0x0d0c0b0a;
% Reg[EBX].i = 0x60;
== 0x01  # code segment
# op  ModR/M  SIB   displacement  immediate
  81  3b                          0a 0b 0c 0d  # compare 0x0d0c0b0a with *EBX
# ModR/M in binary: 00 (indirect mode) 111 (compare imm32) 011 (dest EBX)
== 0x60  # data segment
0a 0b 0c 0d  # 0x0d0c0b0a
+run: combine imm32 0x0d0c0b0a with r/m32
+run: effective address is 0x60 (EBX)
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_imm32_to_r32)
# op  ModR/M  SIB   displacement  immediate
  bb                              0a 0b 0c 0d  # copy 0x0d0c0b0a to EBX
+run: copy imm32 0x0d0c0b0a to EBX

:(before "End Single-Byte Opcodes")
case 0xb8:
case 0xb9:
case 0xba:
case 0xbb:
case 0xbc:
case 0xbd:
case 0xbe:
case 0xbf: {  // copy imm32 to r32
  uint8_t reg1 = op & 0x7;
  int32_t arg2 = imm32();
  trace(2, "run") << "copy imm32 0x" << HEXWORD << arg2 << " to " << rname(reg1) << end();
  Reg[reg1].i = arg2;
  break;
}

//:

:(scenario copy_imm32_to_mem_at_r32)
% Reg[EBX].i = 0x60;
# op  ModR/M  SIB   displacement  immediate
  c7  03                          0a 0b 0c 0d  # copy 0x0d0c0b0a to *EBX
# ModR/M in binary: 00 (indirect mode) 000 (unused) 011 (dest EBX)
+run: copy imm32 0x0d0c0b0a to r/m32
+run: effective address is 0x60 (EBX)

:(before "End Single-Byte Opcodes")
case 0xc7: {  // copy imm32 to r32
  uint8_t modrm = next();
  int32_t arg2 = imm32();
  trace(2, "run") << "copy imm32 0x" << HEXWORD << arg2 << " to r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  *arg1 = arg2;
  break;
}

//:: push

:(scenario push_imm32)
% Reg[ESP].u = 0x14;
# op  ModR/M  SIB   displacement  immediate
  68                              af 00 00 00  # push *EAX to stack
+run: push imm32 0x000000af
+run: ESP is now 0x00000010
+run: contents at ESP: 0x000000af

:(before "End Single-Byte Opcodes")
case 0x68: {
  int32_t val = imm32();
  trace(2, "run") << "push imm32 0x" << HEXWORD << val << end();
  Reg[ESP].u -= 4;
  write_mem_i32(Reg[ESP].u, val);
  trace(2, "run") << "ESP is now 0x" << HEXWORD << Reg[ESP].u << end();
  trace(2, "run") << "contents at ESP: 0x" << HEXWORD << read_mem_u32(Reg[ESP].u) << end();
  break;
}
