sig pixel screen: (addr screen), x: int, y: int, color: int
sig read-key kbd: (addr keyboard) -> _/eax: byte
sig draw-grapheme screen: (addr screen), g: grapheme, x: int, y: int, color: int
