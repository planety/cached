import lists

type
  CachedPolicy* = enum
    lru

  CachedInfo* = tuple
    hits: int
    misses: int
    maxSize: int

  KeyPair*[A, B] = tuple
    keyPart: A
    valuePart: B

  CachedKeyPair*[A, B] = DoublyLinkedList[KeyPair[A, B]]
  MapValue*[A, B] = DoublyLinkedNode[KeyPair[A, B]]