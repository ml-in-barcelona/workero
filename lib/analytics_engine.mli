(** A Workers Analytics Engine dataset, declared in [wrangler.toml] with
    [[[analytics_engine_datasets]]]. *)

type t

(** A blob of a data point. *)
type blob = Text of string | Bytes of string

val of_env : Env.t -> string -> t
(** [of_env env name] is the dataset bound as [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when the
    binding has no [writeDataPoint] method. *)

val write :
  ?index:string -> ?doubles:float list -> ?blobs:blob list -> t -> unit
(** [write dataset] records one data point. [index] is the sampling key. The
    runtime accepts one index, up to 20 [doubles] and up to 20 [blobs]. It does
    not wait: the runtime writes the point after the handler continues, and
    [write] returns at once, without a result.

    @raise Js_error when the runtime rejects the data point. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
