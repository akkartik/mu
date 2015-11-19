//: enable this when tracking down null types
//: (but it interferes with edit/; since recipes created in the environment
//: can raise warnings here which will stop running the entire environment)
//? :(before "End Transform All")
//? check_type_pointers();
//? 
//? :(code)
//? void check_type_pointers() {
//?   for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
//?     if (any_type_ingredient_in_header(p->first)) continue;
//?     const recipe& r = p->second;
//?     for (long long int i = 0; i < SIZE(r.steps); ++i) {
//?       const instruction& inst = r.steps.at(i);
//?       for (long long int j = 0; j < SIZE(inst.ingredients); ++j) {
//?         if (!inst.ingredients.at(j).type) {
//?           raise_error << maybe(r.name) << " '" << inst.to_string() << "' -- " << inst.ingredients.at(j).to_string() << " has no type\n" << end();
//?           return;
//?         }
//?         if (!inst.ingredients.at(j).properties.at(0).second) {
//?           raise_error << maybe(r.name) << " '" << inst.to_string() << "' -- " << inst.ingredients.at(j).to_string() << " has no type name\n" << end();
//?           return;
//?         }
//?       }
//?       for (long long int j = 0; j < SIZE(inst.products); ++j) {
//?         if (!inst.products.at(j).type) {
//?           raise_error << maybe(r.name) << " '" << inst.to_string() << "' -- " << inst.products.at(j).to_string() << " has no type\n" << end();
//?           return;
//?         }
//?         if (!inst.products.at(j).properties.at(0).second) {
//?           raise_error << maybe(r.name) << " '" << inst.to_string() << "' -- " << inst.products.at(j).to_string() << " has no type name\n" << end();
//?           return;
//?         }
//?       }
//?     }
//?   }
//? }
