//: For convenience, make some common types shorter.
//:
//:   a) Rewrite '&t' to 'address:t' and '@t' to 'array:type' (with the
//:   ability to chain any combination of the two). This is not extensible.
//:
//:   b) Provide a facility to create new type names out of old ones.

//:: a) expanding '&' and '@'

:(scenarios load)
:(scenario abbreviations_for_address_and_array)
def main [
  f 1:&number  # abbreviation for 'address:number'
  f 2:@number  # abbreviation for 'array:number'
  f 3:&@number  # combining '&' and '@'
  f 4:&&@&@number  # ..any number of times
  f 5:array:&number:3  # abbreviations take precedence over ':'
  f {6: (array &number 3)}  # support for dilated reagents and more complex parse trees
  f 7:&&@&  # abbreviations without payload
  f 8:@number:3  # *not* the same as array:number:3
]
+parse:   ingredient: {1: ("address" "number")}
+parse:   ingredient: {2: ("array" "number")}
+parse:   ingredient: {3: ("address" "array" "number")}
+parse:   ingredient: {4: ("address" "address" "array" "address" "array" "number")}
+parse:   ingredient: {5: ("array" ("address" "number") "3")}
+parse:   ingredient: {6: ("array" ("address" "number") "3")}
# an error that will be raised elsewhere
+parse:   ingredient: {7: ("address" "address" "array" "address")}
# not what you want
+parse:   ingredient: {8: (("array" "number") "3")}

:(before "End Parsing Reagent Type Property(type_names)")
type_names = replace_address_and_array_symbols(type_names);
:(before "End Parsing Dilated Reagent Type Property(type_names)")
type_names = replace_address_and_array_symbols(type_names);

:(code)
// simple version; lots of unnecessary allocations; always creates a new pointer
string_tree* replace_address_and_array_symbols(string_tree*& orig) {
  if (orig == NULL) return NULL;
  string_tree* new_left = replace_address_and_array_symbols(orig->left);
  string_tree* new_right = replace_address_and_array_symbols(orig->right);
  if (orig->value.empty()) {
    delete orig;  orig = NULL;
    return new string_tree(new_left, new_right);
  }
  assert(new_left == NULL);
  new_left = replace_address_and_array_symbols(orig->value);
  assert(new_left);
  delete orig;  orig = NULL;
  append(new_left, new_right);
  return new_left;
}

// todo: unicode
string_tree* replace_address_and_array_symbols(const string& type_name) {
  if (type_name.empty()) return NULL;
  if (type_name.at(0) != '&' && type_name.at(0) != '@')
    return new string_tree(type_name);
  string_tree* result = NULL;
  string_tree* curr = NULL;
  int i = 0;
  while (i < SIZE(type_name)) {
    string_tree* new_node = NULL;
    if (type_name.at(i) == '&')
      new_node = new string_tree("address");
    else if (type_name.at(i) == '@')
      new_node = new string_tree("array");
    else
      break;
    if (!curr)
      result = curr = new_node;
    else
      curr->right = new_node, curr = curr->right;
    ++i;
  }
  if (i < SIZE(type_name))
    curr->right = new string_tree(type_name.substr(i));
  return result;
}

//:: b) extensible type abbreviations

:(before "End Globals")
map<string, type_tree*> Type_abbreviations;
