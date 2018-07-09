:(before "End Single-Byte Opcodes")
case 0xcd: {  // int imm8 (software interrupt)
  uint8_t code = next();
  if (code != 0x80) {
    raise << "Unimplemented interrupt code " << HEXBYTE << code << '\n' << end();
    raise << "  Only `int 80h` supported for now.\n" << end();
    break;
  }
  process_int80();
  break;
}

:(code)
void process_int80() {
  switch (Reg[EAX].u) {
  case 1:
    exit(Reg[EBX].u);
    break;
  case 3:
    read(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    break;
  }
}
