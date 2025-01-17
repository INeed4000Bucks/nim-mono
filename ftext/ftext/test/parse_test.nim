import base, ext/parser, std/os
import ../model, ../parse

proc block_source(kind, text: string, args = ""): FBlockSource =
  FBlockSource(text: text, kind: kind, args: args)

proc test_space_location(): string =
  current_source_path().parent_dir.absolute_path

proc test_fdoc(): Doc =
  Doc(asset_path: fmt"{test_space_location()}/some".some)

template check_i(list, i, expected) =
  check list[i].to_json == expected.to_json

test "consume_tags":
  template t(a, b) =
    let pr = Parser.init(a.dedent)
    let (tags, lines, _) = pr.consume_tags
    check (tags, lines) == b

  t """
    #"a a"  #b, #д
  """, (@["a a", "b", "д"], (1, 1))

  t """
    some #a /link#hash ^text
  """, (@["a"], (1, 1))

  t """
    #a ^text #b
  """, (@["a", "b"], (1, 1))

template test_blocks(a, expected, tags) =
  let pr = Parser.init(a.dedent.trim)
  var parsed = pr.consume_blocks(@["section"])
  let (blk, parsed_tags, tag_lines) = pr.consume_doc_tags
  if blk.is_some: parsed.add blk.get
  check parsed.len == expected.len
  for i, parsed_i in parsed:
    check (parsed_i.kind, parsed_i.id, parsed_i.text, parsed_i.line_n) == expected[i]
  check (parsed_tags, tag_lines) == tags

test "consume_blocks, consume_tags":
  test_blocks """
    S t [s l](http://site.com) an t,
    same ^ par.

    Second 2^2 paragraph ^text

    - first m{2^a} line
    - second line ^list

    ^text

    first line

    second line ^list

    k: 1 ^id.data

    some text
    #tag #another ^text

    #tag #another tag
  """, @[
    ("text", "",   "S t [s l](http://site.com) an t,\nsame ^ par.\n\nSecond 2^2 paragraph", (1, 4)),
    ("list", "",   "- first m{2^a} line\n- second line", (6, 7)),
    ("text", "",   "", (9, 9)),
    ("list", "",   "first line\n\nsecond line", (11, 13)),
    ("data", "id", "k: 1", (15, 15)),
    ("text", "",   "some text\n#tag #another", (17, 18))
  ], (@["tag", "another"], (20, 20))

  test_blocks """
    some text ^text
  """, @[("text", "", "some text", (1, 1))], (seq[string].init, (1, 1))

test "consume_blocks with json attrs":
  check Parser.init("some ^text cards: { cols: 4 }").consume_blocks.to_json == %[
    { text: "some", id: "", args: "cards: { cols: 4 }", line_n: (1, 1), kind: "text"}
  ]

test "consume_blocks, should not consume embed as block attrs":
  check Parser.init("some ^text img{path}\nanother ^text").consume_blocks.to_json == %[
    { text: "some ^text img{path}\nanother", id: "", args: "", line_n: (1, 2), kind: "text" }
  ]

test "consume_blocks, consume_tags, with implicit text block":
  test_blocks """
    Some text

    Another

    #T

    Section
    #st ^id.section

    some text

    #T

    #dt
  """, @[
    ("text",    "",   "Some text\n\nAnother\n\n#T", (1, 5)),
    ("section", "id", "Section\n#st", (7, 8)),
    ("text",    "",   "some text\n\n#T", (10, 12)),
  ],
    (@["dt"], (14, 14)
  )

test "implicit text block, from error":
  test_blocks """
    Something
  """, @[
    ("text",    "",   "Something", (1, 1)),
  ],
    (@[], (-1, -1)
  )

