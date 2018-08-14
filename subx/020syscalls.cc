:(before "End Initialize Op Names(name)")
put(name, "cd", "software interrupt");

:(before "End Single-Byte Opcodes")
case 0xcd: {  // int imm8 (software interrupt)
  trace(90, "run") << "syscall" << end();
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
    trace(91, "run") << "read: " << Reg[EBX].u << ' ' << Reg[ECX].u << '/' << mem_addr_string(Reg[ECX].u) << ' ' << Reg[EDX].u << end();
    Reg[EAX].i = read(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 4:
    trace(91, "run") << "write: " << Reg[EBX].u << ' ' << Reg[ECX].u << '/' << mem_addr_string(Reg[ECX].u) << ' ' << Reg[EDX].u << end();
    Reg[EAX].i = write(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 5: {
    check_flags(ECX);
    check_mode(EDX);
    trace(91, "run") << "open: " << Reg[EBX].u << '/' << mem_addr_string(Reg[EBX].u) << ' ' << Reg[ECX].u << end();
    Reg[EAX].i = open(/*filename*/mem_addr_string(Reg[EBX].u), /*flags*/Reg[ECX].u, /*mode*/0640);
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  }
  case 6:
    trace(91, "run") << "close: " << Reg[EBX].u << end();
    Reg[EAX].i = close(/*file descriptor*/Reg[EBX].u);
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 8:
    check_mode(ECX);
    trace(91, "run") << "creat: " << Reg[EBX].u << '/' << mem_addr_string(Reg[EBX].u) << end();
    Reg[EAX].i = creat(/*filename*/mem_addr_string(Reg[EBX].u), /*mode*/0640);
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 10:
    trace(91, "run") << "unlink: " << Reg[EBX].u << '/' << mem_addr_string(Reg[EBX].u) << end();
    Reg[EAX].i = unlink(/*filename*/mem_addr_string(Reg[EBX].u));
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 38:
    trace(91, "run") << "rename: " << Reg[EBX].u << '/' << mem_addr_string(Reg[EBX].u) << " -> " << Reg[ECX].u << '/' << mem_addr_string(Reg[ECX].u) << end();
    Reg[EAX].i = rename(/*old filename*/mem_addr_string(Reg[EBX].u), /*new filename*/mem_addr_string(Reg[ECX].u));
    trace(91, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << strerror(errno) << '\n' << end();
    break;
  case 45:  // brk: modify size of data segment
    trace(91, "run") << "grow data segment to " << Reg[EBX].u << end();
    resize_mem(/*new end address*/Reg[EBX].u);
    break;
  default:
    raise << HEXWORD << EIP << ": unimplemented syscall " << Reg[EAX].u << '\n' << end();
  }
}

// SubX is oblivious to file permissions, directories, symbolic links, terminals, and much else besides.
// Also ignoring any concurrency considerations for now.
void check_flags(int reg) {
  uint32_t flags = Reg[reg].u;
  if (flags != ((flags & O_RDONLY) | (flags & O_WRONLY))) {
    raise << HEXWORD << EIP << ": most POSIX flags to the open() syscall are not supported. Just O_RDONLY and O_WRONLY for now. Zero concurrent access support.\n" << end();
    exit(1);
  }
  if ((flags & O_RDONLY) && (flags & O_WRONLY)) {
    raise << HEXWORD << EIP << ": can't open a file for both reading and writing at once. See http://man7.org/linux/man-pages/man2/open.2.html.\n" << end();
    exit(1);
  }
}

void check_mode(int reg) {
  if (Reg[reg].u != 0600) {
    raise << HEXWORD << EIP << ": SubX is oblivious to file permissions; register " << reg << " must be 0.\n" << end();
    exit(1);
  }
}

void resize_mem(uint32_t new_end_address) {
  if (new_end_address < Mem_offset) {
    raise << HEXWORD << EIP << ": can't shrink data segment to before code segment\n";
    return;
  }
  int32_t new_size = new_end_address - Mem_offset;
  if (new_size < SIZE(Mem)) {
    raise << HEXWORD << EIP << ": shrinking data segment is not supported.\n" << end();
    return;
  }
  Mem.resize(new_size);  // will throw exception on failure
}
