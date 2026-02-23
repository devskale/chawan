{.push raises: [].}

import std/posix

import chagashi/charset
import chagashi/decoder
import config/mimetypes
import io/dynstream
import io/promise
import monoucha/fromjs
import monoucha/jsbind
import monoucha/jsutils
import monoucha/quickjs
import monoucha/tojs
import server/headers
import server/request
import types/blob
import types/jsopt
import types/opt
import types/referrer
import types/url
import utils/twtstr

type
  ResponseType* = enum
    rtDefault = "default"
    rtBasic = "basic"
    rtCors = "cors"
    rtError = "error"
    rtOpaque = "opaque"
    rtOpaquedirect = "opaqueredirect"

  ResponseFlag* = enum
    rfAborted

  Response* = ref object
    body*: PosixStream
    flags*: set[ResponseFlag]
    responseType* {.jsget: "type".}: ResponseType
    bodyUsed* {.jsget.}: bool
    status* {.jsget.}: uint16
    headers* {.jsget.}: Headers
    url*: URL #TODO should be urllist?
    resumeFun*: proc(outputId: int)
    onRead*: proc(response: Response) {.nimcall, raises: [].}
    onFinish*: proc(response: Response; success: bool) {.nimcall, raises: [].}
    outputId*: int
    opaque*: RootRef

  TextResult* = object
    isOk*: bool
    get*: string

  FetchPromise* = Promise[Response] # response may be nil

  BlobFinish* = proc(opaque: BlobOpaque; blob: Blob) {.nimcall, raises: [].}

  BlobOpaque = ref object of RootObj
    p: pointer
    len: int
    size: int
    finish: BlobFinish
    contentType: string

  JSBlobOpaque = ref object of BlobOpaque
    ctx: JSContext
    resolve: pointer # JSObject *
    reject: pointer # JSObject *

  NimBlobOpaque = ref object of BlobOpaque
    opaque: RootRef

jsDestructor(Response)

template resolveVal(this: BlobOpaque): JSValue =
  JS_MKPTR(JS_TAG_OBJECT, this.resolve)

template rejectVal(this: BlobOpaque): JSValue =
  JS_MKPTR(JS_TAG_OBJECT, this.reject)

proc finalize(rt: JSRuntime; this: Response) {.jsfin.} =
  if this.opaque of JSBlobOpaque:
    let opaque = JSBlobOpaque(this.opaque)
    if opaque.resolve != nil:
      JS_FreeValueRT(rt, opaque.resolveVal)
    if opaque.reject != nil:
      JS_FreeValueRT(rt, opaque.rejectVal)

proc mark(rt: JSRuntime; this: Response; fun: JS_MarkFunc) {.jsmark.} =
  if this.opaque of JSBlobOpaque:
    let opaque = JSBlobOpaque(this.opaque)
    if opaque.resolve != nil:
      JS_MarkValue(rt, opaque.resolveVal, fun)
    if opaque.reject != nil:
      JS_MarkValue(rt, opaque.rejectVal, fun)

template isErr*(x: TextResult): bool =
  not x.isOk

template ok*(t: typedesc[TextResult]; s: string): TextResult =
  TextResult(isOk: true, get: s)

template err*(t: typedesc[TextResult]): TextResult =
  TextResult()

proc toJS*(ctx: JSContext; x: TextResult): JSValue =
  if x.isOk:
    return ctx.toJS(x.get)
  return JS_ThrowTypeError(ctx, "error reading response body")

proc newResponse*(request: Request; stream: PosixStream; outputId: int):
    Response =
  return Response(
    url: if request != nil: request.url else: nil,
    body: stream,
    outputId: outputId,
    status: 200
  )

proc newResponse*(ctx: JSContext; body: JSValueConst = JS_UNDEFINED;
    init: JSValueConst = JS_UNDEFINED): Opt[Response] {.jsctor.} =
  if not JS_IsUndefined(body) or not JS_IsUndefined(init):
    #TODO
    JS_ThrowInternalError(ctx, "Response constructor with body or init")
    return err()
  return ok(newResponse(nil, nil, -1))

