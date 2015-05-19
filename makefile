mu: makefile enumerate/enumerate tangle/tangle mu.cc termbox/libtermbox.a autogenerated_lists
	g++ -g -Wall -Wextra -fno-strict-aliasing mu.cc termbox/libtermbox.a -o mu

# To see what the program looks like after all layers have been applied, read
# mu.cc
mu.cc: 0*
	./tangle/tangle $$(./enumerate/enumerate --until 9999 |grep -v '.mu$$') > mu.cc
	cat $$(./enumerate/enumerate --until 9999 |grep '.mu$$') > core.mu

enumerate/enumerate:
	cd enumerate && make && ./enumerate test

tangle/tangle:
	cd tangle && make && ./tangle test

termbox/libtermbox.a:
	cd termbox && make

.PHONY: autogenerated_lists test valgrind clena

test: mu
	./mu test

valgrind: mu
	valgrind --leak-check=yes -q --error-exitcode=1 ./mu test

# auto-generated files; by convention they end in '_list'.
autogenerated_lists: mu.cc function_list test_list

# autogenerated list of function declarations, so I can define them in any order
function_list: mu.cc
	@# functions start out unindented, have all args on the same line, and end in ') {'
	@#                                    ignore methods
	@grep -h "^[^[:space:]#].*) {" mu.cc |grep -v ":.*(" |perl -pwe 's/ {.*/;/' > function_list
	@# occasionally we need to modify a declaration in a later layer without messing with ugly unbalanced brackets
	@# assume such functions move the '{' to column 0 of the very next line
	@grep -v "^#line" mu.cc |grep -B1 "^{" |grep -v "^{" |perl -pwe 's/$$/;/' >> function_list
	@# test functions
	@grep -h "^\s*TEST(" mu.cc |perl -pwe 's/^\s*TEST\((.*)\)$$/void test_$$1();/' >> function_list

# autogenerated list of tests to run
test_list: mu.cc
	@grep -h "^\s*void test_" mu.cc |perl -pwe 's/^\s*void (.*)\(\) {.*/$$1,/' > test_list
	@grep -h "^\s*TEST(" mu.cc |perl -pwe 's/^\s*TEST\((.*)\)$$/test_$$1,/' >> test_list

clena: clean
clean:
	cd enumerate && make clean
	cd tangle && make clean
	cd termbox && make clean
	-rm mu.cc core.mu mu *_list
