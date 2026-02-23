{.push raises: [].}

import std/tables

type
  PromiseState = enum
    psPending, psFulfilled

  EmptyPromise* = ref object of RootObj
    cb: (proc() {.raises: [].})
    next: EmptyPromise
    state*: PromiseState

  Promise*[T] = ref object of EmptyPromise
    res*: T

proc resolve*(promise: EmptyPromise) =
  var promise = promise
  while true:
    if promise.cb != nil:
      promise.cb()
    promise.cb = nil
    promise.state = psFulfilled
    let next = promise.next
    promise.next = nil
    if next == nil:
      break
    promise = next

proc resolve*[T](promise: Promise[T]; res: T) =
  promise.res = res
  promise.resolve()

proc newResolvedPromise*(): EmptyPromise =
  let res = EmptyPromise()
  res.resolve()
  return res

proc newResolvedPromise*[T](x: T): Promise[T] =
  let res = Promise[T]()
  res.resolve(x)
  return res

proc then*(promise: EmptyPromise; cb: (proc() {.raises: [].})): EmptyPromise
    {.discardable.} =
  let next = EmptyPromise()
  promise.cb = cb
  promise.next = next
  if promise.state == psFulfilled:
    promise.resolve()
  next

proc then*(promise: EmptyPromise; cb: (proc(): EmptyPromise {.raises: [].})):
    EmptyPromise {.discardable.} =
  let next = EmptyPromise()
  promise.then(proc() =
    let p2 = cb()
    if p2 != nil:
      p2.next = next
    if p2 == nil or p2.state == psFulfilled:
      next.resolve())
  return next

proc then*[T](promise: Promise[T]; cb: (proc(x: T) {.raises: [].})):
    EmptyPromise {.discardable.} =
  return promise.then(proc() = cb(promise.res))

proc then*[T](promise: EmptyPromise; cb: (proc(): Promise[T] {.raises: [].})):
    Promise[T] {.discardable.} =
  let next = Promise[T]()
  promise.then(proc() =
    let p2 = cb()
    if p2 != nil:
      if p2.state == psFulfilled:
        next.res = p2.res
      else:
        p2.next = next
        p2.cb = proc() =
          next.res = p2.res
    if p2 == nil or p2.state == psFulfilled:
      next.resolve())
  next

proc then*[T](promise: Promise[T];
    cb: (proc(x: T): EmptyPromise {.raises: [].})): EmptyPromise
    {.discardable.} =
  let next = EmptyPromise()
  promise.then(proc(x: T) =
    let p2 = cb(x)
    if p2 != nil:
      p2.then(proc() = next.resolve())
    else:
      next.resolve())
  next

proc then*[T](promise: EmptyPromise; cb: (proc(): T {.raises: [].})): Promise[T]
    {.discardable.} =
  let next = Promise[T]()
  promise.next = next
  if promise.state == psFulfilled:
    next.res = cb()
    next.resolve()
  else:
    promise.cb = proc() =
      next.res = cb()
  next

proc then*[T, U: not void](promise: Promise[T];
    cb: (proc(x: T): U {.raises: [].})): Promise[U] {.discardable.} =
  let next = Promise[U]()
  promise.next = next
  if promise.state == psFulfilled:
    next.res = cb(promise.res)
    promise.resolve()
  else:
    promise.cb = proc() =
      next.res = cb(promise.res)
  next

proc then*[T, U](promise: Promise[T];
    cb: (proc(x: T): Promise[U] {.raises: [].})): Promise[U] {.discardable.} =
  let next = Promise[U]()
  promise.then(proc(x: T) =
    let p2 = cb(x)
    if p2 != nil:
      p2.then(proc(y: U) =
        next.res = y
        next.resolve())
    else:
      next.resolve())
  next

proc all*(promises: seq[EmptyPromise]): EmptyPromise =
  let res = EmptyPromise()
  var u = 0u
  let L = uint(promises.len)
  for promise in promises:
    promise.then(proc() =
      inc u
      if u == L:
        res.resolve()
    )
  if promises.len == 0:
    res.resolve()
  res

{.pop.} # raises: []
