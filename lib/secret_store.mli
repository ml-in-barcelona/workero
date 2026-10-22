(** A secret of Cloudflare Secrets Store, bound in [wrangler.toml] with
    [[[secrets_store_secrets]]]. The value is plain text: do not log it. For a
    secret set with [wrangler secret put], use {!Env.secret}. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the secret bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name]. *)

val get : t -> string option
(** The value of the secret, or [None] when the runtime returns [null] or
    [undefined]. Suspends like {!Promise.await}. Raises {!Js_error} when access
    fails, for example when the secret does not exist or the Worker may not read
    the store. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
