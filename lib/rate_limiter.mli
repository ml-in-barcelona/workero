(** A Workers Rate Limiting binding, declared in [wrangler.toml] with
    [[[ratelimits]]]. The binding's [name] is passed to {!of_env}; the limit and
    its period come from the binding, not from the code. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the rate limiter bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [limit] method. *)

val limit : t -> string -> bool
(** [limit limiter key] counts one request for [key] and is [true] when it is
    allowed, [false] when [key] is over the limit. Suspends like
    {!Promise.await}. The count is per location and approximate.

    @raise Js_error when the runtime fails. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
