//: Start allowing us to not specify precise addresses for the start of each
//: segment.
//: This gives up a measure of control in placing code and data.

:(scenario segment_name)
== code
05/add 0x0d0c0b0a/imm32  # add 0x0d0c0b0a to EAX
# code starts at 0x08048000 + p_offset, which is 0x54 for a single-segment binary
+load: 0x08048054 -> 05
+load: 0x08048055 -> 0a
+load: 0x08048056 -> 0b
+load: 0x08048057 -> 0c
+load: 0x08048058 -> 0d
+run: add imm32 0x0d0c0b0a to reg EAX
+run: storing 0x0d0c0b0a

//: update the parser to handle non-numeric segment name

:(before "End Segment Parsing Special-cases(segment_title)")
if (!starts_with(segment_title, "0x")) {
  trace(99, "parse") << "new segment " << segment_title << end();
  out.segments.push_back(segment());
}

//: compute segment address

:(before "End Level-2 Transforms")
Transform.push_back(compute_segment_starts);

:(code)
void compute_segment_starts(program& p) {
  trace(99, "transform") << "-- compute segment addresses" << end();
  uint32_t p_offset = /*size of ehdr*/0x34 + SIZE(p.segments)*0x20/*size of each phdr*/;
  for (size_t i = 0;  i < p.segments.size();  ++i) {
    segment& curr = p.segments.at(i);
    if (curr.start == 0) {
      curr.start = CODE_START + i*SEGMENT_SIZE + p_offset;
      trace(99, "transform") << "segment " << i << " begins at address 0x" << HEXWORD << curr.start << end();
    }
    p_offset += size_of(curr);
    assert(p_offset < SEGMENT_SIZE);  // for now we get less and less available space in each successive segment
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
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    const word& curr = inst.words.at(i);
    if (has_operand_metadata(curr, "disp32") || has_operand_metadata(curr, "imm32"))  // only multi-byte operands
      sum += 4;
    // End num_bytes(curr) Special-cases
    else
      sum++;
  }
  return sum;
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
//: aware in this layer of certain operand types that will eventually occupy
//: multiple bytes.
//:
//: The layer to expand labels later hooks into num_bytes() to teach this
//: layer that labels occupy zero space in the binary.
