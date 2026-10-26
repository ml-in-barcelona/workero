(** A Workers AI binding, declared in [wrangler.toml] with [[ai]]. Models run
    remotely, including under [wrangler dev], and consume account usage. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the Workers AI binding [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [run] method. *)

type retries
(** How AI Gateway retries a failed request, made by {!val:retries}. *)

val retries :
  ?max_attempts:int ->
  ?retry_delay_ms:int ->
  ?backoff:[ `Constant | `Linear | `Exponential ] ->
  unit ->
  retries
(** [retries ()] sets the retry policy of a {!type-gateway}. [max_attempts] is
    from 1 to 5. [retry_delay_ms] is the delay between attempts. The runtime
    picks any field that is not set.

    Raises [Invalid_argument] when [max_attempts] is outside 1 to 5. *)

type gateway
(** Options that route a call through
    {{:https://developers.cloudflare.com/ai-gateway/}AI Gateway}, made by
    {!val:gateway}. *)

val gateway :
  ?cache_key:string ->
  ?cache_ttl:int ->
  ?skip_cache:bool ->
  ?collect_log:bool ->
  ?event_id:string ->
  ?request_timeout_ms:int ->
  ?retries:retries ->
  ?metadata:(string * Jsonkit.t) list ->
  string ->
  gateway
(** [gateway id] routes the call through the AI Gateway named [id]. [cache_key],
    [cache_ttl] (seconds) and [skip_cache] control response caching.
    [collect_log] and [event_id] control logging. [request_timeout_ms] limits
    the request. [metadata] attaches fields to the log entry; each value must be
    [`Null], [`Bool], [`Int], [`Float] or [`String].

    Raises [Invalid_argument] when a metadata value is a list or an object. *)

val run : ?gateway:gateway -> t -> string -> Jsonkit.t -> Jsonkit.t
(** [run ai model input] runs [model], for example
    ["@cf/meta/llama-3.1-8b-instruct"], with [input] and returns its answer as
    JSON. [gateway] routes the call through AI Gateway. Suspends like
    {!Promise.await}.

    Raises [Invalid_argument] when the model answers with a stream or with a
    value that has no JSON form. Use {!run_bytes} for a model that returns an
    image or audio, and {!run_stream} to stream text.
    @raise Js_error when the runtime fails, for example on an unknown model. *)

val run_bytes : ?gateway:gateway -> t -> string -> Jsonkit.t -> string
(** Like {!run}, for a model that answers with binary data. The result is the
    raw bytes.

    Raises [Invalid_argument] when the answer is not binary data. *)

val run_stream : ?gateway:gateway -> t -> string -> Jsonkit.t -> Stream.t
(** Like {!run}, for a model that streams its answer. It sets [stream] to [true]
    in [input], which must be a JSON object, and returns the stream of the
    answer. Text models send server-sent events: chunks such as
    ["data: {\"response\":\"Hel\"}\n\n"], ending with ["data: [DONE]\n\n"]. Read
    it with {!Stream.iter}, or pass it to {!Response.of_stream}. A chunk can
    split an event, so buffer until a blank line. The call returns when the
    stream starts, not when it ends.

    Raises [Invalid_argument] when [input] is not a JSON object or when the
    model does not answer with a stream. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
