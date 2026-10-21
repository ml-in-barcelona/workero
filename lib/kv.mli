(** Text values in a Workers KV namespace, bound with [[[kv_namespaces]]] in
    [wrangler.toml]. Storage operations suspend like {!Promise.await} and raise
    {!Js_error} when the runtime rejects. KV is eventually consistent across
    locations; 60 seconds is not a guaranteed visibility bound. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] looks up the namespace bound as [name]. It does not
    suspend. Raises [Invalid_argument] if the binding is missing, is not a KV
    object, or lacks a required method. The error names the binding. *)

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
    every name in memory. Raises [Failure] when KV reports an incomplete page
    without a cursor. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
