//: Start allowing us to not specify precise addresses for the start of each
//: segment.
//: This gives up a measure of control in placing code and data.

:(scenario segment_name)
% Mem_offset = CODE_START;
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

:(before "End Level-2 Transforms")
Transform.push_back(compute_segment_starts);

:(code)
void compute_segment_starts(program& p) {
  uint32_t p_offset = /*size of ehdr*/0x34 + SIZE(p.segments)*0x20/*size of each phdr*/;
  for (size_t i = 0;  i < p.segments.size();  ++i) {
    segment& curr = p.segments.at(i);
    if (curr.start == 0)
      curr.start = CODE_START + i*SEGMENT_SIZE + p_offset;
    p_offset += num_words(curr);
    assert(p_offset < SEGMENT_SIZE);  // for now we get less and less available space in each successive segment
  }
}
