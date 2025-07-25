{.push raises: [].}

import std/options
import std/strutils
import std/tables

import chame/tags
import css/cssparser
import css/cssvalues
import css/mediaquery
import html/catom
import html/script
import types/opt
import types/url

type
  CSSRuleDef* = ref object
    sels*: SelectorList
    specificity*: int
    normalVals*: seq[CSSComputedEntry]
    importantVals*: seq[CSSComputedEntry]
    normalVars*: seq[CSSVariable]
    importantVars*: seq[CSSVariable]
    # Absolute position in the stylesheet; used for sorting rules after
    # retrieval from the cache.
    idx*: int

  CSSStylesheet* = ref object
    tagTable*: Table[CAtom, seq[CSSRuleDef]]
    idTable*: Table[CAtom, seq[CSSRuleDef]]
    classTable*: Table[CAtom, seq[CSSRuleDef]]
    attrTable*: Table[CAtom, seq[CSSRuleDef]]
    rootList*: seq[CSSRuleDef]
    generalList*: seq[CSSRuleDef]
    importList*: seq[URL]
    len: int
    settings: ptr EnvironmentSettings

  SelectorHashes = object
    tags: seq[CAtom]
    id: CAtom
    class: CAtom
    attr: CAtom
    root: bool

# Forward declarations
proc getSelectorIds(hashes: var SelectorHashes; sel: Selector): bool
proc addRule(sheet: CSSStylesheet; rule: CSSQualifiedRule)
proc addAtRule(sheet: CSSStylesheet; atrule: CSSAtRule; base: URL)

proc getSelectorIds(hashes: var SelectorHashes; sels: CompoundSelector) =
  for sel in sels:
    if hashes.getSelectorIds(sel):
      break

proc getSelectorIds(hashes: var SelectorHashes; cxsel: ComplexSelector) =
  hashes.getSelectorIds(cxsel[^1])

proc getSelectorIds(hashes: var SelectorHashes; sel: Selector): bool =
  case sel.t
  of stType:
    hashes.tags.add(sel.tag)
    return true
  of stClass:
    hashes.class = sel.class
    return true
  of stId:
    hashes.id = sel.id
    return true
  of stAttr:
    hashes.attr = sel.attr
    return true
  of stPseudoElement, stUniversal:
    return false
  of stPseudoClass:
    case sel.pseudo.t
    of pcRoot:
      hashes.root = true
      return true
    of pcLink, pcVisited:
      hashes.tags.add(TAG_A.toAtom())
      hashes.tags.add(TAG_AREA.toAtom())
      hashes.attr = satHref.toAtom()
      return true
    of pcIs, pcWhere:
      # Hash whatever the selectors have in common:
      # 1. get the hashable values of selector 1
      # 2. for each other selector x:
      # 3.   get hashable values of selector x
      # 4.   store hashable values of selector x that aren't stored yet
      # 5.   for each hashable value of selector 1 that doesn't match selector x
      # 6.     cancel hashable value
      var cancelId = false
      var cancelClass = false
      var cancelAttr = false
      var cancelRoot = false
      var i = 0
      if i < sel.pseudo.fsels.len:
        hashes.getSelectorIds(sel.pseudo.fsels[i])
        inc i
      while i < sel.pseudo.fsels.len:
        var nhashes = SelectorHashes()
        nhashes.getSelectorIds(sel.pseudo.fsels[i])
        hashes.tags.add(nhashes.tags)
        if hashes.id == CAtomNull:
          hashes.id = nhashes.id
        elif nhashes.id != CAtomNull and nhashes.id != hashes.id:
          cancelId = true
        if hashes.class == CAtomNull:
          hashes.class = nhashes.class
        elif nhashes.class != CAtomNull and nhashes.class != hashes.class:
          cancelClass = true
        if hashes.attr == CAtomNull:
          hashes.attr = nhashes.attr
        elif nhashes.attr != CAtomNull and nhashes.attr != hashes.attr:
          cancelAttr = true
        if hashes.root != nhashes.root:
          cancelRoot = true
        inc i
      if cancelId:
        hashes.id = CAtomNull
      if cancelClass:
        hashes.class = CAtomNull
      if cancelAttr:
        hashes.attr = CAtomNull
      if cancelRoot:
        hashes.root = false
      return hashes.tags.len > 0 or hashes.id != CAtomNull or
        hashes.class != CAtomNull or hashes.attr != CAtomNull or
        hashes.root
    else:
      return false

