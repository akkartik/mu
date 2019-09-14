#ifndef FRAMEBUFFER_H
#define FRAMEBUFFER_H

#include "common.h"

enum EnFrameBuferIoctl
{
    FB_GET_WIDTH,
    FB_GET_HEIGHT,
    FB_GET_BITSPERPIXEL
};

void initializeFrameBuffer(uint8* p_address, uint8* v_address);

#endif // FRAMEBUFFER_H
