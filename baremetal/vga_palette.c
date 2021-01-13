/* Visualize the standard VGA palette.
 * Based on https://github.com/canidlogic/vgapal (MIT License) */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

char* bar(int n) {
  char* result = calloc(65, 1);
  int i;
  for (i = 0; i < n; ++i)
    result[i] = '.';
  for (; i < 64; ++i)
    result[i] = ' ';
  result[64] = '\0';
  return result;
}

void addColor(int r, int g, int b) {
  static int i = 0;
//?   printf("%02x %02x %02x\n", r, g, b);
  printf("%3d: %2d %2d %2d %s %s %s\n", i, r, g, b, bar(r), bar(g), bar(b));
  ++i;
}

void addGrayColor(int v) {
  addColor(v, v, v);
}

void add16Color(int lo, int melo, int mehi, int hi) {
  int r, g, b, i, h, l;

  for (i = 0; i < 8; i++) {
    r = g = b = lo;
    if (i & 4) r = mehi;
    if (i & 2) g = (i==6)?melo:mehi;  /* exception: color 6 is brown rather than dark yellow */
    if (i & 1) b = mehi;
    addColor(r, g, b);
  }

  for (i = 0; i < 8; i++) {
    r = g = b = melo;
    if (i & 4) r = hi;
    if (i & 2) g = hi;
    if (i & 1) b = hi;
    addColor(r, g, b);
  }
}

/* Add four colors to the palette corresponding to a "run" within an RGB cycle.
 *
 * start - high and low starting states for each channel at the start of the run
 * ch - the channel to change from high to low or low to high */
void addRun(int start, int ch, int lo, int melo, int me, int mehi, int hi) {
  int r, g, b, i, up;

  /* Check parameters */
  if (start < 0 || start > 7)
    abort();
  if (ch != 1 && ch != 2 && ch != 4)
    abort();

  /* Get the starting RGB color and add it */
  r = lo;
  g = lo;
  b = lo;
  if ((start & 4) == 4)
    r = hi;
  if ((start & 2) == 2)
    g = hi;
  if ((start & 1) == 1)
    b = hi;
  addColor(r, g, b);

  /* If selected channel starts high, we're going down; otherwise we're going up */
  up = (start & ch) != ch;

  /* Add remaining three colors of the run */
  switch (ch) {
  case 4:  r = up?melo:mehi; break;
  case 2:  g = up?melo:mehi; break;
  case 1:  b = up?melo:mehi; break;
  }
  addColor(r, g, b);

  switch (ch) {
  case 4:  r = me; break;
  case 2:  g = me; break;
  case 1:  b = me; break;
  }
  addColor(r, g, b);

  switch (ch) {
  case 4:  r = up?mehi:melo; break;
  case 2:  g = up?mehi:melo; break;
  case 1:  b = up?mehi:melo; break;
  }
  addColor(r, g, b);
}

/* A cycle consists of six 4-color runs, each of which transitions from
 * one hue to another until arriving back at starting position. */
void addCycle(int lo, int melo, int me, int mehi, int hi) {
  int hue = 1;  /* blue */
  addRun(hue, 4, lo, melo, me, mehi, hi);
  hue ^= 4;
  assert(hue == 5);
  addRun(hue, 1, lo, melo, me, mehi, hi);
  hue ^= 1;
  assert(hue == 4);
  addRun(hue, 2, lo, melo, me, mehi, hi);
  hue ^= 2;
  assert(hue == 6);
  addRun(hue, 4, lo, melo, me, mehi, hi);
  hue ^= 4;
  assert(hue == 2);
  addRun(hue, 1, lo, melo, me, mehi, hi);
  hue ^= 1;
  assert(hue == 3);
  addRun(hue, 2, lo, melo, me, mehi, hi);
}

int main(void) {
  int i;

  /* 16-color palette */
  add16Color(0, 21, 42, 63);

  /* 16 shades of gray */
  addGrayColor( 0);
  addGrayColor( 5);
  addGrayColor( 8);
  addGrayColor(11);
  addGrayColor(14);
  addGrayColor(17);
  addGrayColor(20);
  addGrayColor(24);
  addGrayColor(28);
  addGrayColor(32);
  addGrayColor(36);
  addGrayColor(40);
  addGrayColor(45);
  addGrayColor(50);
  addGrayColor(56);
  addGrayColor(63);

  /* Nine RGB cycles organized in three groups of three cycles,
   * The groups represent high/medium/low value,
   * and the cycles within the groups represent high/medium/low saturation. */
  addCycle( 0, 16, 31, 47, 63);
  addCycle(31, 39, 47, 55, 63);
  addCycle(45, 49, 54, 58, 63);

  addCycle( 0,  7, 14, 21, 28);
  addCycle(14, 17, 21, 24, 28);
  addCycle(20, 22, 24, 26, 28);

  addCycle( 0,  4,  8, 12, 16);
  addCycle( 8, 10, 12, 14, 16);
  addCycle(11, 12, 13, 15, 16);

  /* final eight palette entries are full black */
  for (i = 0; i < 8; ++i)
    addGrayColor(0);

  return 0;
}
