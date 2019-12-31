import tables
import lists
import options
import macros, hashes

import common



type
  LRUCached*[A, B] = object
    map: Table[A, MapValue[A, B]]
    cached: CachedKeyPair[A, B]
    info: CachedInfo

  LFUCached*[A, B] = object
    map: Table[A, MapValue[A, B]]
    cached: Table[int, CachedKeyPair[A, B]]
    info: CachedInfo


proc initLruCached*[A, B](maxSize: Natural = 128): LRUCached[A, B] =
  LRUCached[A, B](map: initTable[A, MapValue[A, B]](),
      cached: initDoublyLinkedList[KeyPair[A, B]](), info: (hits: 0,
          misses: 0, maxSize: maxSize))

proc moveToFront*[A, B](x: var LRUCached[A, B], node: MapValue[A, B]) =
  x.cached.remove(node)
  x.cached.prepend(node)

proc get*[A, B](x: var LRUCached[A, B], key: A): Option[B] =
  if key in x.map:
    x.info.hits += 1
    let node = x.map[key]
    moveToFront(x, node)
    return some(node.value.valuePart)
  x.info.misses += 1
  return none(B)

proc put*[A, B](x: var LRUCached[A, B], key: A, value: B) =
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
    x.map.del(node.value.keyPart)


  let node = newDoublyLinkedNode((keyPart: key, valuePart: value))
  x.map[key] = node
  moveToFront(x, node)


proc `[]`*[A, B](x: var LRUCached[A, B], key: A): B =
  if key in x.map:
    x.info.hits += 1
    let node = x.map[key]
    moveToFront(x, node)
    return node.value.valuePart
  x.info.misses += 1

proc `[]=`*[A, B](x: var LRUCached[A, B], key: A, value: B) =
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
    x.map.del(node.value.keyPart)

  let node = newDoublyLinkedNode((keyPart: key, valuePart: value))
  x.map[key] = node
  moveToFront(x, node)

proc contains*[A, B](x: var LRUCached[A, B], key: A): bool =
  if key in x.map:
    return true
  else:
    return false


macro cached(x: untyped): untyped =
  for i in 0 ..< x.len:
    expectKind x[i], nnkProcDef

  result = newStmtList()

  for i in 0 ..< x.len:
    let
      funcStmt = x[i]
      funcName = funcStmt[0]
      funcRewriting = funcStmt[1] # for template or macro, should be nnkEmpty
      funcGenericParams = funcStmt[2]
      funcFormalParams = funcStmt[3]
      returnParams = funcFormalParams[0]
      funcPragma = funcStmt[4]
      funcReversed = funcStmt[5]  # reserved slot for future use, should be nnkEmpty
                                  # funcBody = funcStmt[6]


    let mainBody = newStmtList()
    mainBody.add newNimNode(nnkVarSection).add(newIdentDefs(newIdentNode("key"),
        newIdentNode("Hash")))


    var funcParamsNames: seq[NimNode]
    for i in 1 ..< funcFormalParams.len:
      funcParamsNames.add funcFormalParams[i][0]
      mainBody.add newAssignment(newIdentNode("key"), infix(newCall("hash",
          newIdentNode("key")), "!&", newCall("hash",
          funcFormalParams[i][0])))

    mainBody.add newAssignment(newIdentNode("key"), prefix(newIdentNode("key"), "!$"))
    mainBody.add newIfStmt((infix(newIdentNode("key"), "in", newIdentNode("table")),
              newStmtList(newCall(newIdentNode("echo"), newStrLitNode(
                  "I\'m cached")),
              newNimNode(nnkReturnStmt).add(newNimNode(nnkBracketExpr).add(
                  newIdentNode("table"), newIdentNode("key"))))))

    mainBody.add funcStmt
    mainBody.add newAssignment(newIdentNode("result"), newCall(funcName,
        funcParamsNames))
    mainBody.add newAssignment(newNimNode(nnkBracketExpr).add(
      newIdentNode("table"), newIdentNode("key")), newIdentNode("result"))

    var name = strVal(funcName) 
    name.add "_cached" 
    name.add "_xzs" 
    let wrapperNameNode = newIdentNode("wrapper" & name)
  
    let nameNode = newIdentNode(name)
    let main = newNimNode(nnkProcDef).add(
      wrapperNameNode,
      funcRewriting,
      funcGenericParams,
      funcFormalParams,
      funcPragma,
      funcReversed,
      mainBody
    )


    let body = newStmtList()
    body.add newVarStmt(newIdentNode("table"),
          newCall(newNimNode(nnkBracketExpr).add(newIdentNode("initLruCached"),
          newIdentNode("Hash"), returnParams)))
    body.add main
    body.add wrapperNameNode


    let templateBody = newNimNode(nnkTemplateDef).add(
      nameNode,
      newEmptyNode(),
      newEmptyNode(),
      newNimNode(nnkFormalParams).add(newIdentNode("untyped")),
      newEmptyNode(),
      newEmptyNode(),
      body
    )

    result.add templateBody
    result.add newLetStmt(newNimNode(nnkPragmaExpr).add(funcName,
        newNimNode(nnkPragma).add(newIdentNode("inject"))), newCall(nameNode))


cached:
  proc hello(a: int): string = 
    $a


when isMainModule:
  import random, timeit

  randomize(128)

  timeOnce("cached"):
    for i in 1 .. 100:
      echo hello(rand(100))
 
