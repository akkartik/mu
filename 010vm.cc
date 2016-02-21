//: A program is a book of 'recipes' (functions)
:(before "End Globals")
//: Each recipe is stored at a specific page number, or ordinal.
map<recipe_ordinal, recipe> Recipe;
//: You can also refer to each recipe by its name.
map<string, recipe_ordinal> Recipe_ordinal;
recipe_ordinal Next_recipe_ordinal = 1;

//: Ordinals are like numbers, except you can't do arithmetic on them. Ordinal
//: 1 is not less than 2, it's just different. Phone numbers are ordinals;
//: adding two phone numbers is meaningless. Here each recipe does something
//: incommensurable with any other recipe.
:(after "Types")
typedef long long int recipe_ordinal;

:(before "End Types")
// Recipes are lists of instructions. To perform or 'run' a recipe, the
// computer runs its instructions.
struct recipe {
  string name;
  vector<instruction> steps;
  // End recipe Fields
  recipe();
};

:(before "struct recipe")
// Each instruction is either of the form:
//   product1, product2, product3, ... <- operation ingredient1, ingredient2, ingredient3, ...
// or just a single 'label' starting with a non-alphanumeric character
//   +label
// Labels don't do anything, they're just waypoints.
struct instruction {
  bool is_label;
  string label;  // only if is_label
  string name;  // only if !is_label
  string old_name;  // before our automatic rewrite rules
  string original_string;
  recipe_ordinal operation;  // get(Recipe_ordinal, name)
  vector<reagent> ingredients;  // only if !is_label
  vector<reagent> products;  // only if !is_label
  // End instruction Fields
  instruction();
  void clear();
  bool is_empty();
};

:(before "struct instruction")
// Ingredients and products are a single species -- a reagent. Reagents refer
// either to numbers or to locations in memory along with 'type' tags telling
// us how to interpret them. They also can contain arbitrary other lists of
// properties besides types, but we're getting ahead of ourselves.
struct reagent {
  string original_string;
  string name;
  type_tree* type;
  vector<pair<string, string_tree*> > properties;
  double value;
  bool initialized;
  reagent(string s);
  reagent();
  ~reagent();
  void clear();
  reagent(const reagent& old);
  reagent& operator=(const reagent& old);
  void set_value(double v) { value = v; initialized = true; }
};

:(before "struct reagent")
struct property {
  vector<string> values;
};

// Types can range from a simple type ordinal, to arbitrarily complex trees of
// type parameters, like (map (address array character) (list number))
struct type_tree {
  string name;
  type_ordinal value;
  type_tree* left;
  type_tree* right;
  ~type_tree();
  type_tree(const type_tree& old);
  // simple: type ordinal
  explicit type_tree(string name, type_ordinal v) :name(name), value(v), left(NULL), right(NULL) {}
  // intermediate: list of type ordinals
  type_tree(string name, type_ordinal v, type_tree* r) :name(name), value(v), left(NULL), right(r) {}
  // advanced: tree containing type ordinals
  type_tree(type_tree* l, type_tree* r) :value(0), left(l), right(r) {}
};

struct string_tree {
  string value;
  string_tree* left;
  string_tree* right;
  ~string_tree();
  string_tree(const string_tree& old);
  // simple: flat string
  explicit string_tree(string v) :value(v), left(NULL), right(NULL) {}
  // intermediate: list of strings
  string_tree(string v, string_tree* r) :value(v), left(NULL), right(r) {}
  // advanced: tree containing strings
  string_tree(string_tree* l, string_tree* r) :left(l), right(r) {}
};

:(before "End Globals")
// Locations refer to a common 'memory'. Each location can store a number.
map<long long int, double> Memory;
:(before "End Setup")
Memory.clear();

