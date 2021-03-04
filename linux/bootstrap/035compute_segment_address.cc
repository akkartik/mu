//: ELF binaries have finicky rules about the precise alignment each segment
//: should start at. They depend on the amount of code in a program.
//: We shouldn't expect people to adjust segment addresses everytime they make
//: a change to their programs.
//: Let's start taking the given segment addresses as guidelines, and adjust
//: them as necessary.
//: This gives up a measure of control in placing code and data.

void test_segment_name() {
  run(
      "== code 0x09000000\n"
      "05/add-to-EAX  0x0d0c0b0a/imm32\n"
      // code starts at 0x09000000 + p_offset, which is 0x54 for a single-segment binary
  );
  CHECK_TRACE_CONTENTS(
      "load: 0x09000054 -> 05\n"
      "load: 0x09000055 -> 0a\n"
      "load: 0x09000056 -> 0b\n"
      "load: 0x09000057 -> 0c\n"
      "load: 0x09000058 -> 0d\n"
      "run: add imm32 0x0d0c0b0a to EAX\n"
      "run: storing 0x0d0c0b0a\n"
  );
}

//: compute segment address

:(before "End Transforms")
Transform.push_back(compute_segment_starts);

:(code)
void compute_segment_starts(program& p) {
  trace(3, "transform") << "-- compute segment addresses" << end();
  uint32_t p_offset = /*size of ehdr*/0x34 + SIZE(p.segments)*0x20/*size of each phdr*/;
  for (size_t i = 0;  i < p.segments.size();  ++i) {
    segment& curr = p.segments.at(i);
    if (curr.start >= 0x08000000) {
      // valid address for user space, so assume we're creating a real ELF binary, not just running a test
      curr.start &= 0xfffff000;  // same number of zeros as the p_align used when emitting the ELF binary
      curr.start |= (p_offset & 0xfff);
      trace(99, "transform") << "segment " << i << " begins at address 0x" << HEXWORD << curr.start << end();
    }
    p_offset += size_of(curr);
    assert(p_offset < SEGMENT_ALIGNMENT);  // for now we get less and less available space in each successive segment
  }
}

uint32_t size_of(const segment& s) {
  uint32_t sum = 0;
  for (int i = 0;  i < SIZE(s.lines);  ++i)
    sum += num_bytes(s.lines.at(i));
  return sum;
}

// Assumes all bitfields are packed.
uint32_t num_bytes(const line& inst) {
  uint32_t sum = 0;
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    sum += size_of(inst.words.at(i));
  return sum;
}

int size_of(const word& w) {
  if (has_argument_metadata(w, "disp32") || has_argument_metadata(w, "imm32"))
    return 4;
  else if (has_argument_metadata(w, "disp16"))
    return 2;
  // End size_of(word w) Special-cases
  else
    return 1;
}

//: Dependencies:
//: - We'd like to compute segment addresses before setting up global variables,
//:   because computing addresses for global variables requires knowing where
//:   the data segment starts.
//: - We'd like to finish expanding labels before computing segment addresses,
//:   because it would make computing the sizes of segments more self-contained
//:   (num_bytes).
//:
//: Decision: compute segment addresses before expanding labels, by being
//: aware in this layer of certain argument types that will eventually occupy
//: multiple bytes.
//:
//: The layer to expand labels later hooks into num_bytes() to teach this
//: layer that labels occupy zero space in the binary.
