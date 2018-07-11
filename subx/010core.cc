//:: simulated x86 registers; just a subset
//:    assume segment registers are hard-coded to 0
//:    no floating-point, MMX, etc. yet

:(before "End Types")
enum {
  EAX,
  ECX,
  EDX,
  EBX,
  ESP,
  EBP,
  ESI,
  EDI,
  NUM_INT_REGISTERS,
};
union reg {
  int32_t i;
  uint32_t u;
};
:(before "End Globals")
reg Reg[NUM_INT_REGISTERS] = { {0} };
uint32_t EIP = 1;  // preserve null pointer
:(before "End Reset")
bzero(Reg, sizeof(Reg));
EIP = 1;  // preserve null pointer

//:: simulated flag registers; just a subset that we care about

:(before "End Globals")
bool SF = false;  // sign flag
bool ZF = false;  // zero flag
bool OF = false;  // overflow flag
:(before "End Reset")
SF = ZF = OF = false;

//: how the flag registers are updated after each instruction

:(before "End Includes")
// Combine 'arg1' and 'arg2' with arithmetic operation 'op' and store the
// result in 'arg1', then update flags.
// beware: no side-effects in args
#define BINARY_ARITHMETIC_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be signed */ \
  int64_t tmp = arg1 op arg2; \
  arg1 = arg1 op arg2; \
  trace(2, "run") << "storing 0x" << HEXWORD << arg1 << end(); \
  SF = (arg1 < 0); \
  ZF = (arg1 == 0); \
  OF = (arg1 != tmp); \
}

// Combine 'arg1' and 'arg2' with bitwise operation 'op' and store the result
// in 'arg1', then update flags.
#define BINARY_BITWISE_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be unsigned */ \
  arg1 = arg1 op arg2; \
  trace(2, "run") << "storing 0x" << HEXWORD << arg1 << end(); \
  SF = (arg1 >> 31); \
  ZF = (arg1 == 0); \
  OF = false; \
}

//:: simulated RAM

:(before "End Globals")
vector<uint8_t> Mem;
uint32_t Mem_offset = 0;
uint32_t End_of_program = 0;
:(before "End Reset")
Mem.clear();
Mem.resize(1024);
Mem_offset = 0;
End_of_program = 0;
:(code)
// These helpers depend on Mem being laid out contiguously (so you can't use a
// map, etc.) and on the host also being little-endian.
inline uint8_t read_mem_u8(uint32_t addr) {
  return Mem.at(addr-Mem_offset);
}
inline int8_t read_mem_i8(uint32_t addr) {
  return static_cast<int8_t>(Mem.at(addr-Mem_offset));
}
inline uint32_t read_mem_u32(uint32_t addr) {
  return *reinterpret_cast<uint32_t*>(&Mem.at(addr-Mem_offset));
}
inline int32_t read_mem_i32(uint32_t addr) {
  return *reinterpret_cast<int32_t*>(&Mem.at(addr-Mem_offset));
}

inline uint8_t* mem_addr_u8(uint32_t addr) {
  return &Mem.at(addr-Mem_offset);
}
inline int8_t* mem_addr_i8(uint32_t addr) {
  return reinterpret_cast<int8_t*>(&Mem.at(addr-Mem_offset));
}
inline uint32_t* mem_addr_u32(uint32_t addr) {
  return reinterpret_cast<uint32_t*>(&Mem.at(addr-Mem_offset));
}
inline int32_t* mem_addr_i32(uint32_t addr) {
  return reinterpret_cast<int32_t*>(&Mem.at(addr-Mem_offset));
}

inline void write_mem_u8(uint32_t addr, uint8_t val) {
  Mem.at(addr-Mem_offset) = val;
}
inline void write_mem_i8(uint32_t addr, int8_t val) {
  Mem.at(addr-Mem_offset) = static_cast<uint8_t>(val);
}
inline void write_mem_u32(uint32_t addr, uint32_t val) {
  *reinterpret_cast<uint32_t*>(&Mem.at(addr-Mem_offset)) = val;
}
inline void write_mem_i32(uint32_t addr, int32_t val) {
  *reinterpret_cast<int32_t*>(&Mem.at(addr-Mem_offset)) = val;
}

//:: core interpreter loop

:(scenario add_imm32_to_eax)
# In scenarios, programs are a series of hex bytes, each (variable-length)
# instruction on one line.
#
# x86 instructions consist of the following parts (see cheatsheet.pdf):
#   opcode        ModR/M                    SIB                   displacement    immediate
#   instruction   mod, reg, Reg/Mem bits    scale, index, base
#   1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
    05                                                                            0a 0b 0c 0d  # add 0x0d0c0b0a to EAX
