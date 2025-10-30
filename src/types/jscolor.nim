{.push raises: [].}

import std/strutils

import monoucha/fromjs
import monoucha/quickjs
import monoucha/tojs
import types/color
import types/jsopt
import types/opt
import utils/twtstr

proc parseLegacyColor*(s: string): Result[RGBColor, cstring] =
  if s == "":
    return err(cstring"color value must not be the empty string")
  let s = s.strip(chars = AsciiWhitespace).toLowerAscii()
  if s == "transparent":
    return err(cstring"color must not be transparent")
  return ok(parseLegacyColor0(s))

proc toJS*(ctx: JSContext; rgb: RGBColor): JSValue =
  var res = "#"
  res.pushHex(rgb.r)
  res.pushHex(rgb.g)
  res.pushHex(rgb.b)
  return toJS(ctx, res)

proc fromJS*(ctx: JSContext; val: JSValueConst; res: var RGBColor):
    FromJSResult =
  var s: string
  ?ctx.fromJS(val, s)
  let x = parseLegacyColor(s)
  if x.isErr:
    JS_ThrowTypeError(ctx, x.error)
    return fjErr
  res = x.get
  fjOk

proc toJS*(ctx: JSContext; rgba: ARGBColor): JSValue =
  var res = "#"
  res.pushHex(rgba.r)
  res.pushHex(rgba.g)
  res.pushHex(rgba.b)
  res.pushHex(rgba.a)
  return toJS(ctx, res)

proc fromJS*(ctx: JSContext; val: JSValueConst; res: var ARGBColor):
    FromJSResult =
  if JS_IsNumber(val):
    # as hex
    return ctx.fromJS(val, uint32(res))
  # parse
  var s: string
  ?ctx.fromJS(val, s)
  if x := parseARGBColor(s):
    res = x
    return fjOk
  JS_ThrowTypeError(ctx, "unrecognized color")
  fjErr

{.pop.} # raises: []
