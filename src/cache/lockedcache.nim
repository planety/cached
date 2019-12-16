import tables
import lists
import options, rlocks

import common


type
  LockedCachedTable*[A, B] = ref object
    map: Table[A, MapValue[A, B]]
    cached: CachedKeyPair[A, B]
    info: CachedInfo
    rlock: RLock


proc newCachedTable*[A, B](maxSize: int = 128): LockedCachedTable[A, B] =
  var rlock: RLock
  initRLock(rlock)
  LockedCachedTable[A, B](map: initTable[A, MapValue[A, B]](),
      cached: initDoublyLinkedList[KeyPair[A, B]](), info: (hits: 0,
          misses: 0, maxSize: maxSize), rlock: rlock)

proc moveToFront*[A, B](x: var LockedCachedTable[A, B], node: MapValue[A, B]) =
  x.cached.remove(node)
  x.cached.prepend(node)

proc get*[A, B](x: var LockedCachedTable[A, B], key: A): Option[B] =
  if key in x.map:
    withRLock x.rlock:
      x.info.hits += 1
      let node = x.map[key]
      moveToFront(x, node)
      return some(node.value.valuePart)
  withRLock x.rlock:
    x.info.misses += 1
  return none(B)

proc put*[A, B](x: var LockedCachedTable[A, B], key: A, value: B) =
  if key in x.map:
    withRLock x.rlock:
      x.info.hits += 1
      var node = x.map[key]
      node.value.valuePart = value
      moveToFront(x, node)
      return
  withRLock x.rlock:
    x.info.misses += 1

  if x.map.len >= x.info.maxSize:
    let node = x.cached.tail
    withRLock x.rlock:
      x.cached.remove(node)
      x.map.del(node.value.valuePart)

  withRLock x.rlock:
    let node = newDoublyLinkedNode((keyPart: key, valuePart: value))
    x.map[key] = node
    moveToFront(x, node)


when isMainModule:
  import random, timeit


  randomize(128)


  timeOnce("cached"):
    var s = newCachedTable[int, int](128)
    for i in 1 .. 100:
      s.put(rand(1 .. 126), rand(1 .. 126))
    s.put(5, 6)
    echo s.get(12)
    echo s.get(14).isNone
    echo s.get(5)
    echo s.info
    echo s.map.len
