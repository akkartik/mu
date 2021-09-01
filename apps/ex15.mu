# Demo of combining-character support in Mu, which can be summarized as, "the
# old typewriter-based approach of backing up one character and adding the
# accent or _matra_ in."
#   https://en.wikipedia.org/wiki/Combining_character
#
# Mu uses this approach for both accents in Latin languages and vowel
# diacritics in Abugida scripts.
#   https://en.wikipedia.org/wiki/Diacritic
#   https://en.wikipedia.org/wiki/Abugida
#
# Steps for trying it out:
#   1. Translate this example into a disk image code.img.
#       ./translate apps/ex15.mu
#   2. Run:
#       qemu-system-i386 -hda code.img -hdb data.img
#
# Expected output: 'à' in green in a few places near the top-left corner of
# screen, showing off what this approach can and cannot do.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # at the top of screen, the accent is almost cropped
  var dummy/eax: int <-    draw-code-point-on-real-screen   0x61/a,                       0/x 0/y, 3/fg 0/bg
  var dummy/eax: int <- overlay-code-point-on-real-screen 0x0300/combining-grave-accent,  0/x 0/y, 3/fg 0/bg

  # below a grapheme with a descender, the accent uglily overlaps
  #   https://en.wikipedia.org/wiki/Descender
  var dummy/eax: int <-    draw-code-point-on-real-screen   0x67/g,                       4/x 3/y, 3/fg 0/bg
  var dummy/eax: int <-    draw-code-point-on-real-screen   0x61/a,                       4/x 4/y, 3/fg 0/bg
  var dummy/eax: int <- overlay-code-point-on-real-screen 0x0300/combining-grave-accent,  4/x 4/y, 3/fg 0/bg

  # beside a grapheme with a descender, it becomes more obvious that monowidth fonts can't make baselines line up
  #   https://en.wikipedia.org/wiki/Baseline_(typography)
  var dummy/eax: int <-    draw-code-point-on-real-screen   0x67/g,                       8/x 3/y, 3/fg 0/bg
  var dummy/eax: int <-    draw-code-point-on-real-screen   0x61/a,                       9/x 3/y, 3/fg 0/bg
  var dummy/eax: int <- overlay-code-point-on-real-screen 0x0300/combining-grave-accent,  9/x 3/y, 3/fg 0/bg
}
