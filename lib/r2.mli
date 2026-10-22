(** Buffered object bytes in a Cloudflare R2 bucket, bound with [[[r2_buckets]]]
    in [wrangler.toml]. Storage operations suspend like {!Promise.await} and
    raise {!Js_error} when the runtime rejects. Objects are raw bytes held in
    OCaml strings. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] looks up the bucket bound as [name]. It does not suspend.
    Raises [Invalid_argument] if the binding is missing, is not an object, or
    lacks [get], [put], [head], or [delete]. The error names the binding. *)

val get : t -> string -> string option
(** The entire body of an object as bytes, or [None] when the key does not
    exist. Reads the body into Worker memory. *)

val put : ?content_type:string -> t -> string -> string -> unit
(** [put bucket key bytes] stores [bytes] under [key], replacing any object.
    [content_type] is kept as the object's [Content-Type]. *)

val delete : t -> string -> unit
(** Deletes an object. It is not an error when the key does not exist. *)

type info = { size : int; etag : string; content_type : string option }

val head : t -> string -> info option
(** The metadata of an object without its body, or [None] when the key does not
    exist. [head] and [get] are separate, non-atomic requests. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
