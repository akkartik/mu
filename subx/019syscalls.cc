:(before "End Initialize Op Names(name)")
put(name, 0xcd, "software interrupt");

:(before "End Single-Byte Opcodes")
case 0xcd: {  // int imm8 (software interrupt)
  trace(2, "run") << "syscall" << end();
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
    exit(/*exit code*/Reg[EBX].u);
    break;
  case 3:
    Reg[EAX].i = read(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    break;
  case 4:
    Reg[EAX].i = write(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    break;
  }
}

:(before "End Includes")
#include <unistd.h>
