//: Beginnings of a nicer way to build SubX programs.
//: We're going to question every notion, including "Assembly language" and
//: "compiler".
//: Motto: Abstract nothing, check everything.
//:
//: Workflow: read 'source' file. Run a series of transforms on it, each
//: passing through what it doesn't understand. The final program should be
//: just machine code, suitable to write to an ELF binary.

:(before "End Main")
if (is_equal(argv[1], "translate")) {
  assert(argc > 3);
  program p;
  ifstream fin(argv[2]);
  parse(fin, p);
  if (trace_contains_errors()) return 1;
  transform(p);
  if (trace_contains_errors()) return 1;
  dump_elf(p, argv[3]);
}

:(code)
// write out a program to a bare-bones ELF file
void dump_elf(const program& p, const char* filename) {
  ofstream out(filename, ios::binary);
  dump_elf_header(out, p);
  for (size_t i = 0;  i < p.segments.size();  ++i)
    dump_segment(p.segments.at(i), out);
  out.close();
}

void dump_elf_header(ostream& out, const program& p) {
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
  int e_entry = p.segments.at(0).start;  // convention
  emit(e_entry);
  // e_phoff -- immediately after ELF header
  int e_phoff = 0x34;
  emit(e_phoff);
  // e_shoff; unused
  int dummy32 = 0;
  emit(dummy32);
  // e_flags; unused
  emit(dummy32);
  // e_ehsize
  uint16_t e_ehsize = 0x34;
  emit(e_ehsize);
  // e_phentsize
  uint16_t e_phentsize = 0x20;
  emit(e_phentsize);
  // e_phnum
  uint16_t e_phnum = SIZE(p.segments);
  emit(e_phnum);
  // e_shentsize
  uint16_t dummy16 = 0x0;
  emit(dummy16);
  // e_shnum
  emit(dummy16);
  // e_shstrndx
  emit(dummy16);

  uint32_t p_offset = /*size of ehdr*/0x34 + SIZE(p.segments)*0x20/*size of each phdr*/;
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    //// phdr
    // p_type
    uint32_t p_type = 0x1;
    emit(p_type);
    // p_offset
    emit(p_offset);
    // p_vaddr
    emit(e_entry);
    // p_paddr
    emit(e_entry);
    // p_filesz
    uint32_t size = size_of(p.segments.at(i));
    assert(size < SEGMENT_SIZE);
    emit(size);
    // p_memsz
    emit(size);
    // p_flags
    uint32_t p_flags = (i == 0) ? /*r-x*/0x5 : /*rw-*/0x6;  // convention: only first segment is code
    emit(p_flags);
    // p_align
    uint32_t p_align = 0x4;
    emit(p_align);

    // prepare for next segment
    p_offset += size;
  }
#undef O
#undef emit
}

void dump_segment(const segment& s, ostream& out) {
  for (int i = 0;  i < SIZE(s.lines);  ++i) {
    const vector<word>& w = s.lines.at(i).words;
    for (int j = 0;  j < SIZE(w);  ++j) {
      uint8_t x = hex_byte(w.at(j).data);  // we're done with metadata by this point
      out.write(reinterpret_cast<const char*>(&x), /*sizeof(byte)*/1);
    }
  }
}

uint32_t size_of(const segment& s) {
  uint32_t sum = 0;
  for (int i = 0;  i < SIZE(s.lines);  ++i)
    sum += SIZE(s.lines.at(i).words);
  return sum;
}

:(before "End Includes")
using std::ios;
