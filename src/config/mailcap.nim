# See https://www.rfc-editor.org/rfc/rfc1524

{.push raises: [].}

import std/os
import std/posix

import io/chafile
import io/dynstream
import types/opt
import types/url
import utils/myposix
import utils/twtstr

type
  MailcapParser* = object
    line: int
    error*: string

  MailcapFlag* = enum
    mfNeedsterminal = "needsterminal"
    mfCopiousoutput = "copiousoutput"
    mfHtmloutput = "x-htmloutput" # from w3m
    mfAnsioutput = "x-ansioutput" # Chawan extension
    mfSaveoutput = "x-saveoutput" # Chawan extension
    mfNeedsstyle = "x-needsstyle" # Chawan extension
    mfNeedsimage = "x-needsimage" # Chawan extension

  MailcapEntry* = object
    t*: string
    cmd*: string
    flags*: set[MailcapFlag]
    nametemplate*: string
    edit*: string
    test*: string

  Mailcap* = seq[MailcapEntry]

  AutoMailcap* = object
    path*: string
    entries*: Mailcap

proc `$`*(entry: MailcapEntry): string =
  var s = entry.t & ';' & entry.cmd
  for flag in MailcapFlag:
    if flag in entry.flags:
      s &= ';' & $flag
  if entry.nametemplate != "":
    s &= ";nametemplate=" & entry.nametemplate
  if entry.edit != "":
    s &= ";edit=" & entry.edit
  if entry.test != "":
    s &= ";test=" & entry.test
  s &= '\n'
  move(s)

template err(state: MailcapParser; msg: string): untyped =
  state.error = msg
  err()

proc consumeTypeField(state: var MailcapParser; line: openArray[char];
    outs: var string): Opt[int] =
  var nslash = 0
  var n = 0
  while n < line.len:
    let c = line[n]
    if c in AsciiWhitespace + {';'}:
      break
    if c == '/':
      inc nslash
    elif c notin AsciiAlphaNumeric + {'-', '.', '*', '_', '+'}:
      return state.err("invalid character in type field: " & c)
    outs &= c.toLowerAscii()
    inc n
  if nslash == 0:
    # Accept types without a subtype - RFC calls this "implicit-wild".
    outs &= "/*"
  if nslash > 1:
    return state.err("too many slash characters")
  n = line.skipBlanks(n)
  if n >= line.len or line[n] != ';':
    return state.err("semicolon not found")
  ok(n + 1)

proc consumeCommand(state: var MailcapParser; line: string;
    outs: var string; n: int): Opt[int] =
  var n = line.skipBlanks(n)
  var quoted = false
  while n < line.len:
    let c = line[n]
    if not quoted:
      if c == '\r':
        continue
      if c == ';':
        return ok(n)
      if c == '\\':
        quoted = true
        # fall through; backslash will be parsed again in unquoteCommand
      elif c in Controls:
        return state.err("invalid character in command: " & c)
    else:
      quoted = false
    outs &= c
    inc n
  ok(n)

type NamedField = enum
  nmTest = "test"
  nmNametemplate = "nametemplate"
  nmEdit = "edit"

proc consumeField(state: var MailcapParser; line: string;
    entry: var MailcapEntry; n: int): Opt[int] =
  var n = line.skipBlanks(n)
  var s = ""
  while n < line.len:
    let c = line[n]
    inc n
    case c
    of ';':
      break
    of '\r':
      continue
    of '=':
      var cmd = ""
      n = ?state.consumeCommand(line, cmd, n)
      while s.len > 0 and s[^1] in AsciiWhitespace:
        s.setLen(s.len - 1)
      if x := parseEnumNoCase[NamedField](s):
        case x
        of nmTest: entry.test = move(cmd)
        of nmNametemplate: entry.nametemplate = move(cmd)
        of nmEdit: entry.edit = move(cmd)
      return ok(n)
    elif c in Controls:
      return state.err("invalid character in field: " & c)
    else:
      s &= c
  while s.len > 0 and s[^1] in AsciiWhitespace:
    s.setLen(s.len - 1)
  if x := parseEnumNoCase[MailcapFlag](s):
    entry.flags.incl(x)
  return ok(n)

proc parseEntry*(state: var MailcapParser; line: string;
    entry: var MailcapEntry): Opt[void] =
  var n = ?state.consumeTypeField(line, entry.t)
  n = ?state.consumeCommand(line, entry.cmd, n)
  while n < line.len:
    n = ?state.consumeField(line, entry, n)
  ok()

proc parseBuiltin*(mailcap: var Mailcap; buf: openArray[char]) =
  var state = MailcapParser(line: 1)
  for line in buf.split('\n'):
    if line.len <= 0:
      continue
    var entry: MailcapEntry
    let res = state.parseEntry(line, entry)
    doAssert res.isOk, state.error
    mailcap.add(entry)

proc parseMailcap(state: var MailcapParser; mailcap: var Mailcap;
    file: ChaFile): Opt[void] =
  var line: string
  while file.readLine(line).get(false):
    if line.len <= 0 or line[0] == '#':
      continue
    while true:
      if line.len > 0 and line[^1] == '\r':
        line.setLen(line.high)
      if line.len == 0 or line[^1] != '\\':
        break
      line.setLen(line.high) # trim backslash
      if not ?file.readLineAppend(line):
        break
    var entry: MailcapEntry
    ?state.parseEntry(line, entry)
    mailcap.add(entry)
    inc state.line
  return ok()

