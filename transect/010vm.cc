//: type definitions start with either 'record' or 'choice'

:(before "End Types")
typedef int type_id;
:(before "End Globals")
map</*name*/string, type_id> Type_id;
map<type_id, type_info> Type_info;
type_id Next_type_id = 1;
// primitive types
type_id Literal_type_id = 0, Int_type_id = 0, Byte_type_id = 0, Address_type_id = 0, Array_type_id = 0, Ref_type_id = 0;
:(before "End Types")
struct type_info {
  type_id id;
  string name;
  kind_of_type kind;
  int size;  // in bytes
  vector<type_declaration> elements;
  type_info() :kind(PRIMITIVE), size(0) {}
};
:(before "struct type_info")
enum kind_of_type {
  PRIMITIVE,
  RECORD,
  CHOICE,
};
struct type_declaration {
  string name;
  vector<type_id> type;
};

//: global definitions start with 'var'

:(before "End Types")
typedef int global_id;
:(before "End Globals")
map</*name*/string, global_id> Global_id;
map<global_id, global_info> Global_info;
global_id Next_global_id = 1;
:(before "End Types")
struct global_info {
  global_id id;
  vector<type_id> type;
  int address;
  global_info() :address(0) {}
};

//: function definitions start with 'fn'

:(before "End Types")
typedef int function_id;
:(before "End Globals")
map</*name*/string, function_id> Function_id;
map<function_id, function_info> Function_info;
function_id Next_function_id = 1;
:(before "End Types")
struct function_info {
  function_id id;
  string name;
  vector<operand> in;
  vector<operand> in_out;
  vector<instruction> instructions;
  map</*local variable name*/string, int> stack_offset;
  function_info() :id(0) {}
};
:(before "struct function_info")
// operands have form name/property1/property2/... : (type1 type2 ...)
struct operand {
  string name;
  vector<type_id> type;
  vector<string> properties;
  operand(string);
  void set_type(istream&);
};

struct instruction {
  function_id id;
  string name;
  vector<operand> in;
  vector<operand> in_out;
};
:(code)
operand::operand(string s) {
  istringstream in(s);
  name = slurp_until(in, '/');
  while (has_data(in))
    properties.push_back(slurp_until(in, '/'));
}

// extremely hacky; assumes a single-level list of words in parens, with no nesting
void operand::set_type(istream& in) {
  assert(has_data(in));
  string curr;
  in >> curr;
//?   cerr << "2: " << curr << '\n';
  if (curr.at(0) != '(') {
    type.push_back(get(Type_id, curr));
    return;
  }
  curr = curr.substr(/*skip '('*/1);
  while (!ends_with(curr, ")")) {
    if (curr.empty()) continue;
    assert(curr.at(0) != '(');
    type.push_back(get(Type_id, curr));
    // update
    assert(has_data(in));
    in >> curr;
  }
  assert(ends_with(curr, ")"));
  curr = curr.substr(0, SIZE(curr)-1);
  if (!curr.empty()) {
    /*'(' or ')' isn't a token by itself*/
    type.push_back(get(Type_id, curr));
  }
}

string to_string(const operand& o) {
  ostringstream out;
  out << o.name;
  if (o.type.empty()) return out.str();
  out << " : ";
  if (SIZE(o.type) == 1) {
    out << get(Type_info, o.type.at(0)).name;
    return out.str();
  }
  out << "(";
  for (int i = 0;  i < SIZE(o.type);  ++i) {
    if (i > 0) out << ", ";
    out << get(Type_info, o.type.at(i)).name;
  }
  out << ")";
  return out.str();
}

string slurp_until(istream& in, char delim) {
  ostringstream out;
  char c;
  while (in >> c) {
    if (c == delim) {
      // drop the delim
      break;
    }
    out << c;
  }
  return out.str();
}

bool ends_with(const string& s, const string& pat) {
  for (string::const_reverse_iterator p = s.rbegin(), q = pat.rbegin();  q != pat.rend();  ++p, ++q) {
    if (p == s.rend()) return false;  // pat too long
    if (*p != *q) return false;
  }
  return true;
}

:(before "End One-time Setup")
init_primitive_types();
:(code)
void init_primitive_types() {
  Literal_type_id = new_type("literal", PRIMITIVE, 0);
  Int_type_id = new_type("int", PRIMITIVE, 4);
  Byte_type_id = new_type("byte", PRIMITIVE, 1);
  Address_type_id = new_type("address", PRIMITIVE, 4);
  Array_type_id = new_type("array", PRIMITIVE, 0);  // size will depend on length
  Ref_type_id = new_type("ref", PRIMITIVE, 8);  // address + alloc id
}

type_id new_type(string name, kind_of_type kind, int size) {
  assert(!contains_key(Type_id, name));
  int result = Next_type_id++;
  put(Type_id, name, result);
  assert(!contains_key(Type_info, result));
  type_info& curr = Type_info[result];  // insert
  curr.id = result;
  curr.name = name;
  curr.kind = kind;
  curr.size = size;
  return result;
}

//: Start each test by undoing the previous test's types, globals and functions

:(before "End One-time Setup")
save_snapshots();
:(before "End Reset")
restore_snapshots();

:(before "End Globals")
map<string, type_id> Type_id_snapshot;
map<type_id, type_info> Type_info_snapshot;
type_id Next_type_id_snapshot = 0;

map<string, global_id> Global_id_snapshot;
map<global_id, global_info> Global_info_snapshot;
global_id Next_global_id_snapshot = 0;

map<string, function_id> Function_id_snapshot;
map<function_id, function_info> Function_info_snapshot;
function_id Next_function_id_snapshot = 0;
:(code)
void save_snapshots() {
  Type_id_snapshot = Type_id;
  Type_info_snapshot = Type_info;
  Next_type_id_snapshot = Next_type_id;

  Global_id_snapshot = Global_id;
  Global_info_snapshot = Global_info;
  Next_global_id_snapshot = Next_global_id;

  Function_id_snapshot = Function_id;
  Function_info_snapshot = Function_info;
  Next_function_id_snapshot = Next_function_id;
}

void restore_snapshots() {
  Type_id = Type_id_snapshot;
  Type_info = Type_info_snapshot;
  Next_type_id = Next_type_id_snapshot;

  Global_id = Global_id_snapshot;
  Global_info = Global_info_snapshot;
  Next_global_id = Next_global_id_snapshot;

  Function_id = Function_id_snapshot;
  Function_info = Function_info_snapshot;
  Next_function_id = Next_function_id_snapshot;
}

:(before "End Includes")
#include <map>
using std::map;