proc makeNetworkError*(): Response {.jsstfunc: "Response#error".} =
  #TODO use "create" function
  return Response(
    responseType: rtError,
    status: 0,
    headers: newHeaders(hgImmutable),
    bodyUsed: true
  )

proc jsOk(response: Response): bool {.jsfget: "ok".} =
  return response.status in 200u16 .. 299u16

proc surl*(response: Response): string {.jsfget: "url".} =
  if response.responseType == rtError or response.url == nil:
    return ""
  return $response.url

proc getCharset*(this: Response; fallback: Charset): Charset =
  let header = this.headers.getFirst("Content-Type").toLowerAscii()
  if header != "":
    let cs = header.getContentTypeAttr("charset").getCharset()
    if cs != CHARSET_UNKNOWN:
      return cs
  return fallback

proc getLongContentType*(this: Response; fallback: string): string =
  let header = this.headers.getFirst("Content-Type")
  if header != "":
    return header.toValidUTF8().strip()
  # also use DefaultGuess for container, so that local mime.types cannot
  # override buffer mime.types
  return DefaultGuess.guessContentType(this.url.pathname, fallback)

proc getContentType*(this: Response; fallback = "application/octet-stream"):
    string =
  return this.getLongContentType(fallback).untilLower(';')

proc getContentLength*(this: Response): int64 =
  let x = this.headers.getFirst("Content-Length")
  let u = parseUInt64(x.strip(), allowSign = false).get(uint64.high)
  if u <= uint64(int64.high):
    return int64(u)
  return -1

proc getReferrerPolicy*(this: Response): Opt[ReferrerPolicy] =
  for value in this.headers.getAllCommaSplit("Referrer-Policy"):
    if policy := parseEnumNoCase[ReferrerPolicy](value):
      return ok(policy)
  err()

proc resume*(response: Response) =
  response.resumeFun(response.outputId)
  response.resumeFun = nil

const BufferSize = 4096

proc onReadBlob(response: Response) =
  let opaque = BlobOpaque(response.opaque)
  while true:
    if opaque.len + BufferSize > opaque.size:
      opaque.size *= 2
      opaque.p = realloc(opaque.p, opaque.size)
    let p = cast[ptr UncheckedArray[uint8]](opaque.p)
    let diff = opaque.size - opaque.len
    let n = response.body.read(addr p[opaque.len], diff)
    if n <= 0:
      assert n != -1 or errno != EBADF
      break
    opaque.len += n

proc onFinishBlob(response: Response; success: bool) =
  let opaque = BlobOpaque(response.opaque)
  if success:
    let p = opaque.p
    opaque.p = nil
    let blob = if p == nil:
      newEmptyBlob(opaque.contentType)
    else:
      newBlob(p, opaque.len, opaque.contentType, deallocBlob)
    opaque.finish(opaque, blob)
  else:
    if opaque.p != nil:
      dealloc(opaque.p)
      opaque.p = nil
    opaque.finish(opaque, nil)

proc blob*(response: Response; opaque: BlobOpaque) =
  if response.bodyUsed:
    opaque.finish(opaque, nil)
    return
  if response.body == nil:
    response.bodyUsed = true
    opaque.finish(opaque, newEmptyBlob())
    return
  opaque.contentType = response.getContentType()
  opaque.p = alloc(BufferSize)
  opaque.size = BufferSize
  response.opaque = opaque
  response.onRead = onReadBlob
  response.onFinish = onFinishBlob
  response.bodyUsed = true
  response.resume()

proc legacyBlobFinish(opaque: BlobOpaque; blob: Blob) =
  let opaque = NimBlobOpaque(opaque)
  let promise = Promise[Blob](opaque.opaque)
  promise.resolve(blob)

proc blob*(response: Response): Promise[Blob] =
  let promise = Promise[Blob]()
  let opaque = NimBlobOpaque(
    finish: legacyBlobFinish,
    opaque: promise
  )
  response.blob(opaque)
  return promise

