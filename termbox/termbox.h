#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*** 1. Controlling the screen. */

/* The screen is a 2D array of cells. */
struct tb_cell {
  uint32_t ch;  /* unicode character */
  uint16_t fg;  /* foreground color (0-255) and attributes */
  uint16_t bg;  /* background color (0-255) and attributes */
};

/* Names for some colors in tb_cell.fg and tb_cell.bg. */
#define TB_BLACK 232
#define TB_WHITE 255

/* Colors in tb_cell can be combined using bitwise-OR with multiple
 * of the following attributes. */
#define TB_BOLD      0x0100
#define TB_UNDERLINE 0x0200
#define TB_REVERSE   0x0400

/* Initialize screen and keyboard. */
int tb_init(void);
/* Possible error codes returned by tb_init() */
#define TB_EUNSUPPORTED_TERMINAL -1
#define TB_EFAILED_TO_OPEN_TTY   -2
/* Termbox uses unix pipes in order to deliver a message from a signal handler
 * (SIGWINCH) to the main event reading loop. */
#define TB_EPIPE_TRAP_ERROR      -3

/* Restore terminal mode. */
void tb_shutdown(void);

int tb_is_active(void);

/* Size of the screen. Return negative values before tb_init() or after
 * tb_shutdown() */
int tb_width(void);
int tb_height(void);

/* Update the screen with internal state. Most methods below modify just the
 * internal state of the screen. Changes won't be visible until you call
 * tb_present(). */
void tb_present(void);

/* Variant of tb_present() that always refreshes the entire screen. */
void tb_sync(void);

/* Returns a pointer to the internal screen state: a 1D array of cells in
 * raster order. You'll need to call tb_width() and tb_height() for the
 * array's dimensions. The array stays valid until tb_clear() or tb_present()
 * are called. */
struct tb_cell *tb_cell_buffer();

/* Clear the internal screen state using either TB_DEFAULT or the
 * color/attributes set by tb_set_clear_attributes(). */
void tb_clear(void);
void tb_set_clear_attributes(uint16_t fg, uint16_t bg);

/* Move the cursor. Upper-left character is (0, 0).
 */
void tb_set_cursor(int cx, int cy);
/* To hide the cursor, call tb_set_cursor(TB_HIDE_CURSOR, TB_HIDE_CURSOR).
 * Cursor starts out hidden. */
#define TB_HIDE_CURSOR -1

/* Modify a specific cell of the screen. Don't forget to call tb_present() to
 * commit your changes. */
void tb_change_cell(int x, int y, uint32_t ch, uint16_t fg, uint16_t bg);



/*** 2. Controlling keyboard events. */

struct tb_event {
  uint8_t type;
  /* fields for type TB_EVENT_KEY. At most one of 'key' and 'ch' will be set at
   * any time. */
  uint16_t key;
  uint32_t ch;
  /* fields for type TB_EVENT_RESIZE */
  int32_t w;
  int32_t h;
  /* fields for type TB_EVENT_MOUSE */
  int32_t x;
  int32_t y;
};

/* Possible values for tb_event.type. */
#define TB_EVENT_KEY    1
#define TB_EVENT_RESIZE 2
#define TB_EVENT_MOUSE  3

/* Possible values for tb_event.key. */
#define TB_KEY_F1               (0xFFFF-0)
#define TB_KEY_F2               (0xFFFF-1)
#define TB_KEY_F3               (0xFFFF-2)
#define TB_KEY_F4               (0xFFFF-3)
#define TB_KEY_F5               (0xFFFF-4)
#define TB_KEY_F6               (0xFFFF-5)
#define TB_KEY_F7               (0xFFFF-6)
#define TB_KEY_F8               (0xFFFF-7)
#define TB_KEY_F9               (0xFFFF-8)
#define TB_KEY_F10              (0xFFFF-9)
#define TB_KEY_F11              (0xFFFF-10)
#define TB_KEY_F12              (0xFFFF-11)
#define TB_KEY_INSERT           (0xFFFF-12)
#define TB_KEY_DELETE           (0xFFFF-13)
#define TB_KEY_HOME             (0xFFFF-14)
#define TB_KEY_END              (0xFFFF-15)
#define TB_KEY_PGUP             (0xFFFF-16)
#define TB_KEY_PGDN             (0xFFFF-17)
#define TB_KEY_ARROW_UP         (0xFFFF-18)
#define TB_KEY_ARROW_DOWN       (0xFFFF-19)
#define TB_KEY_ARROW_LEFT       (0xFFFF-20)
#define TB_KEY_ARROW_RIGHT      (0xFFFF-21)
#define TB_KEY_MOUSE_LEFT       (0xFFFF-22)
#define TB_KEY_MOUSE_RIGHT      (0xFFFF-23)
#define TB_KEY_MOUSE_MIDDLE     (0xFFFF-24)
#define TB_KEY_MOUSE_RELEASE    (0xFFFF-25)
#define TB_KEY_MOUSE_WHEEL_UP   (0xFFFF-26)
#define TB_KEY_MOUSE_WHEEL_DOWN (0xFFFF-27)
#define TB_KEY_START_PASTE      (0xFFFF-28)
#define TB_KEY_END_PASTE        (0xFFFF-29)
#define TB_KEY_CTRL_ARROW_UP    (0xFFFF-30)
#define TB_KEY_CTRL_ARROW_DOWN  (0xFFFF-31)
#define TB_KEY_CTRL_ARROW_LEFT  (0xFFFF-32)
#define TB_KEY_CTRL_ARROW_RIGHT (0xFFFF-33)
#define TB_KEY_SHIFT_TAB        (0xFFFF-34)

