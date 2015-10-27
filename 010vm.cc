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
  recipe_ordinal operation;  // Recipe_ordinal[name]
  vector<reagent> ingredients;  // only if !is_label
  vector<reagent> products;  // only if !is_label
  // End instruction Fields
  instruction();
  void clear();
  string to_string() const;
};

:(before "struct instruction")
// Ingredients and products are a single species -- a reagent. Reagents refer
// either to numbers or to locations in memory along with 'type' tags telling
// us how to interpret them. They also can contain arbitrary other lists of
// properties besides types, but we're getting ahead of ourselves.
struct reagent {
  string original_string;
  vector<pair<string, string_tree*> > properties;
  string name;
  double value;
  bool initialized;
  type_tree* type;
  reagent(string s);
  reagent();
  ~reagent();
  reagent(const reagent& old);
  reagent& operator=(const reagent& old);
  void set_value(double v) { value = v; initialized = true; }
  string to_string() const;
};

:(before "struct reagent")
struct property {
  vector<string> values;
};

// Types can range from a simple type ordinal, to arbitrarily complex trees of
// type parameters, like (map (address array character) (list number))
struct type_tree {
  type_ordinal value;
  type_tree* left;
  type_tree* right;
  ~type_tree();
  type_tree(const type_tree& old);
  // simple: type ordinal
  explicit type_tree(type_ordinal v) :value(v), left(NULL), right(NULL) {}
  // intermediate: list of type ordinals
  type_tree(type_ordinal v, type_tree* r) :value(v), left(NULL), right(r) {}
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
  Type_ordinal["literal"] = 0;
  Next_type_ordinal = 1;
  // Mu Types Initialization
  type_ordinal number = Type_ordinal["number"] = Next_type_ordinal++;
  Type_ordinal["location"] = Type_ordinal["number"];  // wildcard type: either a pointer or a scalar
  Type[number].name = "number";
  type_ordinal address = Type_ordinal["address"] = Next_type_ordinal++;
  Type[address].name = "address";
  type_ordinal boolean = Type_ordinal["boolean"] = Next_type_ordinal++;
  Type[boolean].name = "boolean";
  type_ordinal character = Type_ordinal["character"] = Next_type_ordinal++;
  Type[character].name = "character";
  // Array types are a special modifier to any other type. For example,
  // array:number or array:address:boolean.
  type_ordinal array = Type_ordinal["array"] = Next_type_ordinal++;
  Type[array].name = "array";
  // End Mu Types Initialization
}
void teardown_types() {
  // todo: why can't I just Type.clear()?
  for (map<type_ordinal, type_info>::iterator p = Type.begin(); p != Type.end(); ++p) {
    if (!p->second.name.empty()) {
      for (long long int i = 0; i < SIZE(p->second.elements); ++i) {
        delete p->second.elements.at(i);
      }
    }
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
  primitive,
  container,
  exclusive_container
};

struct type_info {
  string name;
  kind_of_type kind;
  long long int size;  // only if type is not primitive; primitives and addresses have size 1 (except arrays are dynamic)
  vector<type_tree*> elements;
  vector<string> element_names;
  // End type_info Fields
  type_info() :kind(primitive), size(0) {}
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
  Recipe_ordinal["idle"] = IDLE;
  // Primitive Recipe Numbers
  Recipe_ordinal["copy"] = COPY;
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
Recipe_ordinal["main"] = Next_recipe_ordinal++;
// End Load Recipes
:(before "End Test Run Initialization")
assert(Next_recipe_ordinal < 1000);  // recipes being tested didn't overflow into test space
:(before "End Setup")
Next_recipe_ordinal = 1000;  // consistent new numbers for each test



//:: Helpers

:(code)
instruction::instruction() :is_label(false), operation(IDLE) {
  // End instruction Constructor
}
void instruction::clear() { is_label=false; label.clear(); operation=IDLE; ingredients.clear(); products.clear(); }

// Reagents have the form <name>:<type>:<type>:.../<property>/<property>/...
reagent::reagent(string s) :original_string(s), value(0), initialized(false), type(NULL) {
  // Parsing reagent(string s)
  istringstream in(s);
  in >> std::noskipws;
  // properties
  while (!in.eof()) {
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
    type = new type_tree(0);
    assert(!properties.at(0).second);
    properties.at(0).second = new string_tree("literal");
  }
  if (name == "_" && type == NULL) {
    type = new type_tree(0);
    assert(!properties.at(0).second);
    properties.at(0).second = new string_tree("dummy");
  }
  // End Parsing reagent
}

string_tree* parse_property_list(istream& in) {
  skip_whitespace(in);
  if (in.eof()) return NULL;
  string_tree* result = new string_tree(slurp_until(in, ':'));
  result->right = parse_property_list(in);
  return result;
}

type_tree* new_type_tree(const string_tree* properties) {
  if (!properties) return NULL;
  type_tree* result = new type_tree(0);
  if (!properties->value.empty()) {
    const string& type_name = properties->value;
    if (Type_ordinal.find(type_name) == Type_ordinal.end()
        // types can contain integers, like for array sizes
        && !is_integer(type_name)) {
      Type_ordinal[type_name] = Next_type_ordinal++;
    }
    result->value = Type_ordinal[type_name];
  }
  result->left = new_type_tree(properties->left);
  result->right = new_type_tree(properties->right);
  return result;
}

//: avoid memory leaks for the type tree

reagent::reagent(const reagent& old) :original_string(old.original_string), properties(old.properties), name(old.name), value(old.value), initialized(old.initialized) {
  properties.clear();
  for (long long int i = 0; i < SIZE(old.properties); ++i) {
    properties.push_back(pair<string, string_tree*>(old.properties.at(i).first,
                                                    old.properties.at(i).second ? new string_tree(*old.properties.at(i).second) : NULL));
  }
  type = old.type ? new type_tree(*old.type) : NULL;
}

type_tree::type_tree(const type_tree& old) :value(old.value) {
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
  for (long long int i = 0; i < SIZE(old.properties); ++i) {
    properties.push_back(pair<string, string_tree*>(old.properties.at(i).first, old.properties.at(i).second ? new string_tree(*old.properties.at(i).second) : NULL));
  }
  name = old.name;
  value = old.value;
  initialized = old.initialized;
  type = old.type ? new type_tree(*old.type) : NULL;
  return *this;
}

reagent::~reagent() {
  for (long long int i = 0; i < SIZE(properties); ++i) {
    if (properties.at(i).second) delete properties.at(i).second;
  }
  delete type;
}
type_tree::~type_tree() {
  delete left;
  delete right;
}
string_tree::~string_tree() {
  delete left;
  delete right;
}

reagent::reagent() :value(0), initialized(false), type(NULL) {
  // The first property is special, so ensure we always have it.
  // Other properties can be pushed back, but the first must always be
  // assigned to.
  properties.push_back(pair<string, string_tree*>("", NULL));
}

string reagent::to_string() const {
  ostringstream out;
  if (!properties.empty()) {
    out << "{";
    for (long long int i = 0; i < SIZE(properties); ++i) {
      if (i > 0) out << ", ";
      out << "\"" << properties.at(i).first << "\": ";
      dump_property(properties.at(i).second, out);
    }
    out << "}";
  }
  return out.str();
}

void dump_property(const string_tree* property, ostringstream& out) {
  if (!property) {
    out << "<>";
    return;
  }
  if (!property->left && !property->right) {
    out << '"' << property->value << '"';
    return;
  }
  out << "<";
  if (property->left)
    dump_property(property->left, out);
  else
    out << '"' << property->value << '"';
  out << " : ";
  if (property->right)
    dump_property(property->right, out);
  else
    out << " : <>";
  out << ">";
}

string dump_types(const reagent& x) {
  ostringstream out;
  dump_types(x.type, out);
  return out.str();
}

void dump_types(type_tree* type, ostringstream& out) {
  if (!type->left && !type->right) {
    out << Type[type->value].name;
    return;
  }
  out << "<";
  if (type->left)
    dump_types(type->left, out);
  else
    out << Type[type->value].name;
  out << " : ";
  if (type->right)
    dump_types(type->right, out);
  else
    out << " : <>";
  out << ">";
}

string instruction::to_string() const {
  if (is_label) return label;
  ostringstream out;
  for (long long int i = 0; i < SIZE(products); ++i) {
    if (i > 0) out << ", ";
    out << products.at(i).original_string;
  }
  if (!products.empty()) out << " <- ";
  out << name << ' ';
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (i > 0) out << ", ";
    out << ingredients.at(i).original_string;
  }
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

void dump_memory() {
  for (map<long long int, double>::iterator p = Memory.begin(); p != Memory.end(); ++p) {
    cout << p->first << ": " << no_scientific(p->second) << '\n';
  }
}

void dump_recipe(const string& recipe_name) {
  const recipe& r = Recipe[Recipe_ordinal[recipe_name]];
  cout << "recipe " << r.name << " [\n";
  for (long long int i = 0; i < SIZE(r.steps); ++i) {
    cout << "  " << r.steps.at(i).to_string() << '\n';
  }
  cout << "]\n";
}

void skip_whitespace(istream& in) {
  while (!in.eof() && isspace(in.peek()) && in.peek() != '\n') {
    in.get();
  }
}

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
