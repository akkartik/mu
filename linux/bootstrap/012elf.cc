//: Loading SubX programs from ELF binaries.
//: This will allow us to run them natively on a Linux kernel.
//: Based on https://github.com/kragen/stoneknifeforth/blob/702d2ebe1b/386.c

:(before "End Main")
assert(argc > 1);
if (is_equal(argv[1], "run")) {
  // Outside of tests, traces must be explicitly requested.
  if (Trace_file.is_open()) Trace_stream = new trace_stream;
  trace(2, "run") << "=== Starting to run" << end();
  if (argc <= 2) {
    raise << "Not enough arguments provided.\n" << die();
  }
  reset();
  cerr << std::hex;
  load_elf(argv[2], argc, argv);
  while (EIP < End_of_program)  // weak final-gasp termination check
    run_one_instruction();
  raise << "executed past end of the world: " << EIP << " vs " << End_of_program << '\n' << end();
  return 1;
}

:(code)
void load_elf(const string& filename, int argc, char* argv[]) {
  int fd = open(filename.c_str(), O_RDONLY);
  if (fd < 0) raise << filename.c_str() << ": open" << perr() << '\n' << die();
  off_t size = lseek(fd, 0, SEEK_END);
  lseek(fd, 0, SEEK_SET);
  uint8_t* elf_contents = static_cast<uint8_t*>(malloc(size));
  if (elf_contents == NULL) raise << "malloc(" << size << ')' << perr() << '\n' << die();
  ssize_t read_size = read(fd, elf_contents, size);
  if (size != read_size) raise << "read → " << size << " (!= " << read_size << ')' << perr() << '\n' << die();
  load_elf_contents(elf_contents, size, argc, argv);
  free(elf_contents);
}

void load_elf_contents(uint8_t* elf_contents, size_t size, int argc, char* argv[]) {
  uint8_t magic[5] = {0};
  memcpy(magic, elf_contents, 4);
  if (memcmp(magic, "\177ELF", 4) != 0)
    raise << "Invalid ELF file; starts with \"" << magic << '"' << die();
  if (elf_contents[4] != 1)
    raise << "Only 32-bit ELF files (4-byte words; virtual addresses up to 4GB) supported.\n" << die();
  if (elf_contents[5] != 1)
    raise << "Only little-endian ELF files supported.\n" << die();
  // unused: remaining 10 bytes of e_ident
  uint32_t e_machine_type = u32_in(&elf_contents[16]);
  if (e_machine_type != 0x00030002)
    raise << "ELF type/machine 0x" << HEXWORD << e_machine_type << " isn't i386 executable\n" << die();
  // unused: e_version. We only support version 1, and later versions will be backwards compatible.
  uint32_t e_entry = u32_in(&elf_contents[24]);
  uint32_t e_phoff = u32_in(&elf_contents[28]);
  // unused: e_shoff
  // unused: e_flags
  uint32_t e_ehsize = u16_in(&elf_contents[40]);
  if (e_ehsize < 52) raise << "Invalid binary; ELF header too small\n" << die();
  uint32_t e_phentsize = u16_in(&elf_contents[42]);
  uint32_t e_phnum = u16_in(&elf_contents[44]);
  trace(90, "load") << e_phnum << " entries in the program header, each " << e_phentsize << " bytes long" << end();
  // unused: e_shentsize
  // unused: e_shnum
  // unused: e_shstrndx

  set<uint32_t> overlap;  // to detect overlapping segments
  for (size_t i = 0;  i < e_phnum;  ++i)
    load_segment_from_program_header(elf_contents, i, size, e_phoff + i*e_phentsize, e_ehsize, overlap);

  // initialize code and stack
  assert(overlap.find(STACK_SEGMENT) == overlap.end());
  Mem.push_back(vma(STACK_SEGMENT));
  assert(overlap.find(AFTER_STACK) == overlap.end());
  // The stack grows downward.
  Reg[ESP].u = AFTER_STACK;
  Reg[EBP].u = 0;
  EIP = e_entry;

  // initialize args on stack
  // no envp for now
  // we wastefully use a separate page of memory for argv
  Mem.push_back(vma(ARGV_DATA_SEGMENT));
  uint32_t argv_data = ARGV_DATA_SEGMENT;
  for (int i = argc-1;  i >= /*skip 'subx_bin' and 'run'*/2;  --i) {
    push(argv_data);
    for (size_t j = 0;  j <= strlen(argv[i]);  ++j) {
      assert(overlap.find(argv_data) == overlap.end());  // don't bother comparing ARGV and STACK
      write_mem_u8(argv_data, argv[i][j]);
      argv_data += sizeof(char);
      assert(argv_data < ARGV_DATA_SEGMENT + SEGMENT_ALIGNMENT);
    }
  }
  push(argc-/*skip 'subx_bin' and 'run'*/2);
}

void push(uint32_t val) {
  Reg[ESP].u -= 4;
  if (Reg[ESP].u < STACK_SEGMENT) {
    raise << "The stack overflowed its segment. "
          << "Maybe SPACE_FOR_SEGMENT should be larger? "
          << "Or you need to carve out an exception for the stack segment "
          << "to be larger.\n" << die();
  }
  trace(Callstack_depth+1, "run") << "decrementing ESP to 0x" << HEXWORD << Reg[ESP].u << end();
  trace(Callstack_depth+1, "run") << "pushing value 0x" << HEXWORD << val << end();
  write_mem_u32(Reg[ESP].u, val);
}

