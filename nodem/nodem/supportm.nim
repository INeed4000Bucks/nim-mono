import json, uri, strutils, os, asyncdispatch, re, sugar
from times as nt import nil


template throw*(message: string) = raise new_exception(Exception, message)


proc clean_async_error*(error: string): string =
  error.replace(re"\nAsync traceback:[\s\S]+", "")


proc parse_url*(url: string): tuple[scheme: string, host: string, port: int, path: string] =
  var parsed = init_uri()
  parse_uri(url, parsed)
  (parsed.scheme, parsed.hostname, parsed.port.parse_int, parsed.path)


proc `%`*[T: tuple](o: T): JsonNode =
  result = new_JObject()
  for k, v in o.field_pairs: result[k] = %v


let test_enabled_s = get_env("test", "false")
let test_enabled   = test_enabled_s == "true"

template test*(name: string, body) =
  # block:
  if test_enabled or test_enabled_s == name.to_lower:
    try:
      body
    except Exception as e:
      echo "test '", name.to_lower, "' failed"
      raise e


proc timer_ms*(): (proc (): int) =
  let started_at = nt.utc(nt.now())
  () => nt.in_milliseconds(nt.`-`(nt.utc(nt.now()), started_at)).int


# type Fallible*[T] = object
#   case is_error*: bool
#   of true:
#     message*: string
#   of false:
#     value*: T

# func is_error*[T](e: Fallible[T]): bool = e.is_error

# func get*[T](e: Fallible[T]): T =
#   if e.is_error: throw(e.message) else: e.value

# func error*(T: type, message: string): Fallible[T] = Fallible[T](is_error: true, message: message)

# func success*[T](value: T): Fallible[T] = Fallible[T](is_error: false, value: value)