/* Names for some of the possible values for tb_event.ch. */
/* These are all ASCII code points below SPACE character and a BACKSPACE key. */
#define TB_KEY_CTRL_TILDE       0x00
#define TB_KEY_CTRL_2           0x00 /* clash with 'CTRL_TILDE' */
#define TB_KEY_CTRL_A           0x01
#define TB_KEY_CTRL_B           0x02
#define TB_KEY_CTRL_C           0x03
#define TB_KEY_CTRL_D           0x04
#define TB_KEY_CTRL_E           0x05
#define TB_KEY_CTRL_F           0x06
#define TB_KEY_CTRL_G           0x07
#define TB_KEY_BACKSPACE        0x08
#define TB_KEY_CTRL_H           0x08 /* clash with 'CTRL_BACKSPACE' */
#define TB_KEY_TAB              0x09
#define TB_KEY_CTRL_I           0x09 /* clash with 'TAB' */
#define TB_KEY_CTRL_J           0x0A
#define TB_KEY_CTRL_K           0x0B
#define TB_KEY_CTRL_L           0x0C
#define TB_KEY_ENTER            0x0D
#define TB_KEY_CTRL_M           0x0D /* clash with 'ENTER' */
#define TB_KEY_CTRL_N           0x0E
#define TB_KEY_CTRL_O           0x0F
#define TB_KEY_CTRL_P           0x10
#define TB_KEY_CTRL_Q           0x11
#define TB_KEY_CTRL_R           0x12
#define TB_KEY_CTRL_S           0x13
#define TB_KEY_CTRL_T           0x14
#define TB_KEY_CTRL_U           0x15
#define TB_KEY_CTRL_V           0x16
#define TB_KEY_CTRL_W           0x17
#define TB_KEY_CTRL_X           0x18
#define TB_KEY_CTRL_Y           0x19
#define TB_KEY_CTRL_Z           0x1A
#define TB_KEY_ESC              0x1B
#define TB_KEY_CTRL_LSQ_BRACKET 0x1B /* clash with 'ESC' */
#define TB_KEY_CTRL_3           0x1B /* clash with 'ESC' */
#define TB_KEY_CTRL_4           0x1C
#define TB_KEY_CTRL_BACKSLASH   0x1C /* clash with 'CTRL_4' */
#define TB_KEY_CTRL_5           0x1D
#define TB_KEY_CTRL_RSQ_BRACKET 0x1D /* clash with 'CTRL_5' */
#define TB_KEY_CTRL_6           0x1E
#define TB_KEY_CTRL_7           0x1F
#define TB_KEY_CTRL_SLASH       0x1F /* clash with 'CTRL_7' */
#define TB_KEY_CTRL_UNDERSCORE  0x1F /* clash with 'CTRL_7' */
#define TB_KEY_SPACE            0x20
#define TB_KEY_BACKSPACE2       0x7F
#define TB_KEY_CTRL_8           0x7F /* clash with 'DELETE' */
/* These are non-existing ones.
 *
 * #define TB_KEY_CTRL_1 clash with '1'
 * #define TB_KEY_CTRL_9 clash with '9'
 * #define TB_KEY_CTRL_0 clash with '0'
 */
/* Some aliases */
#define TB_KEY_NEWLINE TB_KEY_CTRL_J
#define TB_KEY_CARRIAGE_RETURN TB_KEY_CTRL_M

/* Wait for an event up to 'timeout' milliseconds and fill the 'event'
 * structure with it, when the event is available. Returns the type of the
 * event (one of TB_EVENT_* constants) or -1 if there was an error or 0 in case
 * there were no event during 'timeout' period.
 */
int tb_peek_event(struct tb_event *event, int timeout);

/* Wait for an event forever and fill the 'event' structure with it, when the
 * event is available. Returns the type of the event (one of TB_EVENT_*
 * constants) or -1 if there was an error.
 */
int tb_poll_event(struct tb_event *event);

int tb_event_ready(void);



/*** 3. Utility utf8 functions. */
#define TB_EOF -1
int tb_utf8_char_length(char c);
int tb_utf8_char_to_unicode(uint32_t *out, const char *c);
int tb_utf8_unicode_to_char(char *out, uint32_t c);
const char* to_unicode(uint32_t c);

#ifdef __cplusplus
}
#endif
