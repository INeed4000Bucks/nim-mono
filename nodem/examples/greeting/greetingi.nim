# Auto-generated code, do not edit
import nodem, asyncdispatch
export nodem, asyncdispatch

let greeting* = Address("greeting")

proc say_hi*(prefix: string): Future[string] {.nimport_from: greeting.} = discard