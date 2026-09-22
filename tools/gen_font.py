"""Stage 17: the two faces of EBB as BMFont (.fnt + .png) for Godot (STYLE.md 16).

    ebb.fnt / ebb.png                  the body face "Ledger": 8 px, proportional, 7 px caps,
                                       5 px x-height, true 2 px descenders, line 10, base 7.
                                       Request font_size 8. Digits are tabular (advance 5).
    ebb_display.fnt / ebb_display.png  the display face "Plate": 16 px, slab-serif capitals
                                       12 px tall with 2 px stems (wood type, the nameplate
                                       and the chandlery board), line 16, base 12. Lowercase
                                       maps to the capitals. Request font_size 16, or 32 for
                                       the one banner at run start.
    assets/reference/anchors/type_sheet.png   the specimen: every glyph, the roles, samples

Run:  python tools/gen_font.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as P  # noqa: E402
from gen_anchors import zoom  # noqa: E402

ROOT = P.ROOT
OUT = os.path.join(ROOT, "assets", "fonts")
REF = os.path.join(ROOT, "assets", "reference", "anchors")


# ---------------------------------------------------------------------------------------
# The body face: "Ledger".  Rows from the cap line: 0-6 are the seven rows above the
# baseline (x-height is rows 2-6), 7-8 the descender.  Width is the glyph's own; the
# advance is width + 1.  Everything a keeper writes in the ledger is set in this.
# ---------------------------------------------------------------------------------------
BODY = {}
BODY_LINE = 10
BODY_BASE = 7
BODY_SPACE = 3


def b(ch, *rows):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (ch, r)
    assert len(rows) <= 9, ch
    BODY[ch] = list(rows)


b("A", ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#")
b("B", "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####.")
b("C", ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###.")
b("D", "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####.")
b("E", "####", "#...", "#...", "###.", "#...", "#...", "####")
b("F", "####", "#...", "#...", "###.", "#...", "#...", "#...")
b("G", ".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###.")
b("H", "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#")
b("I", "###", ".#.", ".#.", ".#.", ".#.", ".#.", "###")
b("J", ".###", "...#", "...#", "...#", "...#", "#..#", ".##.")
b("K", "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#")
b("L", "#...", "#...", "#...", "#...", "#...", "#...", "####")
b("M", "#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#")
b("N", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#")
b("O", ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.")
b("P", "###.", "#..#", "#..#", "###.", "#...", "#...", "#...")
b("Q", ".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#")
b("R", "###.", "#..#", "#..#", "###.", "#.#.", "#..#", "#..#")
b("S", ".###", "#...", "#...", ".##.", "...#", "...#", "###.")
b("T", "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..")
b("U", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.")
b("V", "#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#..")
b("W", "#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#")
b("X", "#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#")
b("Y", "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#..")
b("Z", "####", "...#", "..#.", ".#..", "#...", "#...", "####")

b("a", "....", "....", ".##.", "...#", ".###", "#..#", ".###")
b("b", "#...", "#...", "###.", "#..#", "#..#", "#..#", "###.")
b("c", "...", "...", ".##", "#..", "#..", "#..", ".##")
b("d", "...#", "...#", ".###", "#..#", "#..#", "#..#", ".###")
b("e", "....", "....", ".##.", "#..#", "####", "#...", ".##.")
b("f", ".##", "#..", "###", "#..", "#..", "#..", "#..")
b("g", "....", "....", ".###", "#..#", "#..#", "#..#", ".###", "...#", ".##.")
b("h", "#...", "#...", "###.", "#..#", "#..#", "#..#", "#..#")
b("i", "#", ".", "#", "#", "#", "#", "#")
b("j", ".#", "..", ".#", ".#", ".#", ".#", ".#", ".#", "#.")
b("k", "#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#")
b("l", "#.", "#.", "#.", "#.", "#.", "#.", ".#")
b("m", ".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#")
b("n", "....", "....", "###.", "#..#", "#..#", "#..#", "#..#")
b("o", "....", "....", ".##.", "#..#", "#..#", "#..#", ".##.")
b("p", "....", "....", "###.", "#..#", "#..#", "#..#", "###.", "#...", "#...")
b("q", "....", "....", ".###", "#..#", "#..#", "#..#", ".###", "...#", "...#")
b("r", "...", "...", "#.#", "##.", "#..", "#..", "#..")
b("s", "....", "....", ".###", "#...", ".##.", "...#", "###.")
b("t", "...", ".#.", "###", ".#.", ".#.", ".#.", ".##")
b("u", "....", "....", "#..#", "#..#", "#..#", "#..#", ".###")
b("v", "...", "...", "#.#", "#.#", "#.#", "#.#", ".#.")
b("w", ".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#.")
b("x", "...", "...", "#.#", "#.#", ".#.", "#.#", "#.#")
b("y", "....", "....", "#..#", "#..#", "#..#", "#..#", ".###", "...#", ".##.")
b("z", "....", "....", "####", "...#", ".##.", "#...", "####")

b("0", ".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##.")
b("1", "..#.", ".##.", "..#.", "..#.", "..#.", "..#.", ".###")
b("2", ".##.", "#..#", "...#", "..#.", ".#..", "#...", "####")
b("3", "###.", "...#", "...#", ".##.", "...#", "...#", "###.")
b("4", "..#.", ".##.", "#.#.", "#..#", "####", "...#", "...#")
b("5", "####", "#...", "###.", "...#", "...#", "#..#", ".##.")
b("6", ".##.", "#...", "###.", "#..#", "#..#", "#..#", ".##.")
b("7", "####", "...#", "...#", "..#.", "..#.", ".#..", ".#..")
b("8", ".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##.")
b("9", ".##.", "#..#", "#..#", "#..#", ".###", "...#", ".##.")

b(".", ".", ".", ".", ".", ".", ".", "#")
b(",", "..", "..", "..", "..", "..", ".#", ".#", "#.")
b(":", ".", ".", "#", ".", ".", ".", "#")
b(";", "..", "..", ".#", "..", "..", ".#", ".#", "#.")
b("!", "#", "#", "#", "#", "#", ".", "#")
b("?", ".##.", "#..#", "...#", "..#.", ".#..", "....", ".#..")
b("'", "#", "#")
b('"', "#.#", "#.#")
b("-", "...", "...", "...", "###")
b("+", "...", "...", ".#.", "###", ".#.")
b("/", "..#", "..#", ".#.", ".#.", ".#.", "#..", "#..")
b("(", ".#", "#.", "#.", "#.", "#.", "#.", ".#")
b(")", "#.", ".#", ".#", ".#", ".#", ".#", "#.")
b("[", "##", "#.", "#.", "#.", "#.", "#.", "##")
b("]", "##", ".#", ".#", ".#", ".#", ".#", "##")
b("%", "##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##")
b("<", "...", "...", "..#", ".#.", "#..", ".#.", "..#")
b(">", "...", "...", "#..", ".#.", "..#", ".#.", "#..")
b("=", "...", "...", "...", "###", "...", "###")
b("_", "....", "....", "....", "....", "....", "....", "....", "####")
b("#", "...", "...", "#.#", "###", "#.#", "###", "#.#")
b("&", ".##..", "#..#.", "#..#.", ".##..", "#.#.#", "#..#.", ".##.#")
b("*", "...", "#.#", ".#.", "#.#")
b("~", "....", "....", "....", ".#.#", "#.#.")
b("|", "#", "#", "#", "#", "#", "#", "#", "#", "#")
b("{", ".##", ".#.", ".#.", "#..", ".#.", ".#.", ".##")
b("}", "##.", ".#.", ".#.", "..#", ".#.", ".#.", "##.")
b("\\", "#..", "#..", ".#.", ".#.", ".#.", "..#", "..#")

# Tabular digits: every figure advances 5 so counts and timers do not jitter.
BODY_ADVANCE = {ch: len(BODY[ch][0]) + 1 for ch in BODY}
for ch in "0123456789":
    BODY_ADVANCE[ch] = 5
BODY_ADVANCE["#"] = 4   # the same as the hyphen: the daily board's text bar stays even
BODY_ADVANCE["-"] = 4
BODY_ADVANCE[" "] = BODY_SPACE
BODY[" "] = ["..."]


# ---------------------------------------------------------------------------------------
# The display face: "Plate".  Capitals 12 rows tall (0-11), 2 px stems, 1 px slab serifs;
# Q and the comma go two rows under the baseline.  Advance is width + 2.
# ---------------------------------------------------------------------------------------
DISPLAY = {}
DISPLAY_LINE = 16
DISPLAY_BASE = 12
DISPLAY_SPACE = 5


def d(ch, *rows):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (ch, r)
    assert len(rows) <= 14, ch
    DISPLAY[ch] = list(rows)


d("A",
  "....##....",
  "....##....",
  "...####...",
  "...####...",
  "..##..##..",
  "..##..##..",
  "..######..",
  "..######..",
  "..##..##..",
  ".##....##.",
  ".##....##.",
  "####..####")
d("B",
  "#######..",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##..##..",
  ".######..",
  ".##...##.",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##...##.",
  "#######..")
d("C",
  "..######.",
  ".##....##",
  "##......#",
  "##.......",
  "##.......",
  "##.......",
  "##.......",
  "##.......",
  "##......#",
  "##.....##",
  ".##...##.",
  "..######.")
d("D",
  "######...",
  ".##..##..",
  ".##...##.",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##...##.",
  ".##..##..",
  "######...")
d("E",
  "########",
  ".##....#",
  ".##.....",
  ".##.....",
  ".##..#..",
  ".######.",
  ".##..#..",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##....#",
  "########")
d("F",
  "########",
  ".##....#",
  ".##.....",
  ".##.....",
  ".##..#..",
  ".######.",
  ".##..#..",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  "####....")
d("G",
  "..######.",
  ".##....##",
  "##......#",
  "##.......",
  "##.......",
  "##...####",
  "##...####",
  "##.....##",
  "##.....##",
  "##.....##",
  ".##...##.",
  "..######.")
d("H",
  "####.####",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".#######.",
  ".#######.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  "####.####")
d("I",
  "####",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  ".##.",
  "####")
d("J",
  "....####",
  ".....##.",
  ".....##.",
  ".....##.",
  ".....##.",
  ".....##.",
  ".....##.",
  ".....##.",
  "##...##.",
  "##...##.",
  ".##.##..",
  "..###...")
d("K",
  "####.####",
  ".##...##.",
  ".##..##..",
  ".##.##...",
  ".####....",
  ".###.....",
  ".####....",
  ".##.##...",
  ".##..##..",
  ".##...##.",
  ".##....##",
  "####..###")
d("L",
  "####....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##.....",
  ".##....#",
  "########")
d("M",
  "###.....###",
  ".##.....##.",
  ".###...###.",
  ".###...###.",
  ".####.####.",
  ".##.###.##.",
  ".##.###.##.",
  ".##..#..##.",
  ".##.....##.",
  ".##.....##.",
  ".##.....##.",
  "###.....###")
d("N",
  "####..####",
  ".###...##.",
  ".###...##.",
  ".####..##.",
  ".####..##.",
  ".##.##.##.",
  ".##.##.##.",
  ".##..####.",
  ".##..####.",
  ".##...###.",
  ".##...###.",
  "####..####")
d("O",
  "..######..",
  ".##....##.",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  ".##....##.",
  "..######..")
d("P",
  "#######..",
  ".##...##.",
  ".##....##",
  ".##....##",
  ".##....##",
  ".##...##.",
  ".######..",
  ".##......",
  ".##......",
  ".##......",
  ".##......",
  "####.....")
d("Q",
  "..######..",
  ".##....##.",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##......##",
  "##...##.##",
  ".##...###.",
  "..######..",
  "........##")
d("R",
  "#######..",
  ".##...##.",
  ".##....##",
  ".##....##",
  ".##...##.",
  ".######..",
  ".##.##...",
  ".##..##..",
  ".##..##..",
  ".##...##.",
  ".##...##.",
  "####.####")
d("S",
  "..######.",
  ".##....##",
  "##......#",
  "##.......",
  ".###.....",
  "..#####..",
  "....####.",
  "......###",
  "#......##",
  "##.....##",
  ".##...##.",
  "..######.")
d("T",
  "##########",
  "#...##...#",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "...####...")
d("U",
  "####.####",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  ".##...##.",
  "..#####..")
d("V",
  "####..####",
  ".##....##.",
  ".##....##.",
  ".##....##.",
  ".##....##.",
  "..##..##..",
  "..##..##..",
  "..##..##..",
  "...####...",
  "...####...",
  "....##....",
  "....##....")
d("W",
  "####......####",
  ".##........##.",
  ".##........##.",
  ".##...##...##.",
  ".##...##...##.",
  ".##..####..##.",
  ".##..####..##.",
  ".##.##..##.##.",
  ".##.##..##.##.",
  ".####....####.",
  "..##......##..",
  "..##......##..")
d("X",
  "####..####",
  ".##....##.",
  ".##....##.",
  "..##..##..",
  "..##..##..",
  "...####...",
  "...####...",
  "..##..##..",
  "..##..##..",
  ".##....##.",
  ".##....##.",
  "####..####")
d("Y",
  "####..####",
  ".##....##.",
  ".##....##.",
  "..##..##..",
  "..##..##..",
  "...####...",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "....##....",
  "...####...")
d("Z",
  "#########",
  "#.....##.",
  ".....##..",
  ".....##..",
  "....##...",
  "....##...",
  "...##....",
  "...##....",
  "..##.....",
  "..##.....",
  ".##.....#",
  "#########")

d("0",
  ".######.",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  ".######.")
d("1",
  "...##...",
  ".####...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  ".######.")
d("2",
  ".######.",
  "##....##",
  "##....##",
  "......##",
  ".....##.",
  "....##..",
  "...##...",
  "..##....",
  ".##.....",
  "##......",
  "##.....#",
  "########")
d("3",
  ".######.",
  "##....##",
  "......##",
  "......##",
  ".....##.",
  "...####.",
  ".....##.",
  "......##",
  "......##",
  "##....##",
  "##....##",
  ".######.")
d("4",
  ".....##.",
  "....###.",
  "...####.",
  "..##.##.",
  ".##..##.",
  "##...##.",
  "##...##.",
  "########",
  ".....##.",
  ".....##.",
  ".....##.",
  "....####")
d("5",
  "########",
  "##.....#",
  "##......",
  "##......",
  "######..",
  "##...##.",
  "......##",
  "......##",
  "......##",
  "##....##",
  "##....##",
  ".######.")
d("6",
  "..#####.",
  ".##....#",
  "##......",
  "##......",
  "##.###..",
  "###...##",
  "##.....#",
  "##.....#",
  "##.....#",
  "##.....#",
  ".##...##",
  "..#####.")
d("7",
  "########",
  "#.....##",
  "......##",
  ".....##.",
  ".....##.",
  "....##..",
  "....##..",
  "...##...",
  "...##...",
  "...##...",
  "...##...",
  "...##...")
d("8",
  ".######.",
  "##....##",
  "##....##",
  "##....##",
  ".##..##.",
  "..####..",
  ".##..##.",
  "##....##",
  "##....##",
  "##....##",
  "##....##",
  ".######.")
d("9",
  ".#####..",
  "##...##.",
  "#.....##",
  "#.....##",
  "#.....##",
  "#.....##",
  "##...###",
  "..###.##",
  "......##",
  "......##",
  "#....##.",
  ".#####..")

d(".", "..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##")
d(",", "..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##", ".#", "#.")
d(":", "..", "..", "..", "##", "##", "..", "..", "..", "..", "..", "##", "##")
d(";", "..", "..", "..", "##", "##", "..", "..", "..", "..", "..", "##", "##", ".#", "#.")
d("!", "##", "##", "##", "##", "##", "##", "##", "##", "##", "..", "##", "##")
d("?",
  ".######.",
  "##....##",
  "##....##",
  "......##",
  ".....##.",
  "....##..",
  "...##...",
  "...##...",
  "........",
  "........",
  "...##...",
  "...##...")
d("'", "##", "##", ".#")
d('"', "##.##", "##.##", ".#..#")
d("-", ".....", ".....", ".....", ".....", ".....", "#####", "#####")
d("+", "......", "......", "......", "..##..", "..##..", "######", "######", "..##..", "..##..")
d("/",
  "......##",
  "......##",
  ".....##.",
  ".....##.",
  "....##..",
  "....##..",
  "...##...",
  "...##...",
  "..##....",
  "..##....",
  ".##.....",
  ".##.....")
d("(", "..##", ".##.", "##..", "##..", "##..", "##..", "##..", "##..", "##..", "##..", ".##.", "..##")
d(")", "##..", ".##.", "..##", "..##", "..##", "..##", "..##", "..##", "..##", "..##", ".##.", "##..")
d("&",
  "..####....",
  ".##..##...",
  ".##..##...",
  ".##..##...",
  "..####....",
  ".###....##",
  "##.##...##",
  "##..##.##.",
  "##...###..",
  "##...###..",
  ".##.##.##.",
  "..###...##")
DISPLAY[" "] = ["....."]
DISPLAY_ADVANCE = {ch: len(DISPLAY[ch][0]) + 2 for ch in DISPLAY}
for ch in "0123456789":
    DISPLAY_ADVANCE[ch] = 10
DISPLAY_ADVANCE[" "] = DISPLAY_SPACE
# Sentence case set in the display face comes out in capitals.
DISPLAY_ALIAS = {chr(ord("a") + i): chr(ord("A") + i) for i in range(26)}


# ---------------------------------------------------------------------------------------
# Packing and the .fnt
# ---------------------------------------------------------------------------------------
class Face:
    def __init__(self, name, glyphs, advance, alias, line, base, cell_h):
        self.name = name
        self.glyphs = glyphs
        self.advance = advance
        self.alias = alias
        self.line = line
        self.base = base
        self.cell_h = cell_h
        self.pos = {}
        self.image = None

    def width(self, s):
        return sum(self.advance[self.alias.get(c, c)] for c in s if self.alias.get(c, c) in self.advance)

    def pack(self):
        chars = sorted(self.glyphs.keys(), key=ord)
        x, y, row_w = 1, 1, 0
        sheet_w = 128 if self.name == "ebb" else 192
        for ch in chars:
            w = len(self.glyphs[ch][0])
            if x + w + 1 > sheet_w:
                x = 1
                y += self.cell_h + 1
            self.pos[ch] = (x, y)
            x += w + 1
        h = y + self.cell_h + 1
        im = Image.new("RGBA", (sheet_w, h), (0, 0, 0, 0))
        px = im.load()
        for ch in chars:
            gx, gy = self.pos[ch]
            for yy, row in enumerate(self.glyphs[ch]):
                for xx, c in enumerate(row):
                    if c == "#":
                        px[gx + xx, gy + yy] = (255, 255, 255, 255)
        self.image = im
        return im

    def fnt(self, png_name, size):
        w, h = self.image.size
        lines = [
            'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % (self.name, size),
            "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0" % (self.line, self.base, w, h),
            'page id=0 file="%s"' % png_name,
        ]
        entries = []
        ids = sorted(list(self.glyphs.keys()) + list(self.alias.keys()), key=ord)
        for ch in ids:
            src = self.alias.get(ch, ch)
            gx, gy = self.pos[src]
            gw = len(self.glyphs[src][0])
            gh = len(self.glyphs[src])
            entries.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                           % (ord(ch), gx, gy, gw, gh, self.advance[src]))
        lines.append("chars count=%d" % len(entries))
        lines.extend(entries)
        return "\n".join(lines) + "\n"

    def draw(self, im, x, y, s, colour, shadow=None):
        """Draws `s` with the cap line at y. Returns the advance."""
        px = im.load()
        cx = x
        for c in s:
            c = self.alias.get(c, c)
            if c not in self.glyphs:
                c = "?"
            for yy, row in enumerate(self.glyphs[c]):
                for xx, p in enumerate(row):
                    if p == "#":
                        if shadow is not None:
                            px[cx + xx + shadow, y + yy + shadow] = shadow_colour(colour)
                        px[cx + xx, y + yy] = colour
            cx += self.advance[c]
        return cx - x


def shadow_colour(_c):
    return P.rgb("INK") + (255,)


def build_faces():
    body = Face("ebb", BODY, BODY_ADVANCE, {}, BODY_LINE, BODY_BASE, 9)
    disp = Face("ebb_display", DISPLAY, DISPLAY_ADVANCE, DISPLAY_ALIAS, DISPLAY_LINE, DISPLAY_BASE, 14)
    body.pack()
    disp.pack()
    return body, disp


# ---------------------------------------------------------------------------------------
# The specimen sheet
# ---------------------------------------------------------------------------------------
def rgba(key, a=255):
    return P.rgb(key) + (a,)


def specimen(body, disp):
    W = 1500
    sheet = Image.new("RGBA", (W, 1180), rgba("NIGHT_1"))
    dr = ImageDraw.Draw(sheet)
    try:
        cap = ImageFont.load_default(size=11)
    except TypeError:
        cap = ImageFont.load_default()

    def caption(x, y, s):
        dr.text((x, y), s, fill=P.rgb("VERDIGRIS"), font=cap)

    def paste(im, x, y):
        sheet.alpha_composite(im, (x, y))

    def sample(face, lines, colour, shadow, bg, z, gap=None):
        gap = gap or face.line
        w = max(face.width(s) for s in lines) + 4
        h = gap * len(lines) + 4
        im = Image.new("RGBA", (w, h), bg)
        for i, s in enumerate(lines):
            face.draw(im, 2, 2 + i * gap, s, colour, shadow)
        return zoom(im, z)

    dr.text((12, 10), "EBB type  -  Stage 17  -  the body face Ledger (8 px) and the display face Plate (16 px)  -  STYLE.md 16",
            fill=P.rgb("SALT_WHITE"), font=cap)

    # 1. Every body glyph at 4x
    y = 30
    caption(12, y, "1. Ledger: every glyph at 4x, cap 7, x-height 5, descenders 2, line 10, proportional; digits tabular")
    y += 16
    rows = ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", "0123456789 .,:;!?'\"-+/()[]%<>=_#&*~|{}\\"]
    paste(sample(body, rows, rgba("SALT_WHITE"), 1, rgba("NIGHT_1"), 4), 12, y)
    y += 4 * (body.line * 3 + 4) + 8

    # 2. The roles at 1x and 3x, over the panel and over sand
    caption(12, y, "2. The four roles at 1x and 3x on Night 1 (the panel) with the 1 px Ink shadow; the danger tag; the whisper spacing")
    y += 16
    roles = [("SALT_WHITE", "Primary: A crab the size of a dog under a keeper's boat, upturned. It still rows."),
             ("PALE_SLATE", "Secondary: They dive at the lantern, not at you. Put the light down and they circle."),
             ("WET_GREY", "Muted: 15 of 21 met   room 3 of 9   pearls 42   shards 7   quietly, jumping fox"),
             ("WARM_YELLOW", "Accent: [E] talk   [Q] flare ready   [R] active ready   a night waits at the shore")]
    lines1 = sample(body, [t for _, t in roles], rgba("SALT_WHITE"), 1, rgba("NIGHT_1"), 1)
    # recolour per line
    im1 = Image.new("RGBA", (max(body.width(t) for _, t in roles) + 4, body.line * 4 + 4), rgba("NIGHT_1"))
    for i, (c, t) in enumerate(roles):
        body.draw(im1, 2, 2 + i * body.line, t, rgba(c), 1)
    paste(im1, 12, y)
    paste(zoom(im1, 3), 12, y + im1.height + 6)
    y += im1.height + 6 + im1.height * 3 + 8

    # the danger tag and the whisper
    tag = Image.new("RGBA", (body.width("not enough salt") + 4, 10), rgba("SALT_RED"))
    body.draw(tag, 2, 1, "not enough salt", rgba("SALT_WHITE"), None)
    wh_text = "\"The water remembers the shape of the town. So do you.\""
    wh = Image.new("RGBA", (body.width(wh_text) + len(wh_text) + 4, 12), rgba("NIGHT_1"))
    cx = 2
    for ch in wh_text:
        body.draw(wh, cx, 2, ch, rgba("PALE_SLATE"), 1)
        cx += body.advance.get(ch, 3) + 1
    paste(zoom(tag, 3), 12, y)
    paste(zoom(wh, 3), 12 + tag.width * 3 + 24, y)
    y += 40

    # 3. Over the world: sand, water, and the HUD numbers
    caption(12, y, "3. Over the world at 3x: Sand and Sea with the shadow (the floating RIPTIDE, the room sub line, HUD figures)")
    y += 16
    world = Image.new("RGBA", (300, 44), rgba("SAND"))
    for xx in range(150, 300):
        for yy in range(44):
            world.putpixel((xx, yy), rgba("SEA"))
    body.draw(world, 6, 4, "RIPTIDE   CRACK   +3 salt", rgba("SALT_WHITE"), 1)
    body.draw(world, 6, 18, "3 / 9   Combat   Brine tide 2", rgba("PALE_SLATE"), 1)
    body.draw(world, 6, 32, "130 hp   30   0   dash   special   lantern", rgba("SALT_WHITE"), 1)
    body.draw(world, 160, 4, "RIPTIDE   CRACK   +3 salt", rgba("SALT_WHITE"), 1)
    body.draw(world, 160, 18, "3 / 9   Combat   Brine tide 2", rgba("PALE_SLATE"), 1)
    body.draw(world, 160, 32, "out   rising   high   deep", rgba("WARM_YELLOW"), 1)
    paste(zoom(world, 3), 12, y)
    y += 44 * 3 + 12

    # 4. Plate: every glyph at 3x
    caption(12, y, "4. Plate: every glyph at 3x, capitals 12 tall, 2 px stems, 1 px slab serifs; lowercase sets as capitals")
    y += 16
    rows = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789 .,:;!?'\"-+/()&"]
    paste(sample(disp, rows, rgba("SALT_WHITE"), 1, rgba("NIGHT_1"), 3), 12, y)
    y += 3 * (disp.line * 3 + 4) + 8

    # 5. Titles at 1x and 2x (the 32 px banner) in the card colours
    caption(12, y, "5. Titles at 1x (16) and 2x (the one 32 px banner): cards, the boss name, a header, the results, over Night 1 and over Sand")
    y += 16
    titles = [("SALT_WHITE", "THE HARBOUR"), ("PALE_CREAM", "THE WRECK"), ("SALT_RED", "THE WRECK STIRS"),
              ("WARM_YELLOW", "THE TIDE TURNS"), ("SALT_WHITE", "CODEX"), ("SEA_PALE", "TAKEN BY THE TIDE")]
    tx = 12
    for c, t in titles:
        im = Image.new("RGBA", (disp.width(t) + 4, disp.line + 6), rgba("NIGHT_1"))
        disp.draw(im, 2, 2, t, rgba(c), 1)
        paste(im, tx, y)
        paste(zoom(im, 2), tx, y + 24)
        tx += im.width * 2 + 12
    y += 24 + (disp.line + 6) * 2 + 10
    im = Image.new("RGBA", (disp.width("Keeper's Log  Room 3 of 9") + 4, disp.line + 6), rgba("SAND"))
    disp.draw(im, 2, 2, "Keeper's Log  Room 3 of 9", rgba("SALT_WHITE"), 1)
    paste(zoom(im, 2), 12, y)
    im2 = Image.new("RGBA", (disp.width("HOLD UNTIL THE TIDE TURNS") + 4, disp.line + 6), rgba("SEA"))
    disp.draw(im2, 2, 2, "HOLD UNTIL THE TIDE TURNS", rgba("SALT_WHITE"), 1)
    paste(zoom(im2, 2), 12 + im.width * 2 + 16, y)
    y += (disp.line + 6) * 2 + 12

    # 6. The old font beside the new, same text, 3x
    old_png = os.path.join(REF, "font_old.png")
    old_fnt = os.path.join(REF, "font_old.fnt")
    if os.path.exists(old_png) and os.path.exists(old_fnt):
        caption(12, y, "6. Before and after at 3x: the old 5x7 (no descenders, 2x2 dots, monospace) and Ledger")
        y += 16
        old = load_old(old_png, old_fnt)
        line = "The gulls never left when the city went under. They dive at anything lit. 15 of 21 met, quietly."
        im = Image.new("RGBA", (max(old.width(line), body.width(line)) + 4, 28), rgba("NIGHT_1"))
        old.draw(im, 2, 2, line, rgba("SALT_WHITE"), 1)
        body.draw(im, 2, 15, line, rgba("SALT_WHITE"), 1)
        paste(zoom(im, 3), 12, y)
        y += 28 * 3 + 12
    sheet = sheet.crop((0, 0, W, min(sheet.height, y + 8)))
    return sheet


def load_old(png, fnt):
    """The retired font, read back from its sheet so the specimen can show it beside the new one."""
    im = Image.open(png).convert("RGBA")
    glyphs, adv = {}, {}
    line, base = 9, 7
    for l in open(fnt):
        parts = l.split()
        if not parts:
            continue
        kv = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
        if parts[0] == "common":
            line, base = int(kv["lineHeight"]), int(kv["base"])
        if parts[0] == "char":
            x, y, w, h = int(kv["x"]), int(kv["y"]), int(kv["width"]), int(kv["height"])
            rows = []
            for yy in range(h):
                rows.append("".join("#" if im.getpixel((x + xx, y + yy))[3] > 0 else "." for xx in range(w)))
            ch = chr(int(kv["id"]))
            glyphs[ch] = rows
            adv[ch] = int(kv["xadvance"])
    return Face("old", glyphs, adv, {}, line, base, 8)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REF, exist_ok=True)
    # Keep the retired font once, for the before-and-after.
    old_png, old_fnt = os.path.join(OUT, "ebb.png"), os.path.join(OUT, "ebb.fnt")
    if os.path.exists(old_fnt) and not os.path.exists(os.path.join(REF, "font_old.fnt")):
        with open(old_fnt) as f:
            if "lineHeight=9 " in f.read():
                Image.open(old_png).save(os.path.join(REF, "font_old.png"))
                with open(old_fnt) as src, open(os.path.join(REF, "font_old.fnt"), "w", newline="\n") as dst:
                    dst.write(src.read())
    body, disp = build_faces()
    body.image.save(os.path.join(OUT, "ebb.png"))
    with open(os.path.join(OUT, "ebb.fnt"), "w", newline="\n") as f:
        f.write(body.fnt("ebb.png", 8))
    disp.image.save(os.path.join(OUT, "ebb_display.png"))
    with open(os.path.join(OUT, "ebb_display.fnt"), "w", newline="\n") as f:
        f.write(disp.fnt("ebb_display.png", 16))
    print("wrote ebb.fnt (%d glyphs, %dx%d) and ebb_display.fnt (%d glyphs + %d aliases, %dx%d)"
          % (len(BODY), body.image.width, body.image.height, len(DISPLAY), len(DISPLAY_ALIAS),
             disp.image.width, disp.image.height))
    specimen(body, disp).save(os.path.join(REF, "type_sheet.png"))
    print("wrote", os.path.join(REF, "type_sheet.png"))


if __name__ == "__main__":
    main()
