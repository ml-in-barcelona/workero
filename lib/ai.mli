(** A Workers AI binding, declared in [wrangler.toml] with [[ai]]. Workers AI
    runs models and bills your account, also in [wrangler dev]. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the Workers AI binding [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [run] method. *)

val run : t -> string -> Jsonkit.t -> Jsonkit.t
(** [run ai model input] runs [model], for example
    ["@cf/meta/llama-3.1-8b-instruct"], with [input] and returns its answer as
    JSON. Suspends like {!Promise.await}.

    Raises [Invalid_argument] when the model answers with a stream or with a
    value that has no JSON form. Use {!run_bytes} for a model that returns an
    image or audio.
    @raise Js_error when the runtime fails, for example on an unknown model. *)

val run_bytes : t -> string -> Jsonkit.t -> string
(** Like {!run}, for a model that answers with binary data. The result is the
    raw bytes.

    Raises [Invalid_argument] when the answer is not binary data. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
