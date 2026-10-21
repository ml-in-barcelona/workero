(** A Cloudflare R2 bucket, bound in [wrangler.toml] with [[[r2_buckets]]]. Each
    function suspends like {!Promise.await} and raises {!Js_error} when the
    runtime rejects. Objects are raw bytes held in OCaml strings. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] is the bucket bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name]. *)

val get : t -> string -> string option
(** The bytes of an object, or [None] when the key does not exist. *)

val put : ?content_type:string -> t -> string -> string -> unit
(** [put bucket key bytes] stores [bytes] under [key], replacing any object.
    [content_type] is kept as the object's [Content-Type]. *)

val delete : t -> string -> unit
(** Deletes an object. It is not an error when the key does not exist. *)

type info = { size : int; etag : string; content_type : string option }

val head : t -> string -> info option
(** The metadata of an object without its body, or [None] when the key does not
    exist. *)
