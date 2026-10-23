(** A [Fetcher] sends requests to another Worker, to static assets or to a
    Durable Object. Configure service and assets bindings in [wrangler.toml]
    with [[[services]]] or [[assets]]. A Durable Object stub comes from
    {!Durable_object.Namespace.get}. The calls suspend like {!Promise.await}.
    They raise {!Js_error} when the runtime throws or rejects, for example when
    the target Worker raises. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the service or assets binding [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [fetch] method. *)

val fetch :
  ?signal:Abort_signal.t ->
  ?method_:Method.t ->
  ?headers:(string * string) list ->
  ?body:string ->
  t ->
  string ->
  Response.t
(** [fetch fetcher url] sends a request to the target and waits for the response
    headers. The rules are those of {!Workero.fetch}: [method_] is [GET] by
    default and [body] is sent as raw bytes without a [content-type].

    The URL must be absolute. A service binding ignores the host, so any host
    works, such as ["http://service/path"]; the target sees the path and the
    query. An assets binding looks the path up in the asset directory.

    When [signal] aborts, the call raises {!Js_error} with an [AbortError] or
    [TimeoutError]; see {!Abort_signal}. A signal that has already aborted fails
    the call without a request.

    Raises [Invalid_argument] when [body] is given with [GET] or [HEAD]. *)

val fetch_request : ?signal:Abort_signal.t -> t -> Request.t -> Response.t
(** [fetch_request fetcher req] forwards [req] as it is, with its method,
    headers and body. [req] cannot be used after the call: the runtime consumes
    its body. Use {!Request.clone} first to keep a copy.

    With [signal], the call sends a new request built from [req] that uses
    [signal] in place of the signal of [req]. [signal] aborts the call like in
    {!fetch}. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