proc add(sheet: CSSStylesheet; rule: CSSRuleDef) =
  for cxsel in rule.sels:
    var hashes = SelectorHashes()
    hashes.getSelectorIds(cxsel)
    if hashes.tags.len > 0:
      for tag in hashes.tags:
        sheet.tagTable.withValue(tag, p):
          if p[][^1] != rule:
            p[].add(rule)
        do:
          sheet.tagTable[tag] = @[rule]
    elif hashes.id != CAtomNull:
      sheet.idTable.mgetOrPut(hashes.id, @[]).add(rule)
    elif hashes.class != CAtomNull:
      sheet.classTable.mgetOrPut(hashes.class, @[]).add(rule)
    elif hashes.attr != CAtomNull:
      sheet.attrTable.mgetOrPut(hashes.attr, @[]).add(rule)
    elif hashes.root:
      sheet.rootList.add(rule)
    else:
      sheet.generalList.add(rule)

proc addRules(sheet: CSSStylesheet; ctx: var CSSParser; topLevel: bool;
    base: URL) =
  for rule in ctx.parseListOfRules(topLevel):
    if rule of CSSAtRule:
      sheet.addAtRule(CSSAtRule(rule), base)
    else:
      sheet.addRule(CSSQualifiedRule(rule))

proc addRule(sheet: CSSStylesheet; rule: CSSQualifiedRule) =
  if rule.sels.len > 0:
    let ruleDef = CSSRuleDef(sels: move(rule.sels), idx: sheet.len)
    for decl in rule.decls:
      if decl.name.startsWith("--"):
        let cvar = CSSVariable(
          name: decl.name.toOpenArray(2, decl.name.high).toAtom(),
          toks: decl.value
        )
        if decl.important:
          ruleDef.importantVars.add(cvar)
        else:
          ruleDef.normalVars.add(cvar)
      else:
        if decl.important:
          let olen = ruleDef.importantVals.len
          if ruleDef.importantVals.parseComputedValues(decl.name, decl.value,
              sheet.settings.attrsp[]).isErr:
            ruleDef.importantVals.setLen(olen)
        else:
          let olen = ruleDef.normalVals.len
          if ruleDef.normalVals.parseComputedValues(decl.name, decl.value,
              sheet.settings.attrsp[]).isErr:
            ruleDef.normalVals.setLen(olen)
    sheet.add(ruleDef)
    inc sheet.len

proc addAtRule(sheet: CSSStylesheet; atrule: CSSAtRule; base: URL) =
  case atrule.name
  of cartUnknown: discard
  of cartImport:
    if sheet.len == 0 and base != nil:
      var i = atrule.prelude.skipBlanks(0)
      # Warning: this is a tracking vector minefield. If you implement
      # media query based imports, make sure to not filter here, but in
      # DOM after the sheet has been downloaded. (e.g. importList can
      # get a "media" field, etc.)
      if i < atrule.prelude.len:
        if (let url = cssURL(atrule.prelude[i]); url.isSome):
          if (let url = parseURL(url.get, some(base)); url.isSome):
            i = atrule.prelude.skipBlanks(i + 1)
            # check if there are really no media queries/layers/etc
            if i == atrule.prelude.len:
              sheet.importList.add(url.get)
  of cartMedia:
    if atrule.oblock != nil:
      let query = parseMediaQueryList(atrule.prelude, sheet.settings.attrsp)
      if query.applies(sheet.settings):
        var ctx = initCSSParser(atrule.oblock.value)
        sheet.addRules(ctx, topLevel = false, base = nil)

proc parseStylesheet*(iq: openArray[char]; base: URL;
    settings: ptr EnvironmentSettings): CSSStylesheet =
  let sheet = CSSStylesheet(settings: settings)
  var ctx = initCSSParser(iq)
  sheet.addRules(ctx, topLevel = true, base)
  return sheet

{.pop.} # raises: []
