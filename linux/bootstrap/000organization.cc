//: You guessed right: the '000' prefix means you should start reading here.
//:
//: This project is set up to load all files with a numeric prefix. Just
//: create a new file and start hacking.
//:
//: The first few files (00*) are independent of what this program does, an
//: experimental skeleton that will hopefully make it both easier for others to
//: understand and more malleable, easier to rewrite and remould into radically
//: different shapes without breaking in subtle corner cases. The premise is
//: that understandability and rewrite-friendliness are related in a virtuous
//: cycle. Doing one well makes it easier to do the other.
//:
//: Lower down, this file contains a legal, bare-bones C++ program. It doesn't
//: do anything yet; subsequent files will contain :(...) directives to insert
//: lines into it. For example:
//:   :(after "more events")
//: This directive means: insert the following lines after a line in the
//: program containing the words "more events".
//:
//: A simple tool is included to 'tangle' all the files together in sequence
//: according to their directives into a single source file containing all the
//: code for the project, and then feed the source file to the compiler.
//: (It'll drop these comments starting with a '//:' prefix that only make
//: sense before tangling.)
//:
//: Directives free up the programmer to order code for others to read rather
//: than as forced by the computer or compiler. Each individual feature can be
//: organized in a self-contained 'layer' that adds code to many different data
//: structures and functions all over the program. The right decomposition into
//: layers will let each layer make sense in isolation.
//:
//:   "If I look at any small part of it, I can see what is going on -- I don't
//:   need to refer to other parts to understand what something is doing.
//:
//:   If I look at any large part in overview, I can see what is going on -- I
//:   don't need to know all the details to get it.
//:
//:   Every level of detail is as locally coherent and as well thought-out as
//:   any other level."
//:
//:       -- Richard Gabriel, "The Quality Without A Name"
//:          (http://dreamsongs.com/Files/PatternsOfSoftware.pdf, page 42)
//:
//: Directives are powerful; they permit inserting or modifying any point in
//: the program. Using them tastefully requires mapping out specific lines as
//: waypoints for future layers to hook into. Often such waypoints will be in
//: comments, capitalized to hint that other layers rely on their presence.
//:
//: A single waypoint might have many different code fragments hooking into
//: it from all over the codebase. Use 'before' directives to insert
//: code at a location in order, top to bottom, and 'after' directives to
//: insert code in reverse order. By convention waypoints intended for insertion
//: before begin with 'End'. Notice below how the layers line up above the "End
//: Foo" waypoint.
//:
//:   File 001          File 002                File 003
//:   ============      ===================     ===================
//:   // Foo
//:   ------------
//:              <----  :(before "End Foo")
//:                     ....
//:                     ...
//:   ------------
//:              <----------------------------  :(before "End Foo")
//:                                             ....
//:                                             ...
//:   // End Foo
//:   ============
//:
//: Here's part of a layer in color: http://i.imgur.com/0eONnyX.png. Directives
//: are shaded dark.
//:
//: Layers do more than just shuffle code around. In a well-organized codebase
//: it should be possible to stop loading after any file/layer, build and run
//: the program, and pass all tests for loaded features. (Relevant is
//: http://youtube.com/watch?v=c8N72t7aScY, a scene from "2001: A Space
//: Odyssey".) Get into the habit of running the included script called
//: 'test_layers' before you commit any changes.
//:
//: This 'subsetting guarantee' ensures that this directory contains a
//: cleaned-up narrative of the evolution of this codebase. Organizing
//: autobiographically allows newcomers to rapidly orient themselves, reading
//: the first few files to understand a simple gestalt of a program's core
//: purpose and features, and later gradually working their way through other
//: features as the need arises.
//:
//: Programmers shouldn't need to understand everything about a program to
//: hack on it. But they shouldn't be prevented from a thorough understanding
//: of each aspect either. The goal of layers is to reward curiosity.
//:
//: More information: http://akkartik.name/post/wart-layers

// Includes
// End Includes

// Types
// End Types

// Function prototypes are auto-generated in the 'build' script; define your
// functions in any order. Just be sure to declare each function header all on
// one line, ending with the '{'. Our auto-generation scripts are too minimal
// and simple-minded to handle anything else.
#include "function_list"  // by convention, files ending with '_list' are auto-generated

// Globals
//
// All statements in this section should always define a single variable on a
// single line. The 'build' script will simple-mindedly auto-generate extern
// declarations for them. Remember to define (not just declare) constants with
// extern linkage in this section, since C++ global constants have internal
// linkage by default.
//
// End Globals

int main(int argc, char* argv[]) {
  atexit(reset);
  // we require a 32-bit little-endian system
  assert(sizeof(int) == 4);
  assert(sizeof(float) == 4);
  assert_little_endian();

  // End One-time Setup

  // Commandline Parsing
  // End Commandline Parsing

  // End Main

  return 0;
}

// Unit Tests
// End Unit Tests

//: our first directive; insert the following headers at the start of the program
:(before "End Includes")
#include <assert.h>
#include <stdlib.h>

//: Without directives or with the :(code) directive, lines get added at the
//: end.
//:
//: Regardless of where functions are defined, we can call them anywhere we
//: like as long as we format the function header in a specific way: put it
//: all on a single line without indent, end the line with ') {' and no
//: trailing whitespace. As long as functions uniformly start this way, our
//: 'build' script contains a little command to automatically generate
//: declarations for them.
:(code)
void reset() {
  // End Reset
}

void assert_little_endian() {
  const int x = 1;
  const char* y = reinterpret_cast<const char*>(&x);
  if (*y != 1) {
    cerr << "SubX requires a little-endian processor. Do you have Intel (or AMD or Atom) inside?\n";
    exit(1);
  }
}
:(before "End Includes")
#include<iostream>
using std::cerr;
