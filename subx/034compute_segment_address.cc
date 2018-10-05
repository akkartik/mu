//: Start allowing us to not specify precise addresses for the start of each
//: segment.
//: This gives up a measure of control in placing code and data.

:(scenario segment_name)
== code
05/add 0x0d0c0b0a/imm32  # add 0x0d0c0b0a to EAX
# code starts at 0x08048000 + p_offset, which is 0x54 for a single-segment binary
+load: 0x09000054 -> 05
+load: 0x09000055 -> 0a
+load: 0x09000056 -> 0b
+load: 0x09000057 -> 0c
+load: 0x09000058 -> 0d
+run: add imm32 0x0d0c0b0a to reg EAX
+run: storing 0x0d0c0b0a

//: Update the parser to handle non-numeric segment name.
//:
//: We'll also support repeated segments with non-numeric names.
//: When we encounter a new reference to an existing segment we'll *prepend*
//: the new data to existing data for the segment.

:(before "End Globals")
map</*name*/string, int> Segment_index;
bool Currently_parsing_named_segment = false;  // global to permit cross-layer communication
int Currently_parsing_segment_index = -1;  // global to permit cross-layer communication
:(before "End Reset")
Segment_index.clear();
Currently_parsing_named_segment = false;
Currently_parsing_segment_index = -1;

:(before "End Segment Parsing Special-cases(segment_title)")
if (!starts_with(segment_title, "0x")) {
  Currently_parsing_named_segment = true;
  if (!contains_key(Segment_index, segment_title)) {
    trace(99, "parse") << "new segment '" << segment_title << "'" << end();
    if (segment_title == "code")
      put(Segment_index, segment_title, 0);
    else if (segment_title == "data")
      put(Segment_index, segment_title, 1);
    else
      put(Segment_index, segment_title, max(2, SIZE(out.segments)));
    out.segments.push_back(segment());
  }
  else {
    trace(99, "parse") << "prepending to segment '" << segment_title << "'" << end();
  }
  Currently_parsing_segment_index = get(Segment_index, segment_title);
}

:(before "End flush(p, lines) Special-cases")
if (Currently_parsing_named_segment) {
  if (p.segments.empty() || Currently_parsing_segment_index < 0) {
    raise << "input does not start with a '==' section header\n" << end();
    return;
  }
  trace(99, "parse") << "flushing to segment" << end();
  vector<line>& curr_segment_data = p.segments.at(Currently_parsing_segment_index).lines;
  curr_segment_data.insert(curr_segment_data.begin(), lines.begin(), lines.end());
  lines.clear();
  Currently_parsing_named_segment = false;
  Currently_parsing_segment_index = -1;
  return;
}

:(scenario repeated_segment_merges_data)
== code
05/add 0x0d0c0b0a/imm32  # add 0x0d0c0b0a to EAX
== code
2d/subtract 0xddccbbaa/imm32  # subtract 0xddccbbaa from EAX
+parse: new segment 'code'
+parse: prepending to segment 'code'
+load: 0x09000054 -> 2d
+load: 0x09000055 -> aa
+load: 0x09000056 -> bb
+load: 0x09000057 -> cc
+load: 0x09000058 -> dd
+load: 0x09000059 -> 05
+load: 0x0900005a -> 0a
+load: 0x0900005b -> 0b
+load: 0x0900005c -> 0c
+load: 0x0900005d -> 0d

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
      curr.start = CODE_SEGMENT + i*SPACE_FOR_SEGMENT + p_offset;
      trace(99, "transform") << "segment " << i << " begins at address 0x" << HEXWORD << curr.start << end();
    }
    p_offset += size_of(curr);
    assert(p_offset < INITIAL_SEGMENT_SIZE);  // for now we get less and less available space in each successive segment
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
