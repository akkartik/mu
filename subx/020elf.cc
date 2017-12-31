// https://github.com/kragen/stoneknifeforth/blob/702d2ebe1b/386.c

:(before "End Main")
assert(argc > 1);
reset();
load_elf(argv[1]);
while (EIP < End_of_program)
  run_one_instruction();

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

void load_elf_contents(uint8_t* elf_contents, size_t length) {
  uint8_t magic[5] = {0};
  memcpy(magic, elf_contents, 4);
  if (0 != memcmp(magic, "\177ELF", 4))
    die("Invalid ELF file starting with \"%s\"", magic);

  uint32_t e_type = u32_in(&elf_contents[16]);
  if (0x00030002 != e_type)
    die("ELF type/machine 0x%x isn't i386 executable", e_type);

  uint32_t e_entry = u32_in(&elf_contents[24]);
  uint32_t e_phoff = u32_in(&elf_contents[28]);
  uint32_t p_vaddr = u32_in(&elf_contents[e_phoff + 8]);
  uint32_t p_memsz = u32_in(&elf_contents[e_phoff + 20]);

  Mem.resize(p_memsz);  // TODO: not sure if this should be + p_vaddr
  if (length > p_memsz - p_vaddr) length = p_memsz - p_vaddr;
  for (size_t i = 0;  i < length;  ++i)
    Mem.at(p_vaddr + i) = elf_contents[i];
  End_of_program = p_memsz;

  // TODO: need to set up real stack somewhere

  Reg[ESP].u = Reg[EBP].u = End_of_program;
  EIP = e_entry;
}

inline uint32_t u32_in(uint8_t* p) {
  return p[0] | p[1] << 8 | p[2] << 16 | p[3] << 24;
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
