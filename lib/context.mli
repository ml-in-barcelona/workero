(** The [ctx] argument of a Worker handler. *)

type t

val wait_until : t -> (unit -> unit) -> unit
(** [wait_until ctx f] starts [f] immediately in its own fiber and registers its
    Promise with the runtime. Synchronous work in [f] runs before [wait_until]
    returns; {!Promise.await} suspends the fiber and lets the handler continue.
    A failure in [f] does not change the response. For HTTP requests, all
    [wait_until] calls share up to 30 seconds after the response is sent or the
    client disconnects; unfinished work is canceled. An active response stream
    keeps the HTTP invocation active separately. Durable Objects have their own
    {!Durable_object.State.wait_until}; they remain active during their
    requests, streams and pending I/O without calling it. See
    {{:https://developers.cloudflare.com/workers/runtime-apis/context/#waituntil}Cloudflare's
     waitUntil documentation}. *)

val pass_through_on_exception : t -> unit
(** [pass_through_on_exception ctx] makes the runtime send the request to the
    origin server when the handler raises, instead of answering with an error.
    It needs a route with an origin: it has no effect on [workers.dev] or in
    workerd without one. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
