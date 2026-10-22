(** A Hyperdrive binding, declared in [wrangler.toml] with [[[hyperdrive]]].
    Hyperdrive pools and caches connections to a PostgreSQL or MySQL database.

    The binding gives connection details only. To query the database you need a
    database driver that speaks the wire protocol over TCP, and no such driver
    for OCaml runs in a Worker yet. A driver would open the connection with
    {!Socket.connect}.

    The host, user and password are valid only inside the running Worker. Treat
    {!password} and {!connection_string} as secrets: do not log them. No error
    that this module raises contains them. *)

type t
(** A Hyperdrive binding. The accessors of this module raise [Invalid_argument],
    with the expected and actual JavaScript type, when the binding has no such
    field. *)

val of_env : Env.t -> string -> t
(** [of_env env name] is the Hyperdrive binding [name].

    Raises [Invalid_argument] when [env] has no binding [name], or when [name]
    is not an object. *)

val connection_string : t -> string
(** A connection string, such as [postgres://user:password@host:port/database],
    for a database driver. It contains the password. *)

val host : t -> string
(** A host name that is valid only inside this Worker. *)

val port : t -> int
(** The port of {!host}. *)

val user : t -> string
(** The database user. *)

val password : t -> string
(** A password that is valid only inside this Worker. *)

val database : t -> string
(** The database name. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
