{.push raises: [].}

import std/posix
import std/strutils

import lcgi

proc sendCommand(f: AChaFile; cmd, param: string; outs: var string):
    Opt[int32] =
  if cmd != "":
    if param == "":
      ?f.writeCRLine(cmd)
    else:
      ?f.writeCRLine(cmd & ' ' & param)
    ?f.flush()
  var buf = newString(4)
  outs = ""
  var n = f.read(buf)
  if n < buf.len:
    return err()
  if not f.readLine(outs).get(false):
    return err()
  let status = parseInt32(buf.toOpenArray(0, 2)).get(-1)
  if buf[3] == ' ':
    return ok(status)
  buf[3] = ' '
  while true: # multiline
    var lbuf = ""
    if not f.readLine(lbuf).get(false):
      cgiDie(ceInvalidResponse)
    outs &= lbuf
    if lbuf.startsWith(buf):
      break
  ok(status)

proc sdie(status: int; s, obuf: string) {.noreturn.} =
  let stdout = cast[ChaFile](stdout)
  discard stdout.write("Status: " & $status &
    "\nContent-Type: text/html\n\n" & """
<h1>""" & s & """</h1>

The server has returned the following message:

<plaintext>
""" & obuf)
  quit(1)

const Success = 200 .. 299
proc passiveMode(f: AChaFile; host: string; ipv6: bool): PosixStream =
  var obuf = ""
  if ipv6:
    if f.sendCommand("EPSV", "", obuf).get(-1) != 229:
      cgiDie(ceInvalidResponse)
    var i = obuf.find('(')
    if i == -1:
      cgiDie(ceInvalidResponse)
    i += 4 # skip delims
    let j = obuf.find(')', i)
    if j == -1:
      cgiDie(ceInvalidResponse)
    let port = obuf.substr(i, j - 2)
    return connectSocket(host, port).orDie()
  if f.sendCommand("PASV", "", obuf).get(-1) notin Success:
    cgiDie(ceInvalidResponse, "couldn't enter passive mode")
  let i = obuf.find(AsciiDigit)
  if i == -1:
    cgiDie(ceInvalidResponse)
  var j = obuf.find(AllChars - AsciiDigit - {','}, i)
  if j == -1:
    j = obuf.len
  let ss = obuf.substr(i, j - 1).split(',')
  if ss.len < 6:
    cgiDie(ceInvalidResponse)
  var ipv4 = ss[0]
  for x in ss.toOpenArray(1, 3):
    ipv4 &= '.'
    ipv4 &= x
  let x = parseUInt16(ss[4])
  let y = parseUInt16(ss[5])
  if x.isErr or y.isErr:
    cgiDie(ceInvalidResponse)
  let port = $((x.get shl 8) or y.get)
  return connectSocket(host, port).orDie()

proc login(f: AChaFile; username, password: string): Opt[void] =
  var obuf = ""
  if f.sendCommand("", "", obuf).get(-1) != 220:
    let s = obuf.deleteChars({'\n', '\r'})
    cgiDie(ceConnectionRefused, cstring(s))
  var ustatus = f.sendCommand("USER", username, obuf).get(-1)
  if ustatus == 331:
    ustatus = f.sendCommand("PASS", password, obuf).get(-1)
  if ustatus in Success:
    discard # no need for pass
  else:
    sdie(401, "Unauthorized", obuf)
  discard ?f.sendCommand("TYPE", "I", obuf) # request raw data
  ok()

proc cat(passive: PosixStream): Opt[void] =
  let stdout = cast[ChaFile](stdout)
  ?stdout.flush()
  let os = newPosixStream(STDOUT_FILENO)
  var buffer {.noinit.}: array[4096, uint8]
  while true:
    let n = passive.readData(buffer)
    if n < 0:
      return err()
    if n == 0:
      break
    if not os.writeDataLoop(buffer.toOpenArray(0, n - 1)):
      return err()
  ok()

proc listDir(f: AChaFile; path, host: string; ipv6: bool): Opt[void] =
  let stdout = cast[ChaFile](stdout)
  let passive = f.passiveMode(host, ipv6)
  enterNetworkSandbox()
  var obuf = ""
  if f.sendCommand("LIST", "", obuf).isErr:
    passive.sclose()
    return err()
  let title = ("Index of " & path).mimeQuote()
  ?stdout.writeLine("Content-Type: text/x-dirlist;title=" & title & "\n\n")
  passive.cat()

proc retrieve(f: AChaFile; path, host: string; ipv6: bool): Opt[void] =
  let stdout = cast[ChaFile](stdout)
  let passive = f.passiveMode(host, ipv6)
  enterNetworkSandbox()
  var obuf = ""
  if f.sendCommand("RETR", path, obuf).get(550) == 550:
    passive.sclose()
    sdie(404, "Not found", obuf)
  ?stdout.writeLine()
  passive.cat()

proc main() =
  let stdout = cast[ChaFile](stdout)
  let host = getEnvEmpty("MAPPED_URI_HOST")
  let username = getEnvEmpty("MAPPED_URI_USERNAME")
  let password = getEnvEmpty("MAPPED_URI_PASSWORD")
  let port = getEnvEmpty("MAPPED_URI_PORT", "21")
  if getEnvEmpty("REQUEST_METHOD") != "GET":
    cgiDie(ceInvalidMethod)
  var ipv6: bool
  let ps = connectSocket(host, port, ipv6).orDie()
  let f = ps.afdopen("a+b").orDie(ceInternalError, "failed to open file")
  if f.login(username, password).isOk:
    var obuf = ""
    var path = percentDecode(getEnvEmpty("MAPPED_URI_PATH", "/"))
    let res = if f.sendCommand("CWD", path, obuf).get(-1) == 250:
      if path[^1] != '/':
        stdout.write("Status: 301\nLocation: " & path & "/\n")
      else:
        f.listDir(path, host, ipv6)
    else:
      f.retrieve(path, host, ipv6)
    if res.isOk:
      discard shutdown(SocketHandle(ps.fd), SHUT_RDWR)

main()

{.pop.} # raises: []
