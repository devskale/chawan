{.push raises: [].}

from std/os import parentDir

{.used.}
# used so that we can import it from libregexp.nim

when not compileOption("threads"):
  const CFLAGS = "-O2 -fwrapv -DMNC_NO_THREADS"
else:
  const CFLAGS = "-O2 -fwrapv"

{.compile("qjs/libunicode.c", CFLAGS).}
{.compile("qjs/cutils.c", CFLAGS).}

const luheader = "qjs/libunicode.h"

type
  DynBufReallocFunc = proc(opaque, p: pointer; size: csize_t): pointer {.cdecl.}

  CharRange* {.importc, header: luheader.} = object
    len*: cint # in points, always even
    size*: cint
    points*: ptr uint32 # points sorted by increasing value
    mem_opaque*: pointer
    realloc_func*: DynBufReallocFunc

  UnicodeNormalizationEnum* {.size: sizeof(cint).} = enum
    UNICODE_NFC, UNICODE_NFD, UNICODE_NKFC, UNICODE_NKFD

  JS_BOOL* {.importc: "bool".} = bool

{.passc: "-I" & currentSourcePath().parentDir().}

{.push header: luheader, importc.}

proc cr_init*(cr: ptr CharRange; mem_opaque: pointer;
  realloc_func: DynBufReallocFunc)

proc cr_free*(cr: ptr CharRange)

# conv_type:
# 0 = to upper
# 1 = to lower
# 2 = case folding
# res must be an array of LRE_CC_RES_LEN_MAX
proc lre_case_conv*(res: ptr UncheckedArray[uint32]; c: uint32;
  conv_type: cint): cint

proc unicode_normalize*(pdst: ptr ptr uint32; src: ptr uint32; src_len: cint;
  n_type: UnicodeNormalizationEnum; opaque: pointer;
  realloc_func: DynBufReallocFunc): cint

proc unicode_script*(cr: ptr CharRange; script_name: cstring; is_ext: JS_BOOL):
  cint
proc unicode_prop*(cr: ptr CharRange; prop_name: cstring): cint
proc unicode_general_category*(cr: ptr CharRange; gc_name: cstring): cint
{.pop.} # header, importc
{.pop.} # raises
