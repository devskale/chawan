{.push raises: [].}

import std/algorithm
import std/options
import std/sets
import std/tables

import chame/tags
import config/conftypes
import css/cssparser
import css/cssvalues
import css/lunit
import css/match
import css/sheet
import html/catom
import html/dom
import html/enums
import html/script
import types/color
import types/jscolor
import types/opt

type
  RuleListEntry = object
    normal: seq[CSSComputedEntry]
    important: seq[CSSComputedEntry]
    normalVars: seq[CSSVariable]
    importantVars: seq[CSSVariable]

  RuleList = array[CSSOrigin, RuleListEntry]

  RuleListMap = array[PseudoElement, RuleList]

  RulePair = tuple
    specificity: int
    rule: CSSRuleDef

  ToSorts = array[PseudoElement, seq[RulePair]]

  InitType = enum
    itUserAgent, itUser, itOther

  InitMap = array[CSSPropertyType, set[InitType]]

  ApplyValueContext = object
    vals: CSSValues
    vars: CSSVariableMap
    parentComputed: CSSValues
    previousOrigin: CSSValues
    window: Window
    initMap: InitMap
    varsSeen: HashSet[CAtom]

# Forward declarations
proc applyStyle*(element: Element)

proc calcRule(tosorts: var ToSorts; element: Element;
    depends: var DependencyInfo; rule: CSSRuleDef) =
  for sel in rule.sels:
    if element.matches(sel, depends):
      if tosorts[sel.pseudo].len > 0 and tosorts[sel.pseudo][^1].rule == rule:
        tosorts[sel.pseudo][^1].specificity =
          max(tosorts[sel.pseudo][^1].specificity, sel.specificity)
      else:
        tosorts[sel.pseudo].add((sel.specificity, rule))

proc add(entry: var RuleListEntry; rule: CSSRuleDef) =
  entry.normal.add(rule.normalVals)
  entry.important.add(rule.importantVals)
  entry.normalVars.add(rule.normalVars)
  entry.importantVars.add(rule.importantVars)

proc calcRules(map: var RuleListMap; element: Element;
    sheet: CSSStylesheet; origin: CSSOrigin; depends: var DependencyInfo) =
  var rules: seq[CSSRuleDef] = @[]
  sheet.tagTable.withValue(element.localName, v):
    rules.add(v[])
  if element.id != CAtomNull:
    sheet.idTable.withValue(element.id.toLowerAscii(), v):
      rules.add(v[])
  for class in element.classList:
    sheet.classTable.withValue(class.toLowerAscii(), v):
      rules.add(v[])
  for attr in element.attrs:
    sheet.attrTable.withValue(attr.qualifiedName, v):
      rules.add(v[])
  if element.parentElement == nil:
    for rule in sheet.rootList:
      rules.add(rule)
  for rule in sheet.generalList:
    rules.add(rule)
  var tosorts = ToSorts.default
  for rule in rules:
    tosorts.calcRule(element, depends, rule)
  for pseudo, it in tosorts.mpairs:
    it.sort(proc(x, y: RulePair): int =
      let n = cmp(x.specificity, y.specificity)
      if n != 0:
        return n
      return cmp(x.rule.idx, y.rule.idx), order = Ascending)
    for item in it:
      map[pseudo][origin].add(item.rule)

proc findVariable(ctx: var ApplyValueContext; varName: CAtom): CSSVariable =
  while ctx.vars != nil:
    let cvar = ctx.vars.table.getOrDefault(varName)
    if cvar != nil:
      return cvar
    ctx.vars = ctx.vars.parent
  return nil

