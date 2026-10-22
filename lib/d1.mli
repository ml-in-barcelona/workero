(** Basic SQL queries on a Cloudflare D1 database, bound with [[[d1_databases]]]
    in [wrangler.toml]. Storage operations suspend like {!Promise.await} and
    raise {!Js_error} when the runtime rejects, for example on an SQL error. *)

type t

val of_env : Env.t -> string -> t
(** [of_env env name] looks up the database bound as [name]. It does not
    suspend. Raises [Invalid_argument] if the binding is missing, is not an
    object, or lacks [prepare]. The error names the binding. *)

type value = Sql_value.t =
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string
      (** An SQL value. {!Sql_value} describes the number limits: an [Int] is
          exact within ±[2^53] only. *)

type row = Sql_value.row
(** The columns of a row in result order, with their names. *)

val query : ?params:value list -> t -> string -> row list
(** [query db sql ~params] runs [sql] with [params] bound to its [?] marks, in
    order, and returns the rows. Columns keep the order of the [SELECT], and
    repeated or numeric-looking names are kept as they are. Raises
    [Invalid_argument] when the platform answers with a malformed result: a
    column name that is not text, or a row of another length. *)

val run : ?params:value list -> t -> string -> int
(** [run db sql ~params] runs a statement that returns no rows, such as [INSERT]
    or [CREATE TABLE], and returns the number of rows it changed. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
