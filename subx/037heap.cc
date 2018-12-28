//: Support for dynamic allocation.
//:
//: Just provide a special label marking the first unused address in the data
//: segment. Then we'll write SubX helpers to make use of it.

:(before "Begin rewrite_global_variables")
insert_heap_global_variable(p);
:(code)
void insert_heap_global_variable(program& p) {
  if (SIZE(p.segments) < 2)
    return;  // no data segment defined
  // Start-of-heap:
  p.segments.at(1).lines.push_back(label("Start-of-heap"));
}

line label(string s) {
  line result;
  result.words.push_back(word());
  result.words.back().data = (s+":");
  return result;
}

line imm32(const string& s) {
  line result;
  result.words.push_back(word());
  result.words.back().data = s;
  result.words.back().metadata.push_back("imm32");
  return result;
}
