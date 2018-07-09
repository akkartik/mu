//: Beginnings of a nicer way to build SubX programs.
//: We're going to question every notion, including "Assembly language" and
//: "compiler".
//: Motto: Abstract nothing, check everything.
//:
//: Workflow: read 'source' file as a single string. Run a series of
//: transforms on it, each converting to a new string. The final string should
//: be just machine code and comments, suitable to pass to load_program().

:(before "End Types")
typedef void (*transform_fn)(const string& input, string& output);
:(before "End Globals")
vector<transform_fn> Transform;

:(before "End Includes")
const int START = 0x08048000;
:(before "End Main")
if (is_equal(argv[1], "translate")) {
  assert(argc > 3);
  string program;
  slurp(argv[2], program);
  perform_all_transforms(program);
  dump_elf(program, argv[3]);
}

:(code)
void perform_all_transforms(string& program) {
  string& in = program;
  string out;
  for (int t = 0;  t < SIZE(Transform);  ++t, in.swap(out), out.clear())
    (*Transform.at(t))(in, out);
}

// write out the current Memory contents from address 1 to End_of_program to a
// bare-bones ELF file with a single section/segment and a hard-coded origin address.
void dump_elf(const string& program, const char* filename) {
  initialize_mem();
  // load program into memory, filtering out comments
  load_program(program, 1);  // Not where 'program' should be loaded for running.
                             // But we're not going to run it right now, so we
                             // can load it anywhere.
  // dump contents of memory into ELF binary
  ofstream out(filename, ios::binary);
  dump_elf_header(out);
  for (size_t i = 1;  i < End_of_program;  ++i) {
    char c = read_mem_u8(i);
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
  uint32_t p_offset = /*size of ehdr*/52 + /*size of phdr*/32;
  emit(p_offset);
  // p_vaddr
  emit(e_entry);
  // p_paddr
  emit(e_entry);
  // p_filesz
  uint32_t size = End_of_program - /*we're not using location 0*/1;
  emit(size);
  // p_memsz
  emit(size);
  // p_flags
  uint32_t p_flags = 0x5;  // r-x
  emit(p_flags);
  // p_align
  uint32_t p_align = 0x1000;
  emit(p_align);
#undef O
}

void slurp(const char* filename, string& out) {
  ifstream fin(filename);
  fin >> std::noskipws;
  ostringstream fout;
  char c = '\0';
  while(has_data(fin)) {
    fin >> c;
    fout << c;
  }
  fout.str().swap(out);
}

:(after "Begin run() For Scenarios")
perform_all_transforms(text_bytes);

:(before "End Includes")
using std::ios;