test "text_embed":
  template t(a, i, b) =
    let pr = Parser.init(a); var items: Text
    check pr.is_text_embed == true
    pr.consume_text_embed items
    assert items.len == 1
    let item = items[i]
    check items[i].to_json == b.to_json

  t "math{2^{2} } other", 0, %{ text: "", kind: "embed", embed: { kind: "math", body: "2^{2} " } }
  t "`2^{2} ` other",     0, %{ text: "", kind: "embed", embed: { kind: "code", body: "2^{2} " } }

  check     Parser.init("i2{some}").is_text_embed # embed can have numbers
  check not Parser.init("2{some}").is_text_embed  # but can't start with number

test "consume_inline_text, space":
  check consume_inline_text("**a**b ").mapit(it.text) == @["a", "b"]
  check consume_inline_text("**a** b\n").mapit(it.text) == @["a", " b"]

test "parse_text":
  let config = FParseConfig.init

  let ftext = """
    Some text [some link](http://site.com) another **text,
    and [link 2]** more #tag1 image{img.png} some `code 2` some{some}


    - Line #lt1
    - Line 2 image{none.png}

    And #tag2 another
  """.dedent

  let blk = parse_text(block_source("text", ftext), test_fdoc(), config)
  check blk.warns == @["Unknown embed: some", "Asset doesn't exist: none.png"]

  let parsed = blk.ftext
  check parsed.len == 3

  block: # Paragraph 1
    check parsed[0].kind == text
    check parsed[0].text.len == 13
    var it = parsed[0].text

    check_i it, 0,  (kind: "text", text: "Some text ")
    check_i it, 1,  (kind: "glink", text: "some link", glink: "http://site.com")
    check_i it, 2,  (kind: "text", text:  " another ")
    check_i it, 3,  (kind: "text", text: "text, and ", em: true)
    check_i it, 4,  (kind: "link", text: "link 2", link: (sid: ".", did: "link 2", bid: ""), em: true)
    check_i it, 5,  (kind: "text", text: " more ")
    check_i it, 6,  (kind: "tag", text: "tag1")
    check_i it, 7,  (kind: "text", text: " ")
    check_i it, 8,  (kind: "embed", text: "", embed: (kind: "image", body: "img.png"))
    check_i it, 9,  (kind: "text", text: " some ")
    check_i it, 10, (kind: "embed", text: "", embed: (kind: "code", body: "code 2"))
    check_i it, 11, (kind: "text", text: " ")
    check_i it, 12, (kind: "embed", text: "", embed: (kind: "some", body: "some"))

  block: # Paragraph 2
    check parsed[1].kind == list
    check parsed[1].list.len == 2
    var it = parsed[1].list
    check_i it, 0, [
      (kind: "text", text: "Line "),
      (kind: "tag", text: "lt1")
    ]
    check_i it, 1, [
      %{ kind: "text", text: "Line 2 " },
      %{ kind: "embed", text: "", embed: { kind: "image", body: "none.png"} }
    ]

  block: # Paragraph 3
    check parsed[2].kind == text
    check parsed[2].text.len == 3
    var it = parsed[2].text
    check_i it, 0, (kind: "text", text: "And ")
    check_i it, 1, (kind: "tag", text: "tag2")
    check_i it, 2, (kind: "text", text: " another")

proc parse_list(text: string): ListBlock =
  let config = FParseConfig.init

  parse_list(block_source("list", text), test_fdoc(), config)

test "parse list":
  let parsed = parse_list("""
    - Line #tag
    - Line 2 image{some-img}
  """.dedent).list

  check parsed.len == 2
  check_i parsed, 0, [
    (kind: "text", text: "Line "),
    (kind: "tag", text: "tag")
  ]
  check_i parsed, 1, [
    %{ kind: "text", text: "Line 2 " },
    %{ kind: "embed", text: "", embed: { kind: "image", body: "some-img" } }
  ]

