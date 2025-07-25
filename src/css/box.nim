import css/cssvalues
import css/lunit
import html/dom
import types/bitmap
import types/refstring

type
  DimensionType* = enum
    dtHorizontal, dtVertical

  Offset* = array[DimensionType, LUnit]

  Size* = array[DimensionType, LUnit]

  InlineImageState* = object
    offset*: Offset
    size*: Size

  TextRun* = ref object
    offset*: Offset
    str*: string

  BoxLayoutState* = object
    # offset relative to parent
    offset*: Offset
    # padding size
    size*: Size
    # intrinsic minimum size (e.g. longest word)
    intr*: Size
    # baseline of the first line box of all descendants
    firstBaseline*: LUnit
    # baseline of the last line box of all descendants
    baseline*: LUnit
    # Bottom margin of the box, collapsed with the margin of children.
    # This is already added to size, and only used by flex layout.
    marginBottom*: LUnit

  Area* = object
    offset*: Offset
    size*: Size

  InlineBoxState* = object
    startOffset*: Offset # offset of the first word, for position: absolute
    areas*: seq[Area] # background that should be painted by box

  Span* = object
    start*: LUnit
    send*: LUnit

  RelativeRect* = array[DimensionType, Span]

  StackItem* = ref object
    box*: CSSBox
    index*: int32
    children*: seq[StackItem]

  ClipBox* = object
    start*: Offset
    send*: Offset

  BoxRenderState* = object
    # Whether the following two variables have been initialized.
    #TODO find a better name that doesn't conflict with box.positioned
    positioned*: bool
    offset*: Offset
    clipBox*: ClipBox

  # min-content: box width is longest word's width
  # max-content: box width is content width without wrapping
  # stretch: box width is n px wide
  # fit-content: also known as shrink-to-fit, box width is
  #   min(max-content, stretch(availableWidth))
  #   in other words, as wide as needed, but wrap if wider than allowed
  # (note: I write width here, but it can apply for any constraint)
  SizeConstraintType* = enum
    scStretch, scFitContent, scMinContent, scMaxContent

  SizeConstraint* = object
    t*: SizeConstraintType
    u*: LUnit

  AvailableSpace* = array[DimensionType, SizeConstraint]

  Bounds* = object
    a*: array[DimensionType, Span] # width clamp
    mi*: array[DimensionType, Span] # intrinsic clamp

  ResolvedSizes* = object
    margin*: RelativeRect
    padding*: RelativeRect
    space*: AvailableSpace
    bounds*: Bounds

  CSSBox* = ref object of RootObj
    parent* {.cursor.}: CSSBox
    firstChild*: CSSBox
    next*: CSSBox
    positioned*: bool # set if we participate in positioned layout
    render*: BoxRenderState # render output
    computed*: CSSValues
    element*: Element

  BlockBox* = ref object of CSSBox
    sizes*: ResolvedSizes # tree builder output -> layout input
    state*: BoxLayoutState # layout output -> render input

  InlineBox* = ref object of CSSBox
    state*: InlineBoxState

  InlineTextBox* = ref object of InlineBox
    runs*: seq[TextRun] # state
    text*: RefString

  InlineNewLineBox* = ref object of InlineBox

  InlineImageBox* = ref object of InlineBox
    imgstate*: InlineImageState
    bmp*: NetworkBitmap

  InlineBlockBox* = ref object of InlineBox
    # InlineBlockBox always has one block child.

  LayoutResult* = ref object
    stack*: StackItem

func offset*(x, y: LUnit): Offset =
  return [dtHorizontal: x, dtVertical: y]

func x*(offset: Offset): LUnit {.inline.} =
  return offset[dtHorizontal]

func x*(offset: var Offset): var LUnit {.inline.} =
  return offset[dtHorizontal]

func `x=`*(offset: var Offset; x: LUnit) {.inline.} =
  offset[dtHorizontal] = x