proc jsFinish0(opaque: JSBlobOpaque; val: JSValue) =
  let ctx = opaque.ctx
  let resolve = opaque.resolveVal
  let reject = opaque.rejectVal
  opaque.resolve = nil
  opaque.reject = nil
  opaque.ctx = nil
  if not JS_IsException(val):
    let res = ctx.callSink(resolve, JS_UNDEFINED, val)
    JS_FreeValue(ctx, res)
  else:
    let ex = JS_GetException(ctx)
    let res = ctx.callSink(reject, JS_UNDEFINED, ex)
    JS_FreeValue(ctx, res)
  JS_FreeValue(ctx, resolve)
  JS_FreeValue(ctx, reject)
  JS_FreeContext(ctx)

proc jsBlobFinish(opaque: BlobOpaque; blob: Blob) =
  let opaque = JSBlobOpaque(opaque)
  let ctx = opaque.ctx
  let val = if blob != nil:
    ctx.toJS(blob)
  else:
    JS_ThrowTypeError(ctx, "error reading response body")
  jsFinish0(opaque, val)

proc blob0(ctx: JSContext; response: Response; finish: BlobFinish): JSValue =
  var funs {.noinit.}: array[2, JSValue]
  let res = ctx.newPromiseCapability(funs)
  if JS_IsException(res):
    return res
  let opaque = JSBlobOpaque(
    ctx: JS_DupContext(ctx),
    resolve: JS_VALUE_GET_PTR(funs[0]),
    reject: JS_VALUE_GET_PTR(funs[1]),
    finish: finish
  )
  response.blob(opaque)
  return res

proc blob(ctx: JSContext; response: Response): JSValue {.jsfunc.} =
  return ctx.blob0(response, jsBlobFinish)

proc text*(response: Response): Promise[TextResult] =
  return response.blob().then(proc(blob: Blob): TextResult =
    if blob == nil:
      return TextResult.err()
    TextResult.ok(blob.toOpenArray().toValidUTF8())
  )

proc jsTextFinish(opaque: BlobOpaque; blob: Blob) =
  let opaque = JSBlobOpaque(opaque)
  let ctx = opaque.ctx
  let val = if blob != nil:
    ctx.toJS(blob.toOpenArray().toValidUTF8())
  else:
    JS_ThrowTypeError(ctx, "error reading response body")
  jsFinish0(opaque, val)

proc text(ctx: JSContext; response: Response): JSValue {.jsfunc.} =
  return ctx.blob0(response, jsTextFinish)

proc cssDecode(iq: openArray[char]; fallback: Charset): string =
  var charset = fallback
  var offset = 0
  const charsetRule = "@charset \""
  if iq.startsWith("\xFE\xFF"):
    charset = CHARSET_UTF_16_BE
    offset = 2
  elif iq.startsWith("\xFF\xFE"):
    charset = CHARSET_UTF_16_LE
    offset = 2
  elif iq.startsWith("\xEF\xBB\xBF"):
    charset = CHARSET_UTF_8
    offset = 3
  elif iq.startsWith(charsetRule):
    let s = iq.toOpenArray(charsetRule.len, min(1024, iq.high)).until('"')
    let n = charsetRule.len + s.len
    if n >= 0 and n + 1 < iq.len and iq[n] == '"' and iq[n + 1] == ';':
      charset = getCharset(s)
      if charset in {CHARSET_UTF_16_LE, CHARSET_UTF_16_BE}:
        charset = CHARSET_UTF_8
  iq.toOpenArray(offset, iq.high).decodeAll(charset)

proc cssText*(response: Response; fallback: Charset): Promise[TextResult] =
  return response.blob().then(proc(blob: Blob): TextResult =
    if blob == nil:
      return TextResult.err()
    TextResult.ok(blob.toOpenArray().cssDecode(fallback))
  )

proc jsJsonFinish(opaque: BlobOpaque; blob: Blob) =
  let opaque = JSBlobOpaque(opaque)
  let ctx = opaque.ctx
  let val = if blob != nil:
    let s = blob.toOpenArray().toValidUTF8()
    JS_ParseJSON(ctx, cstring(s), csize_t(s.len), cstring"<input>")
  else:
    JS_ThrowTypeError(ctx, "error reading response body")
  jsFinish0(opaque, val)

proc json(ctx: JSContext; this: Response): JSValue {.jsfunc.} =
  return ctx.blob0(this, jsJsonFinish)

proc addResponseModule*(ctx: JSContext): JSClassID =
  return ctx.registerType(Response)

{.pop.} # raises: []
