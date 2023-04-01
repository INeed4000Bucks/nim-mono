import std/[deques]
import base, ../app

type SessionPostEventKind* = enum event, pull
type SessionPostEvent* = object
  session_id*: string
  case kind*: SessionPostEventKind
  of event:
    event*: InEvent
  of pull:
    discard

type SessionPullEventKind* = enum expired, eval, error
type SessionPullEvent* = object
  case kind*: SessionPullEventKind
  of expired:
    discard
  of eval:
    code*: string
  of error:
    message*: string

# proc to(e: OutEvent, _: type[SessionPostEvent]): SessionPostEvent =
#   assert e.kind == eval
#   PullEvent(kind: eval, code: e.code)

# Processing Browser events decoupled from the HTTP networking, to avoid async complications.
# Browser events are collected in indbox via async http handler, and then processed separatelly via
# sync process. Result of processing stored in outbox, which periodically checked by async HTTP handler
# and sent to Browser if needed.
type Session* = ref object
  id*:               string
  app*:              App
  inbox*:            Deque[InEvent]
  outbox*:           Deque[OutEvent]
  last_accessed_ms*: Timer

proc init*(_: type[Session], session_id: string, app: App): Session =
  Session(id: session_id, app: app, last_accessed_ms: timer_ms())

proc log*(self: Session): Log =
  Log.init("Session", self.id)

proc process(self: Session): void =
  while self.inbox.len > 0:
    let out_events = self.app.process self.inbox.pop_first
    for event in out_events: self.outbox.add_last(event)

type Sessions* = ref Table[string, Session]
# type ProcessSession[S] = proc(session: S, event: JsonNode): Option[JsonNode]

proc process*(sessions: Sessions) =
  for _, s in sessions: s.process

proc collect_garbage*(this: Sessions, session_timeout_ms: int) =
  let deleted = this[].delete (_, s) => s.last_accessed_ms() > session_timeout_ms
  for session in deleted.values: session.log.info("closed")