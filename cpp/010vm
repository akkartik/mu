:(after "Types")
// A program is a book of 'recipes' (functions)
typedef int recipe_number;
:(before "End Globals")
map<string, recipe_number> Recipe_number;
map<recipe_number, recipe> Recipe;
int Next_recipe_number = 1;

:(before "End Types")
// Recipes are lists of instructions. To run a recipe, the computer runs its
// instructions.
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
  recipe_number operation;  // Recipe_number[name]
  vector<reagent> ingredients;  // only if !is_label
  vector<reagent> products;  // only if !is_label
  instruction();
  void clear();
};

:(before "struct instruction")
// Ingredients and products are a single species -- a reagent. Reagents refer
// either to numbers or to locations in memory along with 'type' tags telling
// us how to interpret them. They also can contain arbitrary other lists of
// properties besides types, but we're getting ahead of ourselves.
struct reagent {
  vector<pair<string, vector<string> > > properties;
  string name;
  int value;
  bool initialized;
  vector<type_number> types;
  reagent(string s);
  reagent();
  void set_value(int v) { value = v; initialized = true; }
  string to_string() const;
};

:(before "struct reagent")
struct property {
  vector<string> values;
};

:(before "End Globals")
// Locations refer to a common 'memory'. Each location can store a number.
map<int, int> Memory;
:(before "End Setup")
Memory.clear();

:(after "Types")
// Mu types encode how the numbers stored in different parts of memory are
// interpreted. A location tagged as a 'character' type will interpret the
// number 97 as the letter 'a', while a different location of type 'integer'
// would not.
//
// Unlike most computers today, mu stores types in a single big table, shared
// by all the mu programs on the computer. This is useful in providing a
// seamless experience to help understand arbitrary mu programs.
typedef int type_number;
:(before "End Globals")
map<string, type_number> Type_number;
map<type_number, type_info> Type;
int Next_type_number = 1;
:(code)
void setup_types() {
  Type.clear();  Type_number.clear();
  Type_number["literal"] = 0;
  Next_type_number = 1;
  // Mu Types Initialization
  int integer = Type_number["integer"] = Next_type_number++;
  Type_number["location"] = Type_number["integer"];  // wildcard type
  Type[integer].name = "integer";
  int address = Type_number["address"] = Next_type_number++;
  Type[address].name = "address";
  int boolean = Type_number["boolean"] = Next_type_number++;
  Type[boolean].name = "boolean";
  int character = Type_number["character"] = Next_type_number++;
  Type[character].name = "character";
  // Array types are a special modifier to any other type. For example,
  // array:integer or array:address:boolean.
  int array = Type_number["array"] = Next_type_number++;
  Type[array].name = "array";
  // End Mu Types Initialization
}
:(before "End One-time Setup")
setup_types();

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
  size_t size;  // only if type is not primitive; primitives and addresses have size 1 (except arrays are dynamic)
  vector<vector<type_number> > elements;
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
  Recipe.clear();  Recipe_number.clear();
  Recipe_number["idle"] = IDLE;
  // Primitive Recipe Numbers
  Recipe_number["copy"] = COPY;
  // End Primitive Recipe Numbers
}
//: We could just reset the recipe table after every test, but that gets slow
//: all too quickly. Instead, initialize the common stuff just once at
//: startup. Later layers will carefully undo each test's additions after
//: itself.
:(before "End One-time Setup")
setup_recipes();
assert(MAX_PRIMITIVE_RECIPES < 100);  // level 0 is primitives; until 99
Next_recipe_number = 100;
// End Load Recipes
:(before "End Test Run Initialization")
assert(Next_recipe_number < 1000);  // functions being tested didn't overflow into test space
:(before "End Setup")
Next_recipe_number = 1000;  // consistent new numbers for each test



//:: Helpers

:(code)
instruction::instruction() :is_label(false), operation(IDLE) {}
void instruction::clear() { is_label=false; label.clear(); operation=IDLE; ingredients.clear(); products.clear(); }

// Reagents have the form <name>:<type>:<type>:.../<property>/<property>/...
reagent::reagent(string s) :value(0), initialized(false) {
  istringstream in(s);
  in >> std::noskipws;
  // properties
  while (!in.eof()) {
    istringstream row(slurp_until(in, '/'));
    row >> std::noskipws;
    string name = slurp_until(row, ':');
    vector<string> values;
    while (!row.eof())
      values.push_back(slurp_until(row, ':'));
    properties.push_back(pair<string, vector<string> >(name, values));
  }
  // structures for the first row of properties
  name = properties[0].first;
  for (size_t i = 0; i < properties[0].second.size(); ++i) {
    types.push_back(Type_number[properties[0].second[i]]);
  }
  if (name == "_" && types.empty()) {
    types.push_back(0);
    properties[0].second.push_back("dummy");
  }
}
reagent::reagent() :value(0), initialized(false) {
  // The first property is special, so ensure we always have it.
  // Other properties can be pushed back, but the first must always be
  // assigned to.
  properties.push_back(pair<string, vector<string> >("", vector<string>()));
}
string reagent::to_string() const {
  ostringstream out;
  out << "{name: \"" << name << "\", value: " << value << ", type: ";
  for (size_t i = 0; i < types.size(); ++i) {
    out << types[i];
    if (i < types.size()-1) out << "-";
  }
  if (!properties.empty()) {
    out << ", properties: [";
    for (size_t i = 0; i < properties.size(); ++i) {
      out << "\"" << properties[i].first << "\": ";
      for (size_t j = 0; j < properties[i].second.size(); ++j) {
        out << "\"" << properties[i].second[j] << "\"";
        if (j < properties[i].second.size()-1) out << ":";
      }
      if (i < properties.size()-1) out << ", ";
      else out << "]";
    }
  }
  out << "}";
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

void dump_memory() {
  map<int, int> ordered(Memory.begin(), Memory.end());
  for (map<int, int>::iterator p = ordered.begin(); p != ordered.end(); ++p) {
    cout << p->first << ": " << p->second << '\n';
  }
}
:(before "End Includes")
#include <map>
using std::map;
