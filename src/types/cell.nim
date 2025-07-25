import types/color
import utils/strwidth

type
  FormatFlag* = enum
    ffBold = "bold"
    ffItalic = "italic"
    ffUnderline = "underline"
    ffReverse = "reverse"
    ffStrike = "strike"
    ffOverline = "overline"
    ffBlink = "blink"

  Format* = object
    u: uint64

  SimpleFormatCell* = object
    format*: Format
    pos*: int

  SimpleFlexibleLine* = object
    str*: string
    formats*: seq[SimpleFormatCell]

  SimpleFlexibleGrid* = seq[SimpleFlexibleLine]

  FixedCell* = object
    str*: string
    format*: Format

  FixedGrid* = object
    width*, height*: int
    cells*: seq[FixedCell]

proc `[]=`*(grid: var FixedGrid; i: int; cell: FixedCell) = grid.cells[i] = cell
proc `[]=`*(grid: var FixedGrid; i: BackwardsIndex; cell: FixedCell) =
  grid.cells[i] = cell
proc `[]`*(grid: var FixedGrid; i: int): var FixedCell = grid.cells[i]
proc `[]`*(grid: var FixedGrid; i: BackwardsIndex): var FixedCell =
  grid.cells[i]
proc `[]`*(grid: FixedGrid; i: int): lent FixedCell = grid.cells[i]
proc `[]`*(grid: FixedGrid; i: BackwardsIndex): lent FixedCell =
  return grid.cells[grid.cells.len - int(i)]

proc len*(grid: FixedGrid): int {.inline.} = grid.cells.len
proc high*(grid: FixedGrid): int {.inline.} = grid.cells.high

template bgcolor*(format: Format): CellColor =
  CellColor(format.u and 0x3FFFFFF)

template fgcolor*(format: Format): CellColor =
  CellColor((format.u shr 26) and 0x3FFFFFF)

template flags*(format: Format): set[FormatFlag] =
  cast[set[FormatFlag]](format.u shr 52)

template `bgcolor=`*(format: var Format; bgcolor: CellColor) =
  format.u = format.u and static(not 0x3FFFFFFu64) or uint64(bgcolor)

template `fgcolor=`*(format: var Format; fgcolor: CellColor) =
  format.u = format.u and static(not (0x3FFFFFFu64 shl 26)) or
    (uint64(fgcolor) shl 26)

template `flags=`*(format: var Format; flags: set[FormatFlag]) =
  format.u = format.u and static(not (0xFFFu64 shl 52)) or
    (cast[uint64](flags) shl 52)

template incl*(format: var Format; flag: FormatFlag) =
  format.u = format.u or (cast[uint64]({flag}) shl 52)

template excl*(format: var Format; flag: FormatFlag) =
  format.u = format.u and not (cast[uint64]({flag}) shl 52)

static:
  doAssert {FormatFlag.low..FormatFlag.high}.card <= 12

func initFormat*(bgcolor, fgcolor: CellColor; flags: set[FormatFlag]): Format =
  return Format(
    u: uint64(bgcolor.toUint26()) or
      (uint64(fgcolor.toUint26()) shl 26) or
      (cast[uint64](flags) shl 52)
  )

func initFormat*(): Format =
  return initFormat(defaultColor, defaultColor, {})

iterator items*(grid: FixedGrid): lent FixedCell {.inline.} =
  for cell in grid.cells:
    yield cell

func newFixedGrid*(w: int; h: int = 1): FixedGrid =
  return FixedGrid(width: w, height: h, cells: newSeq[FixedCell](w * h))

func width*(cell: FixedCell): int =
  return cell.str.width()

# Get the first format cell after pos, if any.
func findFormatN*(line: SimpleFlexibleLine; pos: int): int =
  var i = 0
  while i < line.formats.len:
    if line.formats[i].pos > pos:
      break
    inc i
  return i

func findFormat*(line: SimpleFlexibleLine; pos: int): SimpleFormatCell =
  let i = line.findFormatN(pos) - 1
  if i != -1:
    return line.formats[i]
  return SimpleFormatCell(pos: -1)

func findNextFormat*(line: SimpleFlexibleLine; pos: int): SimpleFormatCell =
  let i = line.findFormatN(pos)
  if i < line.formats.len:
    return line.formats[i]
  return SimpleFormatCell(pos: -1)
