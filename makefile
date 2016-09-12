# [0-9]*.cc -> mu.cc -> .build/*.cc -> .build/*.o -> .build/mu_bin
# (layers)   |        |              |             |
#          tangle  cleave          $CXX          $CXX
#
# [0-9]*.mu -> core.mu

all: mu_bin core.mu

CXX ?= c++
CXXFLAGS ?= -g -O3
CXXFLAGS := ${CXXFLAGS} -Wall -Wextra -ftrapv -fno-strict-aliasing

core.mu: [0-9]*.mu mu.cc makefile
	cat $$(./enumerate/enumerate --until zzz |grep '.mu$$') > core.mu

mu_bin: mu.cc makefile function_list test_list cleave/cleave
	@mkdir -p .build
	@cp function_list test_list .build
	@mkdir -p .build/termbox
	@cp termbox/termbox.h .build/termbox
	@# split mu.cc into separate compilation units under .build/ to speed up recompiles
	./cleave/cleave mu.cc .build
	@# recursive (potentially parallel) make to pick up BUILD_SRC after cleave
	@make .build/mu_bin
	cp .build/mu_bin .

BUILD_SRC=$(wildcard .build/*.cc)
.build/mu_bin: $(BUILD_SRC:.cc=.o) termbox/libtermbox.a
	${CXX} ${LDFLAGS} .build/*.o termbox/libtermbox.a -o .build/mu_bin

.build/%.o: .build/%.cc .build/header .build/global_declarations_list
	@# explicitly state default rule since we added dependencies
	${CXX} ${CXXFLAGS} -c $< -o $@

# To see what the program looks like after all layers have been applied, read
# mu.cc
mu.cc: [0-9]*.cc enumerate/enumerate tangle/tangle
	./tangle/tangle $$(./enumerate/enumerate --until zzz |grep -v '.mu$$') > mu.cc

enumerate/enumerate:
	cd enumerate && make

tangle/tangle:
	cd tangle && make && ./tangle test

cleave/cleave: cleave/cleave.cc
	cd cleave && make
	rm -rf .build

termbox/libtermbox.a: termbox/*.c termbox/*.h termbox/*.inl
	cd termbox && make

# auto-generated files; by convention they end in '_list'.

# auto-generated list of function declarations, so I can define them in any order
function_list: mu.cc
	@# functions start out unindented, have all args on the same line, and end in ') {'
	@#                                      ignore methods
	@grep -h "^[^[:space:]#].*) {$$" mu.cc |grep -v ":.*(" |perl -pwe 's/ \{.*/;/' > function_list
	@# occasionally we need to modify a declaration in a later layer without messing with ugly unbalanced brackets
	@# assume such functions move the '{' to column 0 of the very next line
	@grep -v "^#line" mu.cc |grep -B1 "^{" |grep -v "^{" |perl -pwe 's/$$/;/' >> function_list

# auto-generated list of tests to run
test_list: mu.cc
	@grep -h "^\s*void test_" mu.cc |perl -pwe 's/^\s*void (.*)\(\) \{.*/$$1,/' > test_list

# auto-generated list of extern declarations to global variables
# for separate compilation
.build/global_declarations_list: .build/global_definitions_list
	@grep ';' .build/global_definitions_list |perl -pwe 's/[=(].*/;/' |perl -pwe 's/^[^\/# ]/extern $$&/' |perl -pwe 's/^extern extern /extern /' > .build/global_declarations_list

.PHONY: all clean clena

clena: clean
clean:
	cd enumerate && make clean
	cd tangle && make clean
	cd cleave && make clean
	cd termbox && make clean
	-rm mu.cc core.mu mu_bin *_list
	-rm -rf mu_bin.*
	-rm -rf .build
