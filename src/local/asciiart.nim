# ASCII art image converter.
#
# Converts raw RGBA pixel data into colored Unicode block characters
# using 2x2 sub-pixel resolution per terminal cell.

{.push raises: [].}

import std/math
import types/cell
import types/color

# Block element lookup table.
# Bits: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
const BlockChars: array[16, string] = [
  " ",  # 0000
  "▘",  # 0001: top-left
  "▝",  # 0010: top-right
  "▀",  # 0011: upper half
  "▖",  # 0100: bottom-left
  "▌",  # 0101: left half
  "▞",  # 0110: top-right + bottom-left
  "▛",  # 0111: top-left + top-right + bottom-left
  "▗",  # 1000: bottom-right
  "▚",  # 1001: top-left + bottom-right
  "▐",  # 1010: right half
  "▜",  # 1011: top-left + top-right + bottom-right
  "▄",  # 1100: lower half
  "▙",  # 1101: top-left + bottom-left + bottom-right
  "▟",  # 1110: top-right + bottom-left + bottom-right
  "█",  # 1111: full block
]

type Sample = object
  r, g, b, a, n: uint32

proc luminance(r, g, b: uint8): uint8 {.inline.} =
  ## ITU-R BT.601 luma, scaled to 0-255.
  uint8((uint32(r) * 299 + uint32(g) * 587 + uint32(b) * 114 + 500) div 1000)

proc blendWhite(r, g, b, a: uint8): tuple[r, g, b: uint8] {.inline.} =
  ## Alpha-blend a color against white background.
  if a == 255:
    return (r, g, b)
  if a == 0:
    return (255'u8, 255'u8, 255'u8)
  let af = uint32(a)
  let inv = 255 - af
  (
    uint8((uint32(r) * af + 255 * inv + 127) div 255),
    uint8((uint32(g) * af + 255 * inv + 127) div 255),
    uint8((uint32(b) * af + 255 * inv + 127) div 255),
  )

proc sampleRegion(data: ptr UncheckedArray[uint8]; w: int;
    x0, y0, x1, y1: int): Sample =
  result = Sample()
  ## Area-average all pixels in [x0, y0) ..< [x1, y1).
  let x0 = max(x0, 0)
  let y0 = max(y0, 0)
  let x1 = max(x1, x0)
  let y1 = max(y1, y0)
  for y in y0 ..< y1:
    let row = y * w
    for x in x0 ..< x1:
      let i = (row + x) * 4
      result.r += uint32(data[i])
      result.g += uint32(data[i + 1])
      result.b += uint32(data[i + 2])
      result.a += uint32(data[i + 3])
      result.n += 1

proc avgBlended(s: Sample): tuple[r, g, b: uint8] {.inline.} =
  ## Average the sample and alpha-blend against white.
  if s.n == 0:
    return (255'u8, 255'u8, 255'u8)
  blendWhite(
    uint8(s.r div s.n),
    uint8(s.g div s.n),
    uint8(s.b div s.n),
    uint8(s.a div s.n),
  )

proc rgbaToAsciiGrid*(data: pointer; w, h: int;
    ppc, ppl: int; quality: int; datalen = -1): seq[SimpleFlexibleLine] =
  ## Convert RGBA pixel data to a grid of colored block characters.
  ##
  ## data: raw RGBA pixels (R, G, B, A bytes, row-major, 4 bytes/pixel)
  ## w, h: image dimensions in pixels
  ## ppc: pixels per character cell width
  ## ppl: pixels per character cell height
  ## quality: 1..100
  ##   1-30:  monochrome (no color formatting)
  ##   31-70: 256-color ANSI foreground
  ##   71-100: truecolor RGB foreground
  if data == nil or w <= 0 or h <= 0 or ppc <= 0 or ppl <= 0:
    return @[]
  let expected = w * h * 4
  if datalen != -1 and datalen < expected:
    return @[]
  # Copy data to local buffer to avoid GC/mmap lifetime issues
  var buf = newSeq[uint8](expected)
  copyMem(addr buf[0], data, expected)
  let px = cast[ptr UncheckedArray[uint8]](addr buf[0])
  let cols = (w + ppc - 1) div ppc  # ceil
  let rows = (h + ppl - 1) div ppl
  let hw = ppc div 2
  let hh = ppl div 2

  newSeq(result, rows)

  for cy in 0 ..< rows:
    var line = SimpleFlexibleLine(str: "", formats: @[])
    var lastFg = defaultColor

    for cx in 0 ..< cols:
      let x0 = cx * ppc
      let y0 = cy * ppl
      let x1 = min(x0 + ppc, w)
      let y1 = min(y0 + ppl, h)
      let mx = x0 + hw
      let my = y0 + hh

      # Sample 4 sub-pixel quadrants
      let tl = px.sampleRegion(w, x0, y0, mx, my)
      let tr = px.sampleRegion(w, mx, y0, x1, my)
      let bl = px.sampleRegion(w, x0, my, mx, y1)
      let br = px.sampleRegion(w, mx, my, x1, y1)

      # Cell average for threshold and foreground color
      let cell = px.sampleRegion(w, x0, y0, x1, y1)
      let (cr, cg, cb) = avgBlended(cell)
      let cellLum = luminance(cr, cg, cb)

      # Determine bit pattern: sub-pixel is "on" if its luminance >= cell avg
      var bits = 0u8
      let (tlr, tlg, tlb) = avgBlended(tl)
      if luminance(tlr, tlg, tlb) >= cellLum: bits = bits or 0b0001
      let (trr, trg, trb) = avgBlended(tr)
      if luminance(trr, trg, trb) >= cellLum: bits = bits or 0b0010
      let (blr, blg, blb) = avgBlended(bl)
      if luminance(blr, blg, blb) >= cellLum: bits = bits or 0b0100
      let (brr, brg, brb) = avgBlended(br)
      if luminance(brr, brg, brb) >= cellLum: bits = bits or 0b1000

      line.str &= BlockChars[bits]

      # Set foreground color based on quality level
      let fg = if bits == 0:
        defaultColor
      elif quality > 70:
        cellColor(rgb(cr, cg, cb))
      elif quality > 30:
        rgb(cr, cg, cb).toEightBit().cellColor()
      else:
        defaultColor  # monochrome: block chars with default fg

      if fg != lastFg:
        line.formats.add(SimpleFormatCell(
          format: initFormat(defaultColor, fg, {}),
          pos: cx,
        ))
        lastFg = fg

    result[cy] = line

{.pop.}
