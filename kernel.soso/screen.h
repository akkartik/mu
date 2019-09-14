#ifndef SCREEN_H
#define SCREEN_H

#include "common.h"
#include "tty.h"

void Screen_FlushFromTty(Tty* tty);
void Screen_Print(int row, int column, const char* text);
void Screen_SetActiveColor(uint8 color);
void Screen_ApplyColor(uint8 color);
void Screen_Clear();
void Screen_SetCursorVisible(BOOL visible);
void Screen_MoveCursor(uint16 line, uint16 column);
void Screen_GetCursor(uint16* line, uint16* column);

#endif //SCREEN_H