proc resolveVariable(ctx: var ApplyValueContext; t: CSSPropertyType;
    varName: CAtom; fallback: ref CSSComputedEntry): Opt[CSSComputedEntry] =
  let v = t.valueType
  let cvar = ctx.findVariable(varName)
  if cvar == nil:
    if fallback != nil:
      return ok(fallback[])
    return err()
  for (iv, entry) in cvar.resolved.mitems:
    if iv == v:
      entry.t = t # must override, same var can be used for different props
      return ok(entry)
  var entries: seq[CSSComputedEntry] = @[]
  if entries.parseComputedValues($t, cvar.toks,
      ctx.window.settings.attrsp[]).isOk:
    if entries[0].et == ceVar:
      if ctx.varsSeen.containsOrIncl(varName) or ctx.varsSeen.len > 20:
        ctx.varsSeen.clear()
        return err()
    else:
      ctx.varsSeen.clear()
      cvar.resolved.add((v, entries[0]))
    return ok(entries[0])
  err()

proc applyGlobal(ctx: ApplyValueContext; t: CSSPropertyType;
    global: CSSGlobalType; initType: InitType) =
  case global
  of cgtInherit:
    ctx.vals.initialOrCopyFrom(ctx.parentComputed, t)
  of cgtInitial:
    ctx.vals.setInitial(t)
  of cgtUnset:
    ctx.vals.initialOrInheritFrom(ctx.parentComputed, t)
  of cgtRevert:
    if ctx.previousOrigin != nil and initType in ctx.initMap[t]:
      ctx.vals.copyFrom(ctx.previousOrigin, t)
    else:
      ctx.vals.initialOrInheritFrom(ctx.parentComputed, t)

proc applyValue0(ctx: var ApplyValueContext; entry: CSSComputedEntry;
    initType: InitType; nextInitType: set[InitType]): Opt[void] =
  ctx.vars = ctx.vals.vars
  var entry = entry
  while entry.et == ceVar:
    entry = ?ctx.resolveVariable(entry.t, entry.cvar, entry.fallback)
  case entry.et
  of ceBit: ctx.vals.bits[entry.t].dummy = entry.bit
  of ceWord: ctx.vals.words[entry.t] = entry.word
  of ceObject: ctx.vals.objs[entry.t] = entry.obj
  of ceGlobal: ctx.applyGlobal(entry.t, entry.global, initType)
  of ceVar: assert false
  ctx.initMap[entry.t] = ctx.initMap[entry.t] + nextInitType
  ok()

proc applyValue(ctx: var ApplyValueContext; entry: CSSComputedEntry;
    initType: InitType; nextInitType: set[InitType]) =
  discard ctx.applyValue0(entry, initType, nextInitType)

proc applyPresHint(ctx: var ApplyValueContext; entry: CSSComputedEntry) =
  ctx.applyValue(entry, itUserAgent, {itUser})

proc applyDimensionHint(ctx: var ApplyValueContext; p: CSSPropertyType;
    s: string) =
  let s = parseDimensionValues(s)
  if s.isSome:
    ctx.applyPresHint(makeEntry(p, s.get))

proc applyDimensionHintGz(ctx: var ApplyValueContext; p: CSSPropertyType;
    s: string) =
  let s = parseDimensionValues(s).get(CSSLengthZero)
  if not s.isZero:
    ctx.applyPresHint(makeEntry(p, s))

proc applyColorHint(ctx: var ApplyValueContext; p: CSSPropertyType; s: string) =
  let c = parseLegacyColor(s)
  if c.isOk:
    ctx.applyPresHint(makeEntry(p, c.get.cssColor()))

proc applyLengthHint(ctx: var ApplyValueContext; p: CSSPropertyType;
    unit: CSSUnit; u: uint32) =
  let length = resolveLength(unit, float32(u), ctx.window.settings.attrsp[])
  ctx.applyPresHint(makeEntry(p, length))

