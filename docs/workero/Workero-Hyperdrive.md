
# Module `Workero.Hyperdrive`

A Hyperdrive binding, declared in `wrangler.toml` with `[[hyperdrive]]`. Hyperdrive pools and caches connections to a PostgreSQL or MySQL database.

The binding gives connection details only. To query the database you need a database driver that speaks the wire protocol over TCP, and no such driver for OCaml runs in a Worker yet. A driver would open the connection with [`Socket.connect`](./Workero-Socket.md#val-connect).

The host, user and password are valid only inside the running Worker. Treat [`password`](./#val-password) and [`connection_string`](./#val-connection_string) as secrets: do not log them. No error that this module raises contains them.

```ocaml
type t
```
A Hyperdrive binding. The accessors of this module raise `Invalid_argument`, with the expected and actual JavaScript type, when the binding has no such field.

```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the Hyperdrive binding `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when `name` is not an object.

```ocaml
val connection_string : t -> string
```
A connection string, such as `postgres://user:password@host:port/database`, for a database driver. It contains the password.

```ocaml
val host : t -> string
```
A host name that is valid only inside this Worker.

```ocaml
val port : t -> int
```
The port of [`host`](./#val-host).

```ocaml
val user : t -> string
```
The database user.

```ocaml
val password : t -> string
```
A password that is valid only inside this Worker.

```ocaml
val database : t -> string
```
The database name.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```