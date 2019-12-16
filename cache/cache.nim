import tables
import lists
import options

import common


type
  CachedTable*[A, B] = object
    map: Table[A, MapValue[A, B]]
    cached: CachedKeyPair[A, B]
    info: CachedInfo


proc initCachedTable*[A, B](maxSize: int = 128): CachedTable[A, B] =
  CachedTable[A, B](map: initTable[A, MapValue[A, B]](),
      cached: initDoublyLinkedList[KeyPair[A, B]](), info: (hits: 0,
          misses: 0, maxSize: maxSize))

proc moveToFront*[A, B](x: var CachedTable[A, B], node: MapValue[A, B]) =
  x.cached.remove(node)
  x.cached.prepend(node)

proc get*[A, B](x: var CachedTable[A, B], key: A): Option[B] =
  if key in x.map:
    x.info.hits += 1
    let node = x.map[key]
    moveToFront(x, node)
    return some(node.value.valuePart)
  x.info.misses += 1
  return none(B)

proc put*[A, B](x: var CachedTable[A, B], key: A, value: B) =
  if key in x.map:
    x.info.hits += 1
    var node = x.map[key]
    node.value.valuePart = value
    moveToFront(x, node)
    return
  x.info.misses += 1
  if x.map.len >= x.info.maxSize:
    let node = x.cached.tail
    x.cached.remove(node)
    x.map.del(node.value.valuePart)

  let node = newDoublyLinkedNode((keyPart: key, valuePart: value))
  x.map[key] = node
  moveToFront(x, node)



when isMainModule:
  import random, timeit


  randomize(128)

  timeOnce("cached"):
    var s = initCachedTable[int, int](128)
    for i in 1 .. 100:
      s.put(rand(1 .. 126), rand(1 .. 126))
    s.put(5, 6)
    echo s.get(12)
    echo s.get(14).isNone
    echo s.get(5)
    echo s.info
    echo s.map.len
