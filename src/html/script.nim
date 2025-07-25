import config/conftypes
import monoucha/javascript
import monoucha/quickjs
import monoucha/tojs
import types/referrer
import types/url
import types/winattrs
import utils/twtstr

type
  ParserMetadata* = enum
    pmParserInserted, pmNotParserInserted

  ScriptType* = enum
    stClassic, stModule, stImportMap

  ScriptResultType* = enum
    srtNull, srtScript, srtImportMapParse, srtFetching

  RequestDestination* = enum
    rdNone = ""
    rdAudio = "audio"
    rdAudioworklet = "audioworklet"
    rdDocument = "document"
    rdEmbed = "embed"
    rdFont = "font"
    rdFrame = "frame"
    rdIframe = "iframe"
    rdImage = "image"
    rdJson = "json"
    rdManifest = "manifest"
    rdObject = "object"
    rdPaintworklet = "paintworklet"
    rdReport = "report"
    rdScript = "script"
    rdServiceworker = "serviceworker"
    rdSharedworker = "sharedworker"
    rdStyle = "style"
    rdTrack = "track"
    rdWorker = "worker"
    rdXslt = "xslt"

  CredentialsMode* = enum
    cmSameOrigin = "same-origin"
    cmOmit = "omit"
    cmInclude = "include"

type
  EnvironmentSettings* = ref object
    attrsp*: ptr WindowAttributes
    # In app mode, attrsp == scriptAttrsp.
    # In lite mode, scriptAttrsp == addr dummyAttrs.
    scriptAttrsp*: ptr WindowAttributes
    moduleMap*: ModuleMap
    origin*: Origin
    scripting*: ScriptingMode
    colorMode*: ColorMode
    headless*: HeadlessMode
    images*: bool
    styling*: bool
    autofocus*: bool

  Script* = ref object
    #TODO setings
    baseURL*: URL
    options*: ScriptOptions
    mutedErrors*: bool
    #TODO parse error/error to rethrow
    rt*: JSRuntime
    record*: JSValue

  ScriptOptions* = object
    nonce*: string
    integrity*: string
    parserMetadata*: ParserMetadata
    credentialsMode*: CredentialsMode
    referrerPolicy*: Option[ReferrerPolicy]
    renderBlocking*: bool

  ScriptResult* = ref object
    case t*: ScriptResultType
    of srtNull, srtFetching:
      discard
    of srtScript:
      script*: Script
    of srtImportMapParse:
      discard #TODO

  ModuleMapEntry = object
    key: tuple[url, moduleType: string]
    value*: ScriptResult

  ModuleMap* = seq[ModuleMapEntry]

# Forward declaration hack
# set in html/dom
var errorImpl*: proc(ctx: JSContext; ss: varargs[string]) {.
  nimcall, raises: [].}
var getEnvSettingsImpl*: proc(ctx: JSContext): EnvironmentSettings {.
  nimcall, raises: [].}
var storeJSImpl*: proc(ctx: JSContext; v: JSValue): int {.nimcall, raises: [].}
var fetchJSImpl*: proc(ctx: JSContext; n: int): JSValue {.nimcall, raises: [].}

proc toJS*(ctx: JSContext; val: ScriptingMode): JSValue =
  case val
  of smTrue: return JS_TRUE
  of smFalse: return JS_FALSE
  of smApp: return JS_NewString(ctx, "app")

proc free*(script: Script) =
  let record = script.record
  let rt = script.rt
  assert rt != nil
  script.record = JS_UNINITIALIZED
  script.rt = nil
  JS_FreeValueRT(rt, record)

proc clear*(moduleMap: var ModuleMap; rt: JSRuntime) =
  for it in moduleMap.mitems:
    if it.value.t == srtScript:
      it.value.script.free()
  moduleMap.setLen(0)

proc find(moduleMap: ModuleMap; url: URL; moduleType: string): int =
  let surl = $url
  for i, entry in moduleMap.mypairs:
    if entry.key.moduleType == moduleType and entry.key.url == surl:
      return i
  return -1

proc clone(script: Script): Script =
  return Script(
    baseURL: script.baseURL,
    options: script.options,
    mutedErrors: script.mutedErrors,
    #TODO parse error/error to rethrow
    rt: script.rt,
    record: JS_DupValueRT(script.rt, script.record)
  )

