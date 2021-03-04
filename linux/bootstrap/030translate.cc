//: After that lengthy prelude to define an x86 emulator, we are now ready to
//: start translating SubX notation.

//: Translator workflow: read 'source' file. Run a series of transforms on it,
//: each passing through what it doesn't understand. The final program should
//: be just machine code, suitable to emulate, or to write to an ELF binary.

:(before "End Main")
if (is_equal(argv[1], "translate")) {
  // Outside of tests, traces must be explicitly requested.
  if (Trace_file.is_open()) Trace_stream = new trace_stream;
  reset();
  // Begin bootstrap translate
  program p;
  string output_filename;
  for (int i = /*skip 'bootstrap translate'*/2;  i < argc;  ++i) {
    if (is_equal(argv[i], "-o")) {
      ++i;
      if (i >= argc) {
        print_translate_usage();
        cerr << "'-o' must be followed by a filename to write results to\n";
        exit(1);
      }
      output_filename = argv[i];
    }
    else {
      trace(2, "parse") << argv[i] << end();
      ifstream fin(argv[i]);
      if (!fin) {
        cerr << "could not open " << argv[i] << '\n';
        return 1;
      }
      parse(fin, p);
      if (trace_contains_errors()) return 1;
    }
  }
  if (p.segments.empty()) {
    print_translate_usage();
    cerr << "nothing to do; must provide at least one file to read\n";
    exit(1);
  }
  if (output_filename.empty()) {
    print_translate_usage();
    cerr << "must provide a filename to write to using '-o'\n";
    exit(1);
  }
  trace(2, "transform") << "begin" << end();
  transform(p);
  if (trace_contains_errors()) return 1;
  trace(2, "translate") << "begin" << end();
  save_elf(p, output_filename);
  if (trace_contains_errors()) {
    unlink(output_filename.c_str());
    return 1;
  }
  // End bootstrap translate
  return 0;
}

:(code)
void transform(program& p) {
  // End transform(program& p)
}

void print_translate_usage() {
  cerr << "Usage: bootstrap translate file1 file2 ... -o output\n";
}

// write out a program to a bare-bones ELF file
void save_elf(const program& p, const string& filename) {
  ofstream out(filename.c_str(), ios::binary);
  save_elf(p, out);
  out.close();
}

void save_elf(const program& p, ostream& out) {
  // validation: stay consistent with the self-hosted translator
  if (p.entry == 0) {
    raise << "no 'Entry' label found\n" << end();
    return;
  }
  if (find(p, "data") == NULL) {
    raise << "must include a 'data' segment\n" << end();
    return;
  }
  // processing
  write_elf_header(out, p);
  for (size_t i = 0;  i < p.segments.size();  ++i)
    write_segment(p.segments.at(i), out);
}

void write_elf_header(ostream& out, const program& p) {
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
  uint32_t e_entry = p.entry;
  // Override e_entry
  emit(e_entry);
  // e_phoff -- immediately after ELF header
  uint32_t e_phoff = 0x34;
  emit(e_phoff);
  // e_shoff; unused
  uint32_t dummy32 = 0;
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
    const segment& curr = p.segments.at(i);
    //// phdr
    // p_type
    uint32_t p_type = 0x1;
    emit(p_type);
    // p_offset
    emit(p_offset);
    // p_vaddr
    uint32_t p_start = curr.start;
    emit(p_start);
    // p_paddr
    emit(p_start);
    // p_filesz
    uint32_t size = num_words(curr);
    assert(p_offset + size < SEGMENT_ALIGNMENT);
    emit(size);
    // p_memsz
    emit(size);
    // p_flags
    uint32_t p_flags = (curr.name == "code") ? /*r-x*/0x5 : /*rw-*/0x6;
    emit(p_flags);

    // p_align
    // "As the system creates or augments a process image, it logically copies
    // a file's segment to a virtual memory segment.  When—and if— the system
    // physically reads the file depends on the program's execution behavior,
    // system load, and so on.  A process does not require a physical page
    // unless it references the logical page during execution, and processes
    // commonly leave many pages unreferenced. Therefore delaying physical
    // reads frequently obviates them, improving system performance. To obtain
    // this efficiency in practice, executable and shared object files must
    // have segment images whose file offsets and virtual addresses are
    // congruent, modulo the page size." -- http://refspecs.linuxbase.org/elf/elf.pdf (page 95)
    uint32_t p_align = 0x1000;  // default page size on linux
    emit(p_align);
    if (p_offset % p_align != p_start % p_align) {
      raise << "segment starting at 0x" << HEXWORD << p_start << " is improperly aligned; alignment for p_offset " << p_offset << " should be " << (p_offset % p_align) << " but is " << (p_start % p_align) << '\n' << end();
      return;
    }

    // prepare for next segment
    p_offset += size;
  }
#undef O
#undef emit
}

void write_segment(const segment& s, ostream& out) {
  for (int i = 0;  i < SIZE(s.lines);  ++i) {
    const vector<word>& w = s.lines.at(i).words;
    for (int j = 0;  j < SIZE(w);  ++j) {
      uint8_t x = hex_byte(w.at(j).data);  // we're done with metadata by this point
      out.write(reinterpret_cast<const char*>(&x), /*sizeof(byte)*/1);
    }
  }
}

uint32_t num_words(const segment& s) {
  uint32_t sum = 0;
  for (int i = 0;  i < SIZE(s.lines);  ++i)
    sum += SIZE(s.lines.at(i).words);
  return sum;
}

:(before "End Includes")
using std::ios;
