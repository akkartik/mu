:(before "End Initialize Op Names")
put_new(Name, "cd", "software interrupt (int)");

:(before "End Single-Byte Opcodes")
case 0xcd: {  // int imm8 (software interrupt)
  trace(Callstack_depth+1, "run") << "syscall" << end();
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
    trace(Callstack_depth+1, "run") << "read: " << Reg[EBX].u << ' ' << Reg[ECX].u << ' ' << Reg[EDX].u << end();
    Reg[EAX].i = read(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "read: " << strerror(errno) << '\n' << end();
    break;
  case 4:
    trace(Callstack_depth+1, "run") << "write: " << Reg[EBX].u << ' ' << Reg[ECX].u << ' ' << Reg[EDX].u << end();
    trace(Callstack_depth+1, "run") << Reg[ECX].u << " => " << mem_addr_string(Reg[ECX].u, Reg[EDX].u) << end();
    Reg[EAX].i = write(/*file descriptor*/Reg[EBX].u, /*memory buffer*/mem_addr_u8(Reg[ECX].u), /*size*/Reg[EDX].u);
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "write: " << strerror(errno) << '\n' << end();
    break;
  case 5: {
    check_flags(ECX);
    check_mode(EDX);
    trace(Callstack_depth+1, "run") << "open: " << Reg[EBX].u << ' ' << Reg[ECX].u << end();
    trace(Callstack_depth+1, "run") << Reg[EBX].u << " => " << mem_addr_kernel_string(Reg[EBX].u) << end();
    Reg[EAX].i = open(/*filename*/mem_addr_kernel_string(Reg[EBX].u), /*flags*/Reg[ECX].u, /*mode*/0640);
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "open: " << strerror(errno) << '\n' << end();
    break;
  }
  case 6:
    trace(Callstack_depth+1, "run") << "close: " << Reg[EBX].u << end();
    Reg[EAX].i = close(/*file descriptor*/Reg[EBX].u);
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "close: " << strerror(errno) << '\n' << end();
    break;
  case 8:
    check_mode(ECX);
    trace(Callstack_depth+1, "run") << "creat: " << Reg[EBX].u << end();
    trace(Callstack_depth+1, "run") << Reg[EBX].u << " => " << mem_addr_kernel_string(Reg[EBX].u) << end();
    Reg[EAX].i = creat(/*filename*/mem_addr_kernel_string(Reg[EBX].u), /*mode*/0640);
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "creat: " << strerror(errno) << '\n' << end();
    break;
  case 10:
    trace(Callstack_depth+1, "run") << "unlink: " << Reg[EBX].u << end();
    trace(Callstack_depth+1, "run") << Reg[EBX].u << " => " << mem_addr_kernel_string(Reg[EBX].u) << end();
    Reg[EAX].i = unlink(/*filename*/mem_addr_kernel_string(Reg[EBX].u));
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "unlink: " << strerror(errno) << '\n' << end();
    break;
  case 38:
    trace(Callstack_depth+1, "run") << "rename: " << Reg[EBX].u << " -> " << Reg[ECX].u << end();
    trace(Callstack_depth+1, "run") << Reg[EBX].u << " => " << mem_addr_kernel_string(Reg[EBX].u) << end();
    trace(Callstack_depth+1, "run") << Reg[ECX].u << " => " << mem_addr_kernel_string(Reg[ECX].u) << end();
    Reg[EAX].i = rename(/*old filename*/mem_addr_kernel_string(Reg[EBX].u), /*new filename*/mem_addr_kernel_string(Reg[ECX].u));
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].i << end();
    if (Reg[EAX].i == -1) raise << "rename: " << strerror(errno) << '\n' << end();
    break;
  case 90:  // mmap: allocate memory outside existing segment allocations
    trace(Callstack_depth+1, "run") << "mmap: allocate new segment" << end();
    // Ignore most arguments for now: address hint, protection flags, sharing flags, fd, offset.
    // We only support anonymous maps.
    Reg[EAX].u = new_segment(/*length*/read_mem_u32(Reg[EBX].u+0x4));
    trace(Callstack_depth+1, "run") << "result: " << Reg[EAX].u << end();
    break;
  case 0xa2:  // nanosleep
    cerr << "not sleeping\n";
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
    cerr << HEXWORD << EIP << ": most POSIX flags to the open() syscall are not supported. Just O_RDONLY and O_WRONLY for now. Zero concurrent access support.\n";
    exit(1);
  }
  if ((flags & O_RDONLY) && (flags & O_WRONLY)) {
    cerr << HEXWORD << EIP << ": can't open a file for both reading and writing at once. See http://man7.org/linux/man-pages/man2/open.2.html.\n";
    exit(1);
  }
}

void check_mode(int reg) {
  if (Reg[reg].u != 0600) {
    cerr << HEXWORD << EIP << ": SubX is oblivious to file permissions; register " << reg << " must be 0x180.\n";
    exit(1);
  }
}

:(before "End Globals")
// Very primitive/fixed/insecure mmap segments for now.
uint32_t Segments_allocated_above = END_HEAP;
:(code)
// always allocate multiples of the segment size
uint32_t new_segment(uint32_t length) {
  assert(length > 0);
  uint32_t result = (Segments_allocated_above - length) & 0xff000000;  // same number of zeroes as SEGMENT_ALIGNMENT
  if (result <= START_HEAP) {
    raise << "Allocated too many segments; the VM ran out of memory. "
          << "Maybe SEGMENT_ALIGNMENT can be smaller?\n" << die();
  }
  Mem.push_back(vma(result, result+length));
  Segments_allocated_above = result;
  return result;
}
