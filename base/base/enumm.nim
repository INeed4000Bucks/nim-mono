import std/[macros, strutils]

macro autoconvert*(TT: type[enum]) =
  echo "disable enum autoconvert"
  let fname = ident "to" & $(TT)
  quote do:
    converter `fname`*(s: string): `TT` = parse_enum[`TT`](s)