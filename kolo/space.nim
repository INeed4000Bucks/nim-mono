import base

type
  Block* = ref object
    id*:      string
    version*: int
    tags*:    seq[string]
    links*:   seq[(string, string)]
    glinks*:  seq[string]
    text*:    string
    warns*:   seq[string]

  Doc* = ref object of RootObj
    id*:       string
    version*:  int
    title*:    string
    blocks*:   seq[Block]
    warns*:    seq[string]

  Space* = ref object
    id*:           string
    version*:      int
    docs*:         Table[string, Doc]
    warnings*:     seq[string]
    processors*:   seq[proc()]
    bgjobs*:       seq[proc()]
    allowed_tags*: HashSet[string]

  Db* = ref object
    version*:  int
    pversion*: int
    spaces*:   Table[string, Space]

proc init*(_: type[Space], id: string, version = 0): Space =
  Space(id: id, version: version)

proc link_to_s*(link: (string, string)): string =
  if link[0] == ".": link[1] else: link[0] & "/" & link[1]

iterator blocks*(space: Space): Block =
  for id, doc in space.docs:
    for blk in doc.blocks:
      yield blk

proc validate_tags*(space: Space) =
  if not space.allowed_tags.is_empty:
    for blk in space.blocks:
      for tag in blk.tags:
        if tag notin space.allowed_tags:
          blk.warns.add fmt"Invalid tag: {tag}"

proc validate_links*(space: Space, db: Db) =
  for blk in space.blocks:
    for link in blk.links:
      let (sid, did) = link
      if sid == ".":
        if did notin space.docs:
          blk.warns.add fmt"Invalid link: {link.link_to_s}"
      else:
        if sid notin db.spaces:
          blk.warns.add fmt"Invalid link: {link.link_to_s}"
        else:
          if did notin space.docs:
            blk.warns.add fmt"Invalid link: {link.link_to_s}"

proc process*(db: Db) =
  if db.version != db.pversion:
    for sid, space in db.spaces:
      space.validate_tags
      space.validate_links db
      for fn in space.processors: fn()
  db.pversion = db.version

proc bg*(db: Db) =
  for sid, space in db.spaces:
    for fn in space.bgjobs: fn()