proc applyPresHints(ctx: var ApplyValueContext; element: Element) =
  case element.tagType
  of TAG_TABLE:
    ctx.applyDimensionHintGz(cptWidth, element.attr(satWidth))
    ctx.applyDimensionHintGz(cptHeight, element.attr(satHeight))
    ctx.applyColorHint(cptBackgroundColor, element.attr(satBgcolor))
    let s = element.attrul(satCellspacing)
    if s.isOk:
      let n = cssLength(float32(s.get))
      ctx.applyPresHint(makeEntry(cptBorderSpacingInline, n))
      ctx.applyPresHint(makeEntry(cptBorderSpacingBlock, n))
  of TAG_TD, TAG_TH:
    ctx.applyDimensionHintGz(cptWidth, element.attr(satWidth))
    ctx.applyDimensionHintGz(cptHeight, element.attr(satHeight))
    ctx.applyColorHint(cptBackgroundColor, element.attr(satBgcolor))
    let colspan = element.attrulgz(satColspan).get(1001)
    if colspan < 1001:
      ctx.applyPresHint(makeEntry(cptChaColspan, int32(colspan)))
    let rowspan = element.attrul(satRowspan).get(65535)
    if rowspan < 65535:
      ctx.applyPresHint(makeEntry(cptChaRowspan, int32(rowspan)))
  of TAG_THEAD, TAG_TBODY, TAG_TFOOT, TAG_TR:
    ctx.applyDimensionHint(cptHeight, element.attr(satHeight))
    ctx.applyColorHint(cptBackgroundColor, element.attr(satBgcolor))
  of TAG_COL:
    ctx.applyDimensionHint(cptWidth, element.attr(satWidth))
  of TAG_IMG, TAG_CANVAS, TAG_SVG:
    ctx.applyDimensionHint(cptWidth, element.attr(satWidth))
    ctx.applyDimensionHint(cptHeight, element.attr(satHeight))
  of TAG_HTML:
    ctx.applyPresHint(makeEntry(cptBgcolorIsCanvas,
      CSSValueBit(bgcolorIsCanvas: true)))
  of TAG_BODY:
    ctx.applyPresHint(makeEntry(cptBgcolorIsCanvas,
      CSSValueBit(bgcolorIsCanvas: true)))
    ctx.applyColorHint(cptBackgroundColor, element.attr(satBgcolor))
    ctx.applyColorHint(cptColor, element.attr(satText))
  of TAG_TEXTAREA:
    let textarea = HTMLTextAreaElement(element)
    let cols = textarea.attrul(satCols).get(20)
    let rows = textarea.attrul(satRows).get(1)
    ctx.applyLengthHint(cptWidth, cuCh, cols)
    ctx.applyLengthHint(cptHeight, cuEm, rows)
  of TAG_FONT:
    ctx.applyColorHint(cptColor, element.attr(satColor))
  of TAG_INPUT:
    let input = HTMLInputElement(element)
    if input.inputType in InputTypeWithSize:
      let s = element.attrul(satSize)
      if s.isOk:
        ctx.applyLengthHint(cptWidth, cuCh, s.get)
  of TAG_SELECT:
    if element.attrb(satMultiple):
      let size = element.attrulgz(satSize).get(4)
      ctx.applyLengthHint(cptHeight, cuEm, size)
  of TAG_OL:
    if n := element.attrl(satStart):
      if n > int32.low:
        let n = n - 1
        let val = CSSValue(
          v: cvtCounterSet,
          counterSet: @[CSSCounterSet(name: satListItem.toAtom(), num: n)]
        )
        ctx.applyPresHint(makeEntry(cptCounterReset, val))
  of TAG_LI:
    if n := element.attrl(satValue):
      let val = CSSValue(
        v: cvtCounterSet,
        counterSet: @[CSSCounterSet(name: satListItem.toAtom(), num: n)]
      )
      ctx.applyPresHint(makeEntry(cptCounterSet, val))
  else: discard

