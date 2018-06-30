:(before "End Includes")
const int START = 0x08048000;
:(before "End Main")
if (is_equal(argv[1], "translate")) {
  assert(argc > 3);
  ifstream in(argv[2]);
  Mem.resize(1024);
  load_program(in, 1);  // since we're not going to run it right now, we can load it anywhere
  dump_elf(argv[3]);
}

:(code)
// write out the current Memory contents from address 1 to End_of_program to a
// bare-bones ELF file with a single section/segment and a hard-coded origin address.
void dump_elf(const char* filename) {
  ofstream out(filename, ios::binary);
  dump_elf_header(out);
  for (size_t i = 1;  i < End_of_program;  ++i) {
    char c = Mem.at(i);
    out.write(&c, sizeof(c));
  }
  out.close();
}

void dump_elf_header(ostream& out) {
  char c = '\0';
#define O(X)  c = (X); out.write(&c, sizeof(c))
// host is required to be little-endian
#define emit(X)  out.write(reinterpret_cast<const char*>(&X), sizeof(X))
  //// ehdr
  // e_ident
  O(0x7f); O(/*E*/0x45); O(/*L*/0x4c); O(/*F*/0x46);
    O(0x1);  // 32-bit format
    O(0x1);  // little-endian
    O(0x1); O(0x0);
  for (size_t i = 0;  i < 8;  ++i) { O(0x0); }
  // e_type
  O(0x02); O(0x00);
  // e_machine
  O(0x03); O(0x00);
  // e_version
  O(0x01); O(0x00); O(0x00); O(0x00);
  // e_entry
  int e_entry = START + /*size of ehdr*/52 + /*size of phdr*/32;
  emit(e_entry);
  // e_phoff -- immediately after ELF header
  int e_phoff = 52;
  emit(e_phoff);
  // e_shoff; unused
  int dummy32 = 0;
  emit(dummy32);
  // e_flags; unused
  emit(dummy32);
  // e_ehsize
  uint16_t e_ehsize = 52;
  emit(e_ehsize);
  // e_phentsize
  uint16_t e_phentsize = 0x20;
  emit(e_phentsize);
  // e_phnum
  uint16_t e_phnum = 0x1;
  emit(e_phnum);
  // e_shentsize
  uint16_t dummy16 = 0x0;
  emit(dummy16);
  // e_shnum
  emit(dummy16);
  // e_shstrndx
  emit(dummy16);

  //// phdr
  // p_type
  uint32_t p_type = 0x1;
  emit(p_type);
  // p_offset
  emit(dummy32);
  // p_vaddr
  emit(START);
  // p_paddr
  emit(START);
  // p_filesz
  uint32_t size = (End_of_program-1) + /*size of ehdr*/52 + /*size of phdr*/32;
  emit(size);
  // p_memsz
  emit(size);
  // p_flags
  uint32_t p_flags = 0x5;
  emit(p_flags);
  // p_align
  uint32_t p_align = 0x1000;
  emit(p_align);
#undef O
}

:(before "End Includes")
using std::ios;