proc clone*(value: ScriptResult): ScriptResult =
  case value.t
  of srtScript:
    return ScriptResult(t: srtScript, script: value.script.clone())
  of srtNull, srtFetching:
    return value
  of srtImportMapParse:
    return ScriptResult(t: srtImportMapParse)

proc get*(moduleMap: ModuleMap; url: URL; moduleType: string): ScriptResult =
  let i = moduleMap.find(url, moduleType)
  if i == -1:
    return nil
  return moduleMap[i].value.clone()

proc set*(moduleMap: var ModuleMap; url: URL; moduleType: string;
    value: ScriptResult; ctx: JSContext) =
  let i = moduleMap.find(url, moduleType)
  if i != -1:
    let ovalue = moduleMap[i].value
    if ovalue.t == srtScript:
      ovalue.script.free()
    moduleMap[i].value = value
  else:
    moduleMap.add(ModuleMapEntry(key: ($url, moduleType), value: value))

func moduleTypeToRequestDest*(moduleType: string; default: RequestDestination):
    RequestDestination =
  if moduleType == "json":
    return rdJson
  if moduleType == "css":
    return rdStyle
  return default

proc newClassicScript*(ctx: JSContext; source: string; baseURL: URL;
    options: ScriptOptions; mutedErrors = false): ScriptResult =
  let urls = '<' & baseURL.serialize() & '>'
  let record = ctx.compileScript(source, urls)
  return ScriptResult(
    t: srtScript,
    script: Script(
      rt: JS_GetRuntime(ctx),
      record: record,
      baseURL: baseURL,
      options: options,
      mutedErrors: mutedErrors
    )
  )

proc newJSModuleScript*(ctx: JSContext; source: string; baseURL: URL;
    options: ScriptOptions): ScriptResult =
  let urls = baseURL.serialize(excludepassword = true)
  let record = ctx.compileModule(source, urls)
  return ScriptResult(
    t: srtScript,
    script: Script(
      rt: JS_GetRuntime(ctx),
      record: record,
      baseURL: baseURL,
      options: options
    )
  )

proc setImportMeta*(ctx: JSContext; funcVal: JSValue; isMain: bool) =
  let m = cast[JSModuleDef](JS_VALUE_GET_PTR(funcVal))
  let moduleNameAtom = JS_GetModuleName(ctx, m)
  let metaObj = JS_GetImportMeta(ctx, m)
  doAssert ctx.definePropertyCWE(metaObj, "url",
    JS_AtomToValue(ctx, moduleNameAtom)) == dprSuccess
  doAssert ctx.definePropertyCWE(metaObj, "main", false) == dprSuccess
  JS_FreeValue(ctx, metaObj)
  JS_FreeAtom(ctx, moduleNameAtom)

proc normalizeModuleName*(ctx: JSContext; base_name, name: cstringConst;
    opaque: pointer): cstring {.cdecl.} =
  return js_strdup(ctx, cstring(name))

proc finishLoadModule*(ctx: JSContext; source, name: string): JSModuleDef =
  let funcVal = compileModule(ctx, source, name)
  if JS_IsException(funcVal):
    return nil
  ctx.setImportMeta(funcVal, false)
  # "the module is already referenced, so we must free it"
  # idk how this works, so for now let's just do what qjs does
  result = cast[JSModuleDef](JS_VALUE_GET_PTR(funcVal))
  JS_FreeValue(ctx, funcVal)

proc logException*(ctx: JSContext) =
  ctx.errorImpl(ctx.getExceptionMsg())

func uninitIfNull*(val: JSValue): JSValue =
  if JS_IsNull(val):
    return JS_UNINITIALIZED
  return val

proc getEnvSettings*(ctx: JSContext): EnvironmentSettings =
  return ctx.getEnvSettingsImpl()

# Store and fetch JS objects that we may not be able to clean up
# immediately on free.  Gives/takes one refcount.
# fetchJS may return JS_UNINITIALIZED in case the value got freed before
# it was fetched.
proc storeJS*(ctx: JSContext; v: JSValue): int =
  return storeJSImpl(ctx, v)

proc fetchJS*(ctx: JSContext; n: int): JSValue =
  return fetchJSImpl(ctx, n)