proc applyDeclarations(rules: RuleList; parent, element: Element;
    window: Window): CSSValues =
  result = CSSValues()
  var parentVars: CSSVariableMap = nil
  var ctx = ApplyValueContext(window: window, vals: result)
  if parent != nil:
    if parent.computed == nil:
      parent.applyStyle()
    ctx.parentComputed = parent.computed
    parentVars = ctx.parentComputed.vars
  for origin in CSSOrigin:
    if rules[origin].importantVars.len > 0:
      if result.vars == nil:
        result.vars = newCSSVariableMap(parentVars)
      for i in countdown(rules[origin].importantVars.high, 0):
        let cvar = rules[origin].importantVars[i]
        result.vars.putIfAbsent(cvar.name, cvar)
  for origin in countdown(CSSOrigin.high, CSSOrigin.low):
    if rules[origin].normalVars.len > 0:
      if result.vars == nil:
        result.vars = newCSSVariableMap(parentVars)
      for i in countdown(rules[origin].normalVars.high, 0):
        let cvar = rules[origin].normalVars[i]
        result.vars.putIfAbsent(cvar.name, cvar)
  if result.vars == nil:
    result.vars = parentVars # inherit parent
  for entry in rules[coUserAgent].normal: # user agent
    ctx.applyValue(entry, itOther, {itUserAgent, itUser})
  let uaProperties = result.copyProperties()
  # Presentational hints override user agent style, but respect user/author
  # style.
  if element != nil:
    ctx.applyPresHints(element)
  ctx.previousOrigin = uaProperties
  for entry in rules[coUser].normal:
    ctx.applyValue(entry, itUserAgent, {itUser})
  # save user properties so author can use them
  ctx.previousOrigin = result.copyProperties() # use user for author revert
  for entry in rules[coAuthor].normal:
    ctx.applyValue(entry, itUser, {itOther})
  for entry in rules[coAuthor].important:
    ctx.applyValue(entry, itUser, {itOther})
  ctx.previousOrigin = uaProperties # use UA for user important revert
  for entry in rules[coUser].important:
    ctx.applyValue(entry, itUserAgent, {itOther})
  ctx.previousOrigin = nil # reset origin for UA
  for entry in rules[coUserAgent].important:
    ctx.applyValue(entry, itUserAgent, {itOther})
  # fill in defaults
  for t in CSSPropertyType:
    if ctx.initMap[t] == {}:
      result.initialOrInheritFrom(ctx.parentComputed, t)
  # Quirk: it seems others aren't implementing what the spec says about
  # blockification.
  # Well, neither will I, because the spec breaks on actual websites.
  # Curse CSS.
  if result{"position"} in PositionAbsoluteFixed:
    if result{"display"} == DisplayInline:
      result{"display"} = DisplayInlineBlock
  elif result{"float"} != FloatNone or
      ctx.parentComputed != nil and
        ctx.parentComputed{"display"} in DisplayInnerFlex + DisplayInnerGrid:
    result{"display"} = result{"display"}.blockify()
  if (result{"overflow-x"} in {OverflowVisible, OverflowClip}) !=
      (result{"overflow-y"} in {OverflowVisible, OverflowClip}):
    result{"overflow-x"} = result{"overflow-x"}.bfcify()
    result{"overflow-y"} = result{"overflow-y"}.bfcify()

func hasValues(rules: RuleList): bool =
  for x in rules:
    if x.normal.len > 0 or x.important.len > 0:
      return true
  return false

proc applyStyle*(element: Element) =
  let document = element.document
  let window = document.window
  var depends = DependencyInfo.default
  var map = RuleListMap.default
  for sheet in document.uaSheets:
    map.calcRules(element, sheet, coUserAgent, depends)
  map.calcRules(element, document.userSheet, coUser, depends)
  for sheet in document.authorSheets:
    map.calcRules(element, sheet, coAuthor, depends)
  let style = element.cachedStyle
  if window.settings.styling and style != nil:
    for decl in style.decls:
      #TODO variables
      let vals = parseComputedValues(decl.name, decl.value,
        window.settings.attrsp[])
      if decl.important:
        map[peNone][coAuthor].important.add(vals)
      else:
        map[peNone][coAuthor].normal.add(vals)
  element.applyStyleDependencies(depends)
  element.computed =
    map[peNone].applyDeclarations(element.parentElement, element, window)
  assert element.computedMap.len == 0
  for pseudo in peBefore .. PseudoElement.high:
    if map[pseudo].hasValues() or window.settings.scripting == smApp:
      let computed = map[pseudo].applyDeclarations(element, nil, window)
      if pseudo == peMarker:
        computed{"display"} = DisplayMarker
      element.computedMap.add((pseudo, computed))

{.pop.} # raises: []