test "parse_list, with warnings":
  let blk = parse_list("""
    - Some image{img.png} some{some}
    - Another image{none.png}
  """.dedent)

  let parsed = blk.list
  check parsed.len == 2

  block: # Line 1
    var it = parsed[0]
    check_i it, 0,  (kind: "text", text: "Some ")
    check_i it, 1,  (kind: "embed", text: "", embed: (kind: "image", body: "img.png"))
    check_i it, 2,  (kind: "text", text: " ")
    check_i it, 3,  (kind: "embed", text: "", embed: (kind: "some", body: "some"))

  block: # Line 2
    var it = parsed[1]
    check_i it, 0,  (kind: "text", text: "Another ")
    check_i it, 1,  (kind: "embed", text: "", embed: (kind: "image", body: "none.png"))

test "parse list, with paragraphs":
  let parsed = parse_list("""
    Line #tag some
    text

    Line 2 image{some-img}
  """.dedent).list

  check parsed.len == 2
  check_i parsed, 0, [
    (kind: "text", text: "Line "),
    (kind: "tag", text: "tag"),
    (kind: "text", text: " some text")
  ]
  check_i parsed, 1, [
    %{ kind: "text", text: "Line 2 " },
    %{ kind: "embed", text: "", embed: { kind: "image", body: "some-img" } }
  ]

test "parse_list with tags":
  proc check_block(b: ListBlock) =
    check b.list.len == 2
    check (b.list[1], b.tags, b.warns.len).to_json == %[[{ kind: "text", text: "b" }], @["t"], 0]

  check_block parse_list("""
    - a
    - b
    #t
  """.dedent)


  check_block parse_list("""
    - a
    - b

    #t
  """.dedent)

  check_block parse_list("""
  a

  b

  #t
  """.dedent)

  block:
    let b = parse_list("""
    a

    b
    #t
    """.dedent)
    check b.list.len == 2
    check (b.tags, b.warns.len).to_json == %[@["t"], 0]
    check b.list[1].to_json == %[{ kind: "text", text: "b " }, { kind: "tag", text: "t" }]

test "image":
  let img = parse_image(block_source("image", "some.png #t1 #t2"), test_fdoc())
  check (img.image, img.tags, img.assets) == ("some.png", @["t1", "t2"], @["some.png"])