proc parseMailcap*(mailcap: var Mailcap; path: string): Err[string] =
  let file0 = chafile.fopen(path, "r")
  if file0.isErr:
    return ok()
  let file = file0.get
  var state = MailcapParser(line: 1)
  let res = state.parseMailcap(mailcap, file)
  file.close()
  if res.isErr:
    return err(path & '(' & $state.line & "): " & msg)
  ok()

# Mostly based on w3m's mailcap quote/unquote
type UnquoteState = enum
  usNormal, usQuoted, usPerc, usAttr, usAttrQuoted, usDollar

type UnquoteResult* = object
  canpipe*: bool
  cmd*: string

type QuoteState* = enum
  qsNormal, qsDoubleQuoted, qsSingleQuoted

proc quoteFile*(file: string; qs: QuoteState): string =
  var s = ""
  for c in file:
    case c
    of '$', '`', '"', '\\':
      if qs != qsSingleQuoted:
        s &= '\\'
    of '\'':
      if qs == qsSingleQuoted:
        s &= "'\\'" # then re-open the quote by appending c
      elif qs == qsNormal:
        s &= '\\'
      # double-quoted: append normally
    of AsciiAlphaNumeric, '_', '.', ':', '/':
      discard # no need to quote
    elif qs == qsNormal:
      s &= '\\'
    s &= c
  move(s)

proc unquoteCommand*(ecmd, contentType, outpath: string; url: URL;
    canpipe: var bool; line = -1): string =
  var cmd = ""
  var attrname = ""
  var state = usNormal
  var qss = @[qsNormal] # quote state stack. len >1
  template qs: var QuoteState = qss[^1]
  for c in ecmd:
    case state
    of usQuoted:
      cmd &= c
      state = usNormal
    of usAttrQuoted:
      attrname &= c.toLowerAscii()
      state = usAttr
    of usNormal, usDollar:
      let prevDollar = state == usDollar
      state = usNormal
      case c
      of '%':
        state = usPerc
      of '\\':
        state = usQuoted
      of '\'':
        if qs == qsSingleQuoted:
          qs = qsNormal
        else:
          qs = qsSingleQuoted
        cmd &= c
      of '"':
        if qs == qsDoubleQuoted:
          qs = qsNormal
        else:
          qs = qsDoubleQuoted
        cmd &= c
      of '$':
        if qs != qsSingleQuoted:
          state = usDollar
        cmd &= c
      of '(':
        if prevDollar:
          qss.add(qsNormal)
        cmd &= c
      of ')':
        if qs != qsSingleQuoted:
          if qss.len > 1:
            qss.setLen(qss.len - 1)
          else:
            # mismatched parens; probably an invalid shell command...
            qss[0] = qsNormal
        cmd &= c
      else:
        cmd &= c
    of usPerc:
      case c
      of '%': cmd &= c
      of 's':
        cmd &= quoteFile(outpath, qs)
        canpipe = false
      of 't':
        cmd &= quoteFile(contentType.until(';'), qs)
      of 'u': # Netscape extension
        if url != nil: # nil in getEditorCommand
          cmd &= quoteFile($url, qs)
      of 'd': # line; not used in mailcap, only in getEditorCommand
        if line != -1: # -1 in mailcap
          cmd &= $line
      of '{':
        state = usAttr
        continue
      else: discard
      state = usNormal
    of usAttr:
      if c == '}':
        let s = contentType.getContentTypeAttr(attrname)
        cmd &= quoteFile(s, qs)
        attrname = ""
        state = usNormal
      elif c == '\\':
        state = usAttrQuoted
      else:
        attrname &= c
  move(cmd)

proc unquoteCommand*(ecmd, contentType, outpath: string; url: URL): string =
  var canpipe: bool
  return unquoteCommand(ecmd, contentType, outpath, url, canpipe)

proc checkEntry(entry: MailcapEntry; contentType, mt, st: string; url: URL):
    bool =
  if not entry.t.startsWith("*/") and not entry.t.startsWithIgnoreCase(mt) or
      not entry.t.endsWith("/*") and not entry.t.endsWithIgnoreCase(st):
    return false
  if entry.test != "":
    var canpipe = true
    let cmd = unquoteCommand(entry.test, contentType, "", url, canpipe)
    return canpipe and myposix.system(cstring(cmd)) == 0
  true

proc findPrevMailcapEntry*(mailcap: Mailcap; contentType: string; url: URL;
    last: int): int =
  let mt = contentType.until('/') & '/'
  let st = contentType.until(AsciiWhitespace + {';'}, mt.len - 1)
  for i in countdown(last - 1, 0):
    if checkEntry(mailcap[i], contentType, mt, st, url):
      return i
  return -1

proc findMailcapEntry*(mailcap: Mailcap; contentType: string; url: URL;
    start = -1): int =
  let mt = contentType.until('/') & '/'
  let st = contentType.until(AsciiWhitespace + {';'}, mt.len - 1)
  for i in start + 1 ..< mailcap.len:
    if checkEntry(mailcap[i], contentType, mt, st, url):
      return i
  return -1

proc saveEntry*(mailcap: var Mailcap; path: string; entry: MailcapEntry):
    Opt[void] =
  let s = $entry
  let pdir = path.parentDir()
  discard mkdir(cstring(pdir), 0o700)
  let ps = newPosixStream(path, O_WRONLY or O_APPEND or O_CREAT, 0o644)
  if ps == nil:
    return err()
  let res = ps.writeLoop(s)
  if res.isOk:
    mailcap.add(entry)
  ps.sclose()
  res

{.pop.} # raises: []