# All hex bytes must be exactly 2 characters each. No '0x' prefixes.
+load: 1 -> 05
+load: 2 -> 0a
+load: 3 -> 0b
+load: 4 -> 0c
+load: 5 -> 0d
+run: add imm32 0x0d0c0b0a to reg EAX
+run: storing 0x0d0c0b0a

:(code)
// helper for tests: load a program into memory from a textual representation
// of its bytes, and run it
void run(string text_bytes) {
  // Begin run() For Scenarios
//?   cerr << text_bytes << '\n';
  load_program(text_bytes);
  EIP = 1;  // preserve null pointer
  while (EIP < End_of_program)
    run_one_instruction();
}

// skeleton of how x86 instructions are decoded
void run_one_instruction() {
  uint8_t op=0, op2=0, op3=0;
  trace(2, "run") << "inst: 0x" << HEXWORD << EIP << end();
//?   cerr << "inst: 0x" << EIP << '\n';
  switch (op = next()) {
  case 0xf4:  // hlt
    EIP = End_of_program;
    break;
  // our first opcode
  case 0x05: {  // add imm32 to EAX
    int32_t arg2 = imm32();
    trace(2, "run") << "add imm32 0x" << HEXWORD << arg2 << " to reg EAX" << end();
    BINARY_ARITHMETIC_OP(+, Reg[EAX].i, arg2);
    break;
  }
  // End Single-Byte Opcodes
  case 0x0f:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With 0f
    default:
      cerr << "unrecognized second opcode after 0f: " << HEXBYTE << NUM(op2) << '\n';
      exit(1);
    }
    break;
  case 0xf3:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With f3
    case 0x0f:
      switch(op3 = next()) {
      // End Three-Byte Opcodes Starting With f3 0f
      default:
        cerr << "unrecognized third opcode after f3 0f: " << HEXBYTE << NUM(op3) << '\n';
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f3: " << HEXBYTE << NUM(op2) << '\n';
      exit(1);
    }
    break;
  default:
    cerr << "unrecognized opcode: " << HEXBYTE << NUM(op) << '\n';
    exit(1);
  }
}

void load_program(const string& text_bytes) {
  istringstream in(text_bytes);
  load_program(in);
}
void load_program(istream& in) {
  uint32_t addr = 1;  // preserve null pointer
  int segment_index = 0;
  while (has_data(in)) {
    string line_data;
    getline(in, line_data);
//?     cerr << "line: " << SIZE(line_data) << ": " << line_data << '\n';
    istringstream line(line_data);
    while (has_data(line)) {
      string word;
      line >> word;
      if (word.empty()) continue;
      if (word == "==") {
        // assume the first segment contains code
        if (segment_index == 1) End_of_program = addr;
        ++segment_index;
        // new segment
        line >> std::hex >> addr;
        break;  // skip rest of line
      }
      if (word[0] == ':') {
        // metadata
        break;
      }
      if (word[0] == '#') {
        // comment
        break;
      }
      // otherwise it's a hex byte
      uint32_t next_byte = 0;
      istringstream ss(word);
      ss >> std::hex >> next_byte;
      if (next_byte > 0xff) {
        raise << "invalid hex byte " << word << '\n' << end();
        return;
      }
      write_mem_u8(addr, static_cast<uint8_t>(next_byte));
      trace(99, "load") << addr << " -> " << HEXBYTE << NUM(read_mem_u8(addr)) << end();
//?       cerr << addr << " -> " << HEXBYTE << NUM(read_mem_u8(addr)) << '\n';
      addr++;
    }
  }
  // convenience: allow zero segment headers; code then starts at address 1
  if (segment_index == 0) End_of_program = addr;
}

inline uint8_t next() {
  return read_mem_u8(EIP++);
}

// read a 32-bit immediate in little-endian order from the instruction stream
int32_t imm32() {
  int32_t result = next();
  result |= (next()<<8);
  result |= (next()<<16);
  result |= (next()<<24);
  return result;
}

string rname(uint8_t r) {
  switch (r) {
  case 0: return "EAX";
  case 1: return "ECX";
  case 2: return "EDX";
  case 3: return "EBX";
  case 4: return "ESP";
  case 5: return "EBP";
  case 6: return "ESI";
  case 7: return "EDI";
  default: raise << "invalid register " << r << '\n' << end();  return "";
  }
}

:(before "End Includes")
#include <iomanip>
#define HEXBYTE  std::hex << std::setw(2) << std::setfill('0')
#define HEXWORD  std::hex << std::setw(8) << std::setfill('0')
// ugly that iostream doesn't print uint8_t as an integer
#define NUM(X) static_cast<int>(X)
#include <stdint.h>