void load_segment_from_program_header(uint8_t* elf_contents, int segment_index, size_t size, uint32_t offset, uint32_t e_ehsize, set<uint32_t>& overlap) {
  uint32_t p_type = u32_in(&elf_contents[offset]);
  trace(90, "load") << "program header at offset " << offset << ": type " << p_type << end();
  if (p_type != 1) {
    trace(90, "load") << "ignoring segment at offset " << offset << " of non PT_LOAD type " << p_type << " (see http://refspecs.linuxbase.org/elf/elf.pdf)" << end();
    return;
  }
  uint32_t p_offset = u32_in(&elf_contents[offset + 4]);
  uint32_t p_vaddr = u32_in(&elf_contents[offset + 8]);
  if (e_ehsize > p_vaddr) raise << "Invalid binary; program header overlaps ELF header\n" << die();
  // unused: p_paddr
  uint32_t p_filesz = u32_in(&elf_contents[offset + 16]);
  uint32_t p_memsz = u32_in(&elf_contents[offset + 20]);
  if (p_filesz != p_memsz)
    raise << "Can't yet handle segments where p_filesz != p_memsz (see http://refspecs.linuxbase.org/elf/elf.pdf)\n" << die();

  if (p_offset + p_filesz > size)
    raise << "Invalid binary; segment at offset " << offset << " is too large: wants to end at " << p_offset+p_filesz << " but the file ends at " << size << '\n' << die();
  if (p_memsz >= SEGMENT_ALIGNMENT) {
    raise << "Code segment too small for SubX; for now please manually increase SEGMENT_ALIGNMENT.\n" << end();
    return;
  }
  trace(90, "load") << "blitting file offsets (" << p_offset << ", " << (p_offset+p_filesz) << ") to addresses (" << p_vaddr << ", " << (p_vaddr+p_memsz) << ')' << end();
  if (size > p_memsz) size = p_memsz;
  Mem.push_back(vma(p_vaddr));
  for (size_t i = 0;  i < p_filesz;  ++i) {
    assert(overlap.find(p_vaddr+i) == overlap.end());
    write_mem_u8(p_vaddr+i, elf_contents[p_offset+i]);
    overlap.insert(p_vaddr+i);
  }
  if (segment_index == 0 && End_of_program < p_vaddr+p_memsz)
    End_of_program = p_vaddr+p_memsz;
}

:(before "End Includes")
// Very primitive/fixed/insecure ELF segments for now.
//   --- inaccessible:        0x00000000 -> 0x08047fff
//   code:                    0x09000000 -> 0x09ffffff (specified in ELF binary)
//   data:                    0x0a000000 -> 0x0affffff (specified in ELF binary)
//                      --- heap gets mmap'd somewhere here ---
//   stack:                   0xbdffffff -> 0xbd000000 (downward; not in ELF binary)
//   argv hack:               0xbf000000 -> 0xbfffffff (not in ELF binary)
//   --- reserved for kernel: 0xc0000000 -> ...
const uint32_t START_HEAP        = 0x0b000000;
const uint32_t END_HEAP          = 0xbd000000;
const uint32_t STACK_SEGMENT     = 0xbd000000;
const uint32_t AFTER_STACK       = 0xbe000000;
const uint32_t ARGV_DATA_SEGMENT = 0xbf000000;
// When updating the above memory map, don't forget to update `mmap`'s
// implementation in the 'syscalls' layer.
:(before "End Dump Info for Instruction")
//? dump_stack();  // slow
:(code)
void dump_stack() {
  ostringstream out;
  trace(Callstack_depth+1, "run") << "stack:" << end();
  for (uint32_t a = AFTER_STACK-4;  a > Reg[ESP].u;  a -= 4)
    trace(Callstack_depth+2, "run") << "  0x" << HEXWORD << a << " => 0x" << HEXWORD << read_mem_u32(a) << end();
  trace(Callstack_depth+2, "run") << "  0x" << HEXWORD << Reg[ESP].u << " => 0x" << HEXWORD << read_mem_u32(Reg[ESP].u) << "  <=== ESP" << end();
  for (uint32_t a = Reg[ESP].u-4;  a > Reg[ESP].u-40;  a -= 4)
    trace(Callstack_depth+2, "run") << "  0x" << HEXWORD << a << " => 0x" << HEXWORD << read_mem_u32(a) << end();
}

inline uint32_t u32_in(uint8_t* p) {
  return p[0] | p[1] << 8 | p[2] << 16 | p[3] << 24;
}

inline uint16_t u16_in(uint8_t* p) {
  return p[0] | p[1] << 8;
}

:(before "End Types")
struct perr {};
:(code)
ostream& operator<<(ostream& os, perr /*unused*/) {
  if (errno)
    os << ": " << strerror(errno);
  return os;
}

:(before "End Includes")
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdarg.h>
#include <errno.h>
#include <unistd.h>