test "images, missing":
  let imgs = parse_images(block_source("images", "missing/dir\n#t1 #t2", "cols: 4"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == ("missing/dir", @[], @["t1", "t2"],
    @["missing/dir"])
  check imgs.cols == 4

test "images":
  let imgs = parse_images(block_source("images", ". #t1 #t2"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == (".", @["img.png"], @["t1", "t2"],
    @[".", "img.png"])

test "parse":
  block:
    let text = """
      Some #tag text ^text

      - a
      - b ^list

      k: 1 ^config.data

      #t #t2
    """.dedent

    let doc = Doc.parse(text, "some.ft")
    doc.blocks.delete 0 # removing title block
    check doc.blocks.len == 3
    check doc.tags == @["t", "t2"]
    check doc.source.DocTextSource.tags_line_n == (8, 8)

  block:
    let text = """
      Some title ^title

      Some section ^section

      Some #tag text #t1 ^text

      Another section
      #t1 #t2 ^section

      - a
      - b ^list

      k: 1 ^data

      #t #t2
    """.dedent

    let doc = Doc.parse(text, "some.ft")
    check doc.title == "Some title"
    doc.blocks.delete 0 # removing title block
    check doc.blocks.len == 5

test "should check for missing assets":
  let text = """
    image{missing1.png} ^text

    missing2.png ^image

    missing_dir ^images
  """.dedent

  let doc = Doc.parse(text, fmt"{test_space_location()}/some.ft")
  doc.blocks.delete 0 # removing title block
  let blocks = doc.blocks
  check blocks.len == 3
  check blocks[0].warns == @["Asset doesn't exist: missing1.png"]
  check blocks[1].warns == @["Asset doesn't exist: missing2.png"]
  check blocks[2].warns == @["Asset doesn't exist: missing_dir"]

test "should guess asset extensions":
  let text = """
    image{img} ^text

    img ^image

    image{missing} ^text
  """.dedent

  let doc = Doc.parse(text, fmt"{test_space_location()}/some.ft")
  doc.blocks.delete 0 # removing title block
  let blocks = doc.blocks
  check blocks.len == 3
  check (blocks[0].assets, blocks[0].warns) == (@["img.png"], @[])
  check (blocks[1].assets, blocks[1].warns) == (@["img.png"], @[])
  check (blocks[2].assets, blocks[2].warns) == (@["missing"], @["Asset doesn't exist: missing"])

proc parse_table(has_header: bool, text: string): TableBlock =
  let config = FParseConfig.init
  let args = if has_header: "header: true" else: ""
  parse_table(block_source("table", text, args), test_fdoc(), config)

test "parse_table":
  proc test_table(text: string) =
    let blk = parse_table(false, text)
    check blk.warns == @["Unknown embed: some"]
    check blk.assets == @["img.png"]
    let rows = blk.rows
    check blk.header.is_none
    check blk.cols == 2
    check rows.len == 2
    check (rows[0].len, rows[1].len) == (2, 2)
    check rows[0][0].to_json == %[{ kind: "text", text: "text" }]
    check rows[0][1].to_json == %[
      { kind: "embed", text: "", embed: { kind: "image", body: "img.png" } }]

    check rows[1][0].to_json == %[{ kind: "embed", text: "",   embed: { kind: "code", body: ",|" } }]
    check rows[1][1].to_json == %[{ kind: "embed", text: "", embed: { kind: "some", body: "some" } }]

  test_table """
    text, image{img.png}
    code{,|}, some{some}
  """.dedent

  test_table """
    text, image{img.png}

    code{,|},
    some{some}
  """.dedent

  test_table """
    text,
    image{img.png}

    code{,|},
    some{some}
  """.dedent

  test_table """
    text | image{img.png}
    code{,|} | some{some}
  """.dedent

test "parse_table with header":
  proc test_table(text: string) =
    let blk = parse_table(true, text)
    check blk.assets == @["img.png"]
    check blk.cols == 2
    let rows = blk.rows
    check blk.header.is_some
    let header = blk.header.get
    check header.len == 2
    check header[0].to_json == %[{ kind: "text", text: "text" }]
    check header[1].to_json == %[
      { kind: "embed", text: "", embed: { kind: "image", body: "img.png" } }]

    check rows.len == 1
    check rows[0].len == 2
    check rows[0][0].to_json == %[{ kind: "embed", text: "", embed: { kind: "code", body: ",|" } }]
    check rows[0][1].to_json == %[{ kind: "text", text: "text2" }]

  test_table """
    text, image{img.png}
    code{,|}, text2
  """.dedent

  test_table """
    text, image{img.png}

    code{,|},
    text2
  """.dedent

  test_table """
    text,
    image{img.png}

    code{,|},
    text2
  """.dedent

  test_table """
    text,
    image{img.png}

    code{,|},
    text2
  """.dedent

  test_table """
    text | image{img.png}
    code{,|} | text2
  """.dedent

test "parse_table with tags":
  proc test_table(text: string, rows: int) =
    let blk = parse_table(false, text)
    check blk.warns.is_empty
    check blk.rows.len == rows
    check blk.header.is_none
    check blk.tags == @["t1", "t2"]

  test_table("""
    a1, a2
    b1, b2
    #t1 #t2
  """.dedent, 2)

  test_table("""
    a1, a2
    b1, b2
    #t1, #t2
  """.dedent, 3)

  test_table("""
    a1 | a2
    b1 | b2
    #t1, #t2
  """.dedent, 2)

  test_table("""
    a1, a2

    b1,
    b2

    #t1 #t2
  """.dedent, 2)

  test_table("""
    a1,
    a2

    b1,
    b2

    #t1 #t2
  """.dedent, 2)

test "doc, from error":
  let doc = Doc.parse("""
    Algorithms ^title

    Some

    Another
  """.dedent.trim, "some.ft")
  doc.blocks.delete 0 # removing title block
  check doc.blocks.len == 1
  check doc.blocks[0].text == "Some Another"
  check doc.warns.is_empty