:(after "Types")
// Mu types encode how the numbers stored in different parts of memory are
// interpreted. A location tagged as a 'character' type will interpret the
// value 97 as the letter 'a', while a different location of type 'number'
// would not.
//
// Unlike most computers today, mu stores types in a single big table, shared
// by all the mu programs on the computer. This is useful in providing a
// seamless experience to help understand arbitrary mu programs.
typedef long long int type_ordinal;
:(before "End Globals")
map<string, type_ordinal> Type_ordinal;
map<type_ordinal, type_info> Type;
type_ordinal Next_type_ordinal = 1;
:(code)
void setup_types() {
  Type.clear();  Type_ordinal.clear();
  put(Type_ordinal, "literal", 0);
  Next_type_ordinal = 1;
  // Mu Types Initialization
  type_ordinal number = put(Type_ordinal, "number", Next_type_ordinal++);
  put(Type_ordinal, "location", get(Type_ordinal, "number"));  // wildcard type: either a pointer or a scalar
  get_or_insert(Type, number).name = "number";
  type_ordinal address = put(Type_ordinal, "address", Next_type_ordinal++);
  get_or_insert(Type, address).name = "address";
  type_ordinal boolean = put(Type_ordinal, "boolean", Next_type_ordinal++);
  get_or_insert(Type, boolean).name = "boolean";
  type_ordinal character = put(Type_ordinal, "character", Next_type_ordinal++);
  get_or_insert(Type, character).name = "character";
  // Array types are a special modifier to any other type. For example,
  // array:number or array:address:boolean.
  type_ordinal array = put(Type_ordinal, "array", Next_type_ordinal++);
  get_or_insert(Type, array).name = "array";
  // End Mu Types Initialization
}
void teardown_types() {
  for (map<type_ordinal, type_info>::iterator p = Type.begin(); p != Type.end(); ++p) {
    for (long long int i = 0; i < SIZE(p->second.elements); ++i)
      p->second.elements.clear();
  }
  Type_ordinal.clear();
}
:(before "End One-time Setup")
setup_types();
atexit(teardown_types);

:(before "End Types")
// You can construct arbitrary new types. New types are either 'containers'
// with multiple 'elements' of other types, or 'exclusive containers' containing
// one of multiple 'variants'. (These are similar to C structs and unions,
// respectively, though exclusive containers implicitly include a tag element
// recording which variant they should be interpreted as.)
//
// For example, storing bank balance and name for an account might require a
// container, but if bank accounts may be either for individuals or groups,
// with different properties for each, that may require an exclusive container
// whose variants are individual-account and joint-account containers.
enum kind_of_type {
  PRIMITIVE,
  CONTAINER,
  EXCLUSIVE_CONTAINER
};

struct type_info {
  string name;
  kind_of_type kind;
  long long int size;  // only if type is not primitive; primitives and addresses have size 1 (except arrays are dynamic)
  vector<reagent> elements;
  // End type_info Fields
  type_info() :kind(PRIMITIVE), size(0) {}
};

enum primitive_recipes {
  IDLE = 0,
  COPY,
  // End Primitive Recipe Declarations
  MAX_PRIMITIVE_RECIPES,
};
:(code)
//: It's all very well to construct recipes out of other recipes, but we need
//: to know how to do *something* out of the box. For the following
//: recipes there are only codes, no entries in the book, because mu just knows
//: what to do for them.
void setup_recipes() {
  Recipe.clear();  Recipe_ordinal.clear();
  put(Recipe_ordinal, "idle", IDLE);
  // Primitive Recipe Numbers
  put(Recipe_ordinal, "copy", COPY);
  // End Primitive Recipe Numbers
}
//: We could just reset the recipe table after every test, but that gets slow
//: all too quickly. Instead, initialize the common stuff just once at
//: startup. Later layers will carefully undo each test's additions after
//: itself.
:(before "End One-time Setup")
setup_recipes();
assert(MAX_PRIMITIVE_RECIPES < 200);  // level 0 is primitives; until 199
Next_recipe_ordinal = 200;
put(Recipe_ordinal, "main", Next_recipe_ordinal++);
// End Load Recipes
:(before "End Test Run Initialization")
assert(Next_recipe_ordinal < 1000);  // recipes being tested didn't overflow into test space
:(before "End Setup")
Next_recipe_ordinal = 1000;  // consistent new numbers for each test



//:: Helpers

:(code)
recipe::recipe() {
  // End recipe Constructor
}

instruction::instruction() :is_label(false), operation(IDLE) {
  // End instruction Constructor
}
void instruction::clear() { is_label=false; label.clear(); name.clear(); old_name.clear(); operation=IDLE; ingredients.clear(); products.clear(); original_string.clear(); }
bool instruction::is_empty() { return !is_label && name.empty(); }

// Reagents have the form <name>:<type>:<type>:.../<property>/<property>/...
reagent::reagent(string s) :original_string(s), type(NULL), value(0), initialized(false) {
  // Parsing reagent(string s)
  istringstream in(s);
  in >> std::noskipws;
  // properties
  while (has_data(in)) {
    istringstream row(slurp_until(in, '/'));
    row >> std::noskipws;
    string key = slurp_until(row, ':');
    string_tree* value = parse_property_list(row);
    properties.push_back(pair<string, string_tree*>(key, value));
  }
  // structures for the first row of properties: name and list of types
  name = properties.at(0).first;
  type = new_type_tree(properties.at(0).second);
  if (is_integer(name) && type == NULL) {
    assert(!properties.at(0).second);
    properties.at(0).second = new string_tree("literal");
    type = new type_tree("literal", get(Type_ordinal, "literal"));
  }
  if (name == "_" && type == NULL) {
    assert(!properties.at(0).second);
    properties.at(0).second = new string_tree("dummy");
    type = new type_tree("literal", get(Type_ordinal, "literal"));
  }
  // End Parsing reagent
}