func y*(offset: Offset): LUnit {.inline.} =
  return offset[dtVertical]

func y*(offset: var Offset): var LUnit {.inline.} =
  return offset[dtVertical]

func `y=`*(offset: var Offset; y: LUnit) {.inline.} =
  offset[dtVertical] = y

func size*(w, h: LUnit): Size =
  return [dtHorizontal: w, dtVertical: h]

func w*(size: Size): LUnit {.inline.} =
  return size[dtHorizontal]

func w*(size: var Size): var LUnit {.inline.} =
  return size[dtHorizontal]

func `w=`*(size: var Size; w: LUnit) {.inline.} =
  size[dtHorizontal] = w

func h*(size: Size): LUnit {.inline.} =
  return size[dtVertical]

func h*(size: var Size): var LUnit {.inline.} =
  return size[dtVertical]

func `h=`*(size: var Size; h: LUnit) {.inline.} =
  size[dtVertical] = h

func `+`*(a, b: Offset): Offset =
  return offset(x = a.x + b.x, y = a.y + b.y)

func `-`*(a, b: Offset): Offset =
  return offset(x = a.x - b.x, y = a.y - b.y)

proc `+=`*(a: var Offset; b: Offset) =
  a.x += b.x
  a.y += b.y

proc `-=`*(a: var Offset; b: Offset) =
  a.x -= b.x
  a.y -= b.y

func left*(s: RelativeRect): LUnit =
  return s[dtHorizontal].start

func right*(s: RelativeRect): LUnit =
  return s[dtHorizontal].send

func top*(s: RelativeRect): LUnit =
  return s[dtVertical].start

func bottom*(s: RelativeRect): LUnit =
  return s[dtVertical].send

func topLeft*(s: RelativeRect): Offset =
  return offset(x = s.left, y = s.top)

proc `+=`*(span: var Span; u: LUnit) =
  span.start += u
  span.send += u

func `<`*(a, b: Offset): bool =
  return a.x < b.x and a.y < b.y

iterator children*(box: CSSBox): CSSBox =
  var it {.cursor.} = box.firstChild
  while it != nil:
    yield it
    it = it.next

proc resetState(box: CSSBox) =
  box.render = BoxRenderState()

proc resetState*(ibox: InlineBox) =
  CSSBox(ibox).resetState()
  ibox.state = InlineBoxState()

proc resetState*(box: BlockBox) =
  CSSBox(box).resetState()
  box.state = BoxLayoutState()

const DefaultClipBox* = ClipBox(send: offset(LUnit.high, LUnit.high))

when defined(debug):
  import chame/tags

  proc `$`*(box: CSSBox; pass2 = true): string =
    if box.positioned and not pass2:
      return ""
    result = "<"
    let name = if box.computed{"display"} != DisplayInline:
      if box.element.tagType in {TAG_HTML, TAG_BODY}:
        $box.element.tagType
      else:
        "div"
    elif box of InlineNewLineBox:
      "br"
    else:
      "span"
    result &= name
    let computed = box.computed.copyProperties()
    if computed{"display"} == DisplayBlock:
      computed{"display"} = DisplayInline
    var style = $computed.serializeEmpty()
    if style != "":
      if style[^1] == ';':
        style.setLen(style.high)
      result &= " style='" & style & "'"
    result &= ">"
    if box of InlineNewLineBox:
      return
    if box of BlockBox:
      result &= '\n'
    for it in box.children:
      result &= `$`(it, pass2 = false)
    if box of InlineTextBox:
      for run in InlineTextBox(box).runs:
        result &= run.str
    if box of BlockBox:
      result &= '\n'
    result &= "</" & name & ">"

  proc `$`*(stack: StackItem): string =
    result = "<STACK index=" & $stack.index & ">\n"
    result &= `$`(stack.box, pass2 = true)
    result &= "\n"
    for child in stack.children:
      result &= "<child>\n"
      result &= $child
      result &= "</child>\n"
    result &= "</STACK>\n"
