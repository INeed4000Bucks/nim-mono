import std/deques
import base, ext/url, ./component, ./mono_el, ./diff

type
  InEventEnvelopeKind* = enum events, pull
  InEventEnvelope* = object
    mono_id*: string
    case kind*: InEventEnvelopeKind
    of events: events*: seq[InEvent]
    of pull:   discard

  OutEventKind* = enum eval, update, ignore, expired, error
  OutEvent* = object
    case kind*: OutEventKind
    of eval:    code*: string
    of update:  diffs*: seq[Diff]
    of ignore:  discard
    of expired: discard
    of error:   message*: string

  BinaryResponseKind* = enum file, http
  BinaryResponse* = object
    case kind*: BinaryResponseKind
    of file:
      path*: string
    of http:
      content*: string
      code*:    int
      headers*: seq[(string, string)]

  # Processing Browser events decoupled from the HTTP networking, to avoid async complications.
  # Browser events are collected in indbox via async http handler, and then processed separatelly via
  # sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
  # and sent to Browser if needed.
  Session*[T] = ref object of RootObj
    id*:     string
    inbox*:  seq[InEvent]
    outbox*: seq[OutEvent]
    app*:    T
    el*:     Option[El] # UI tree from the last app render
    last_accessed_ms*: TimerMs

proc log*[T](self: Session[T]): Log =
  Log.init("Session", self.id)

method process*[T](self: Session[T]): bool {.base.} =
  when compiles(self.before_processing_session):
    self.before_processing_session
    defer: self.after_processing_session

  if self.inbox.is_empty: return

  let inbox = self.inbox.copy
  self.inbox.clear

  let oel = self.app.process(self.el, inbox)
  if oel.is_none: return
  let el = oel.get

  el.attrs["mono_id"] = self.id
  if self.el.is_some:
    let diffs = diff(@[], self.el.get, el)
    unless diffs.is_empty: self.outbox.add OutEvent(kind: update, diffs: diffs)
  self.el = el.some
  true

proc init*[T](_: type[Session[T]], app: T): Session[T] =
  Session[T](id: secure_random_token(6), last_accessed_ms: timer_ms(), app: app)

# Sessions -----------------------------------------------------------------------------------------
type Sessions*[T] = ref Table[string, Session[T]]

proc process*[T](sessions: Sessions[T]) =
  for _, s in sessions: discard s.process

proc collect_garbage*[T](self: Sessions[T], session_timeout_ms: int) =
  let deleted = self[].delete (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session in deleted.values: session.log.info("closed")

proc add_timer_event*[T](self: Sessions[T]) =
  for id, session in self: session.inbox.add(InEvent(kind: timer))

proc file_response*(path: string): BinaryResponse =
  BinaryResponse(kind: file, path: path)

proc http_response*(content: string, code = 200, headers = seq[(string, string)].init): BinaryResponse =
  BinaryResponse(kind: http, content: content, code: code, headers: headers)