string_tree* parse_property_list(istream& in) {
  skip_whitespace_but_not_newline(in);
  if (!has_data(in)) return NULL;
  string_tree* result = new string_tree(slurp_until(in, ':'));
  result->right = parse_property_list(in);
  return result;
}

// TODO: delete
type_tree* new_type_tree(const string_tree* properties) {
  if (!properties) return NULL;
  type_tree* result = new type_tree("", 0);
  if (!properties->value.empty()) {
    const string& type_name = result->name = properties->value;
    if (contains_key(Type_ordinal, type_name))
      result->value = get(Type_ordinal, type_name);
    else if (is_integer(type_name))  // sometimes types will contain non-type tags, like numbers for the size of an array
      result->value = 0;
    else if (properties->value != "->")  // used in recipe types
      result->value = -1;  // should never happen; will trigger errors later
  }
  result->left = new_type_tree(properties->left);
  result->right = new_type_tree(properties->right);
  return result;
}

//: avoid memory leaks for the type tree

reagent::reagent(const reagent& old) {
  original_string = old.original_string;
  name = old.name;
  value = old.value;
  initialized = old.initialized;
  properties.clear();
  for (long long int i = 0; i < SIZE(old.properties); ++i) {
    properties.push_back(pair<string, string_tree*>(old.properties.at(i).first,
                                                    old.properties.at(i).second ? new string_tree(*old.properties.at(i).second) : NULL));
  }
  type = old.type ? new type_tree(*old.type) : NULL;
}

type_tree::type_tree(const type_tree& old) {
  name = old.name;
  value = old.value;
  left = old.left ? new type_tree(*old.left) : NULL;
  right = old.right ? new type_tree(*old.right) : NULL;
}

string_tree::string_tree(const string_tree& old) {  // :value(old.value) {
  value = old.value;
  left = old.left ? new string_tree(*old.left) : NULL;
  right = old.right ? new string_tree(*old.right) : NULL;
}

reagent& reagent::operator=(const reagent& old) {
  original_string = old.original_string;
  properties.clear();
  for (long long int i = 0; i < SIZE(old.properties); ++i)
    properties.push_back(pair<string, string_tree*>(old.properties.at(i).first, old.properties.at(i).second ? new string_tree(*old.properties.at(i).second) : NULL));
  name = old.name;
  value = old.value;
  initialized = old.initialized;
  type = old.type ? new type_tree(*old.type) : NULL;
  return *this;
}

reagent::~reagent() {
  clear();
}

void reagent::clear() {
  for (long long int i = 0; i < SIZE(properties); ++i) {
    if (properties.at(i).second) {
      delete properties.at(i).second;
      properties.at(i).second = NULL;
    }
  }
  delete type;
  type = NULL;
}
type_tree::~type_tree() {
  delete left;
  delete right;
}
string_tree::~string_tree() {
  delete left;
  delete right;
}

reagent::reagent() :type(NULL), value(0), initialized(false) {
  // The first property is special, so ensure we always have it.
  // Other properties can be pushed back, but the first must always be
  // assigned to.
  properties.push_back(pair<string, string_tree*>("", NULL));
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

bool has_property(reagent x, string name) {
  for (long long int i = /*skip name:type*/1; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == name) return true;
  }
  return false;
}

string_tree* property(const reagent& r, const string& name) {
  for (long long int p = /*skip name:type*/1; p != SIZE(r.properties); ++p) {
    if (r.properties.at(p).first == name)
      return r.properties.at(p).second;
  }
  return NULL;
}

:(before "End Globals")
const string Ignore(",");  // commas are ignored in mu except within [] strings
:(code)
void skip_whitespace_but_not_newline(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    else if (in.peek() == '\n') break;
    else if (isspace(in.peek())) in.get();
    else if (Ignore.find(in.peek()) != string::npos) in.get();
    else break;
  }
}

void dump_memory() {
  for (map<long long int, double>::iterator p = Memory.begin(); p != Memory.end(); ++p) {
    cout << p->first << ": " << no_scientific(p->second) << '\n';
  }
}

//:: Helpers for converting various values to string
//: Use to_string() in trace(), and try to avoid relying on unstable codes that
//: will perturb .traces/ from commit to commit.
//: Use debug_string() while debugging, and throw everything into it.
//: Use inspect() only for emitting a canonical format that can be parsed back
//: into the value.

string to_string(const recipe& r) {
  ostringstream out;
  out << "recipe " << r.name << " [\n";
  for (long long int i = 0; i < SIZE(r.steps); ++i)
    out << "  " << to_string(r.steps.at(i)) << '\n';
  out << "]\n";
  return out.str();
}

