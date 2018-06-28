// https://github.com/kragen/stoneknifeforth/blob/702d2ebe1b/386.c

:(before "End Main")
assert(argc > 1);
if (is_equal(argv[1], "run")) {
  assert(argc > 2);
  reset();
  load_elf(argv[2]);
  while (EIP < End_of_program)
    run_one_instruction();
}

:(code)
void load_elf(const string& filename) {
  int fd = open(filename.c_str(), O_RDONLY);
  if (fd < 0) die("%s: open", filename.c_str());
  off_t size = lseek(fd, 0, SEEK_END);
  lseek(fd, 0, SEEK_SET);
  uint8_t* elf_contents = static_cast<uint8_t*>(malloc(size));
  if (elf_contents == NULL) die("malloc(%d)", size);
  ssize_t read_size = read(fd, elf_contents, size);
  if (size != read_size) die("read → %d (!= %d)", size, read_size);
  load_elf_contents(elf_contents, size);
  free(elf_contents);
}

void load_elf_contents(uint8_t* elf_contents, size_t size) {
  uint8_t magic[5] = {0};
  memcpy(magic, elf_contents, 4);
  if (memcmp(magic, "\177ELF", 4) != 0)
    die("Invalid ELF file starting with \"%s\"", magic);
  if (elf_contents[4] != 1)
    die("Only 32-bit ELF files (4-byte words; virtual addresses up to 4GB) supported.\n");
  if (elf_contents[5] != 1)
    die("Only little-endian ELF files supported.\n");
  // unused: remaining 10 bytes of e_ident
  uint32_t e_machine_type = u32_in(&elf_contents[16]);
  if (e_machine_type != 0x00030002)
    die("ELF type/machine 0x%x isn't i386 executable", e_machine_type);
  // unused: e_version. We only support version 1, and later versions will be backwards compatible.
  uint32_t e_entry = u32_in(&elf_contents[24]);
  uint32_t e_phoff = u32_in(&elf_contents[28]);
  // unused: e_shoff
  // unused: e_flags
  uint32_t e_ehsize = u16_in(&elf_contents[40]);
  if (e_ehsize < 52) die("Invalid binary; ELF header too small\n");
  uint32_t e_phentsize = u16_in(&elf_contents[42]);
  uint32_t e_phnum = u16_in(&elf_contents[44]);
  cerr << e_phnum << " entries in the program header, each " << e_phentsize << " bytes long\n";
  // unused: e_shentsize
  // unused: e_shnum
  // unused: e_shstrndx

  for (size_t i = 0;  i < e_phnum;  ++i)
    load_program_header(elf_contents, size, e_phoff + i*e_phentsize, e_ehsize);

  // TODO: need to set up real stack somewhere

  Reg[ESP].u = Reg[EBP].u = End_of_program;
  EIP = e_entry;
}

void load_program_header(uint8_t* elf_contents, size_t size, uint32_t offset, uint32_t e_ehsize) {
  uint32_t p_type = u32_in(&elf_contents[offset]);
  cerr << "program header at offset " << offset << ": type " << p_type << '\n';
  if (p_type != 1) {
    cerr << "ignoring segment at offset " << offset << " of non PT_LOAD type " << p_type << " (see http://refspecs.linuxbase.org/elf/elf.pdf)\n";
    return;
  }
  uint32_t p_offset = u32_in(&elf_contents[offset + 4]);
  uint32_t p_vaddr = u32_in(&elf_contents[offset + 8]);
  if (e_ehsize > p_vaddr) die("Invalid binary; program header overlaps ELF header\n");
  // unused: p_paddr
  uint32_t p_filesz = u32_in(&elf_contents[offset + 16]);
  uint32_t p_memsz = u32_in(&elf_contents[offset + 20]);
  if (p_filesz != p_memsz)
    die("Can't handle segments where p_filesz != p_memsz (see http://refspecs.linuxbase.org/elf/elf.pdf)\n");

  if (p_offset + p_filesz > size)
    die("Invalid binary; segment at offset %d is too large: wants to end at %d but the file ends at %d\n", offset, p_offset+p_filesz, size);
  Mem.resize(p_vaddr + p_memsz);
  if (size > p_memsz) size = p_memsz;
  cerr << "blitting file offsets (" << p_offset << ", " << (p_offset+p_filesz) << ") to addresses (" << p_vaddr << ", " << (p_vaddr+p_memsz) << ")\n";
  for (size_t i = 0;  i < p_filesz;  ++i)
    Mem.at(p_vaddr + i) = elf_contents[p_offset + i];
  if (End_of_program < p_vaddr+p_memsz)
    End_of_program = p_vaddr+p_memsz;
}

inline uint32_t u32_in(uint8_t* p) {
  return p[0] | p[1] << 8 | p[2] << 16 | p[3] << 24;
}

inline uint16_t u16_in(uint8_t* p) {
  return p[0] | p[1] << 8;
}

void die(const char* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  if (errno)
    perror("‌");
  else
    fprintf(stderr, "\n");
  va_end(args);
  abort();
}

:(before "End Types")
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>
