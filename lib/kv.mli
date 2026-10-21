(** A Workers KV namespace, bound in [wrangler.toml] with [[[kv_namespaces]]].
    Each function suspends like {!Promise.await} and raises {!Js_error} when the
    runtime rejects. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the namespace bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name]. *)

val get : t -> string -> string option
(** The value of a key as text, or [None] when the key does not exist. *)

val put : ?expiration_ttl:int -> t -> string -> string -> unit
(** [put kv key value] stores [value] under [key]. [expiration_ttl] is the
    number of seconds after which the key expires; Cloudflare requires at least
    60. *)

val delete : t -> string -> unit
(** Deletes a key. It is not an error when the key does not exist. *)

val list : ?prefix:string -> t -> string list
(** The names of all keys that start with [prefix], in lexicographic order. KV
    returns at most 1000 keys per request, so a large namespace takes several
    requests; [list] follows the cursor until the listing is complete and holds
    every name in memory. *)
