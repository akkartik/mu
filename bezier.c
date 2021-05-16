#include<assert.h>
#include<stdio.h>

void setPixel(int x, int y) {
  printf("%d %d\n", x, y);
}

void plotQuadBezierSeg(int x0, int y0, int x1, int y1, int x2, int y2)
{                            
  int sx = x2-x1, sy = y2-y1;
  long xx = x0-x1, yy = y0-y1, xy;         /* relative values for checks */
  double dx, dy, err, cur = xx*sy-yy*sx;                    /* curvature */

  assert(xx*sx <= 0 && yy*sy <= 0);  /* sign of gradient must not change */

  printf("0 sx %d sy %d xx %ld yy %ld xy %ld cur %g\n", sx, sy, xx, yy, xy, cur);
  if (sx*(long)sx+sy*(long)sy > xx*xx+yy*yy) { /* begin with longer part */ 
    printf("swap\n");
    x2 = x0; x0 = sx+x1; y2 = y0; y0 = sy+y1; cur = -cur;  /* swap P0 P2 */
  }  
  if (cur != 0) {                                    /* no straight line */
    xx += sx; xx *= sx = x0 < x2 ? 1 : -1;           /* x step direction */
    yy += sy; yy *= sy = y0 < y2 ? 1 : -1;           /* y step direction */
    xy = 2*xx*yy; xx *= xx; yy *= yy;          /* differences 2nd degree */
    if (cur*sx*sy < 0) {                           /* negated curvature? */
      xx = -xx; yy = -yy; xy = -xy; cur = -cur;
    }
    printf("1 sx %d sy %d xx %ld yy %ld xy %ld cur %g\n", sx, sy, xx, yy, xy, cur);
    dx = 4.0*sy*cur*(x1-x0)+xx-xy;             /* differences 1st degree */
    dy = 4.0*sx*cur*(y0-y1)+yy-xy;
    xx += xx; yy += yy; err = dx+dy+xy;                /* error 1st step */    
    do {                              
      printf("%d %d: dx %g dy %g err %g\n", x0, y0, dx, dy, err);
      if (x0 == x2 && y0 == y2) return;  /* last pixel -> curve finished */
      y1 = 2*err < dx;                  /* save value for test of y step */
      if (2*err > dy) { x0 += sx; dx -= xy; err += dy += yy; } /* x step */
      if (    y1    ) { y0 += sy; dy -= xy; err += dx += xx; } /* y step */
    } while (dy < dx );           /* gradient negates -> algorithm fails */
  }
//?   plotLine(x0,y0, x2,y2);                  /* plot remaining part to end */
}

int main(void) {
  plotQuadBezierSeg(1, 1, 0x80, 0x100, 0x200, 0x140);
  return 0;
}