string debug_string(const recipe& x) {
  ostringstream out;
  out << "- recipe " << x.name << '\n';
  // Begin debug_string(recipe x)
  for (long long int index = 0; index < SIZE(x.steps); ++index) {
    const instruction& inst = x.steps.at(index);
    out << "inst: " << to_string(inst) << '\n';
    out << "  ingredients\n";
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i)
      out << "    " << debug_string(inst.ingredients.at(i)) << '\n';
    out << "  products\n";
    for (long long int i = 0; i < SIZE(inst.products); ++i)
      out << "    " << debug_string(inst.products.at(i)) << '\n';
  }
  return out.str();
}

string to_string(const instruction& inst) {
  if (inst.is_label) return inst.label;
  ostringstream out;
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (i > 0) out << ", ";
    out << inst.products.at(i).original_string;
  }
  if (!inst.products.empty()) out << " <- ";
  out << inst.name << ' ';
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (i > 0) out << ", ";
    out << inst.ingredients.at(i).original_string;
  }
  return out.str();
}

string to_string(const reagent& r) {
  ostringstream out;
  if (!r.properties.empty()) {
    out << "{";
    for (long long int i = 0; i < SIZE(r.properties); ++i) {
      if (i > 0) out << ", ";
      out << "\"" << r.properties.at(i).first << "\": " << to_string(r.properties.at(i).second);
    }
    out << "}";
  }
  return out.str();
}

string debug_string(const reagent& x) {
  ostringstream out;
  out << x.name << ": " << x.value << ' ' << to_string(x.type) << " -- " << to_string(x);
  return out.str();
}

string to_string(const string_tree* property) {
  if (!property) return "()";
  ostringstream out;
  if (!property->left && !property->right)
    // abbreviate a single-node tree to just its contents
    out << '"' << property->value << '"';
  else
    dump(property, out);
  return out.str();
}

void dump(const string_tree* x, ostream& out) {
  if (!x->left && !x->right) {
    out << x->value;
    return;
  }
  out << '(';
  for (const string_tree* curr = x; curr; curr = curr->right) {
    if (curr != x) out << ' ';
    if (curr->left)
      dump(curr->left, out);
    else
      out << '"' << curr->value << '"';
  }
  out << ')';
}

string to_string(const type_tree* type) {
  // abbreviate a single-node tree to just its contents
  if (!type) return "NULLNULLNULL";  // should never happen
  ostringstream out;
  if (!type->left && !type->right)
    dump(type->value, out);
  else
    dump(type, out);
  return out.str();
}

void dump(const type_tree* type, ostream& out) {
  out << "<";
  if (type->left)
    dump(type->left, out);
  else
    dump(type->value, out);
  out << " : ";
  if (type->right)
    dump(type->right, out);
  else
    out << "<>";
  out << ">";
}

void dump(type_ordinal type, ostream& out) {
  if (contains_key(Type, type))
    out << get(Type, type).name;
  else
    out << "?" << type;
}

//: helper to print numbers without excessive precision

:(before "End Types")
struct no_scientific {
  double x;
  explicit no_scientific(double y) :x(y) {}
};

:(code)
ostream& operator<<(ostream& os, no_scientific x) {
  if (!isfinite(x.x)) {
    // Infinity or NaN
    os << x.x;
    return os;
  }
  ostringstream tmp;
  tmp << std::fixed << x.x;
  os << trim_floating_point(tmp.str());
  return os;
}

string trim_floating_point(const string& in) {
  if (in.empty()) return "";
  long long int len = SIZE(in);
  while (len > 1) {
    if (in.at(len-1) != '0') break;
    --len;
  }
  if (in.at(len-1) == '.') --len;
//?   cerr << in << ": " << in.substr(0, len) << '\n';
  return in.substr(0, len);
}

void test_trim_floating_point() {
  CHECK_EQ("", trim_floating_point(""));
  CHECK_EQ("0", trim_floating_point("000000000"));
  CHECK_EQ("1.5", trim_floating_point("1.5000"));
  CHECK_EQ("1.000001", trim_floating_point("1.000001"));
  CHECK_EQ("23", trim_floating_point("23.000000"));
  CHECK_EQ("23", trim_floating_point("23.0"));
  CHECK_EQ("23", trim_floating_point("23."));
  CHECK_EQ("23", trim_floating_point("23"));
  CHECK_EQ("3", trim_floating_point("3.000000"));
  CHECK_EQ("3", trim_floating_point("3.0"));
  CHECK_EQ("3", trim_floating_point("3."));
  CHECK_EQ("3", trim_floating_point("3"));
}

:(before "End Includes")
#include<utility>
using std::pair;
#include<math.h>
