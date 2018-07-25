// Helper for debugging and testing.
// Based on https://github.com/kragen/stoneknifeforth/blob/702d2ebe1b/386.c

:(before "End Main")
assert(argc > 1);
if (is_equal(argv[1], "run")) {
  START_TRACING_UNTIL_END_OF_SCOPE;
  assert(argc > 2);
  reset();
  cerr << std::hex;
  initialize_mem();
  Mem_offset = CODE_START;
  load_elf(argv[2]);
  while (EIP < End_of_program)  // weak final-gasp termination check
    run_one_instruction();
  info << "executed past end of the world: " << EIP << " vs " << End_of_program << '\n';
}

:(code)
void load_elf(const string& filename) {
  int fd = open(filename.c_str(), O_RDONLY);
  if (fd < 0) raise << filename.c_str() << ": open" << perr() << '\n' << die();
  off_t size = lseek(fd, 0, SEEK_END);
  lseek(fd, 0, SEEK_SET);
  uint8_t* elf_contents = static_cast<uint8_t*>(malloc(size));
  if (elf_contents == NULL) raise << "malloc(" << size << ')' << perr() << '\n' << die();
  ssize_t read_size = read(fd, elf_contents, size);
  if (size != read_size) raise << "read → " << size << " (!= " << read_size << ')' << perr() << '\n' << die();
  load_elf_contents(elf_contents, size);
  free(elf_contents);
}

void load_elf_contents(uint8_t* elf_contents, size_t size) {
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
  info << e_phnum << " entries in the program header, each " << e_phentsize << " bytes long\n";
  // unused: e_shentsize
  // unused: e_shnum
  // unused: e_shstrndx

  for (size_t i = 0;  i < e_phnum;  ++i)
    load_segment_from_program_header(elf_contents, size, e_phoff + i*e_phentsize, e_ehsize);

  // initialize code and stack
  Reg[ESP].u = AFTER_STACK;
  Reg[EBP].u = 0;
  EIP = e_entry;
}

void load_segment_from_program_header(uint8_t* elf_contents, size_t size, uint32_t offset, uint32_t e_ehsize) {
  uint32_t p_type = u32_in(&elf_contents[offset]);
  info << "program header at offset " << offset << ": type " << p_type << '\n';
  if (p_type != 1) {
    info << "ignoring segment at offset " << offset << " of non PT_LOAD type " << p_type << " (see http://refspecs.linuxbase.org/elf/elf.pdf)\n";
    return;
  }
  uint32_t p_offset = u32_in(&elf_contents[offset + 4]);
  uint32_t p_vaddr = u32_in(&elf_contents[offset + 8]);
  if (e_ehsize > p_vaddr) raise << "Invalid binary; program header overlaps ELF header\n" << die();
  // unused: p_paddr
  uint32_t p_filesz = u32_in(&elf_contents[offset + 16]);
  uint32_t p_memsz = u32_in(&elf_contents[offset + 20]);
  if (p_filesz != p_memsz)
    raise << "Can't handle segments where p_filesz != p_memsz (see http://refspecs.linuxbase.org/elf/elf.pdf)\n" << die();

  if (p_offset + p_filesz > size)
    raise << "Invalid binary; segment at offset " << offset << " is too large: wants to end at " << p_offset+p_filesz << " but the file ends at " << size << '\n' << die();
  if (Mem.size() < p_vaddr + p_memsz)
    Mem.resize(p_vaddr + p_memsz);
  if (size > p_memsz) size = p_memsz;
  info << "blitting file offsets (" << p_offset << ", " << (p_offset+p_filesz) << ") to addresses (" << p_vaddr << ", " << (p_vaddr+p_memsz) << ")\n";
  for (size_t i = 0;  i < p_filesz;  ++i)
    write_mem_u8(p_vaddr+i, elf_contents[p_offset+i]);
  if (End_of_program < p_vaddr+p_memsz)
    End_of_program = p_vaddr+p_memsz;
}

:(before "End Includes")
// Very primitive/fixed/insecure ELF segments for now.
//   code: 0x08048000 -> 0x08048fff
//   data: 0x08049000 -> 0x08049fff
//   heap: 0x0804a000 -> 0x0804afff
//   stack: 0x0804bfff -> 0x0804b000 (downward)
const int CODE_START = 0x08048000;
const int SEGMENT_SIZE = 0x1000;
const int AFTER_STACK = 0x0804c000;
:(code)
void initialize_mem() {
  Mem.resize(AFTER_STACK - CODE_START);
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
ostream& operator<<(ostream& os, unused perr) {
  if (errno)
    os << ": " << strerror(errno);
  return os;
}

:(before "End Types")
struct die {};
:(code)
ostream& operator<<(unused ostream& os, unused die) {
  if (Trace_stream) Trace_stream->newline();
  exit(1);
}

:(before "End Includes")
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdarg.h>
#include <errno.h>

#define info cerr
// #define info dbg
