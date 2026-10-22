
# Hyperdrive

[`Workero.Hyperdrive`](./Workero-Hyperdrive.md) is the [Hyperdrive](https://developers.cloudflare.com/hyperdrive/) binding. Hyperdrive pools and caches connections to a PostgreSQL or MySQL database. The binding tells your Worker where and how to connect.

**Workero cannot query the database yet.** The binding gives connection details only. To send a query you need a database driver that speaks the database protocol over TCP, and no such driver for OCaml runs in a Worker. The TCP module of workero is still in development. Until a driver exists, use Hyperdrive from workero only to read the details and pass them on.


## Configure

```toml
[[hyperdrive]]
binding = "HYPERDRIVE"
id = "<hyperdrive config id>"
localConnectionString = "postgres://user:password@localhost:5432/app"
```

## Use

```ocaml
let handler _req env _ctx =
  let open Workero in
  let db = Hyperdrive.of_env env "HYPERDRIVE" in
  Response.text
    (Printf.sprintf "%s on port %d, database %s\n" (Hyperdrive.host db)
       (Hyperdrive.port db) (Hyperdrive.database db))

let () = Workero.serve handler
```
- [`Workero.Hyperdrive.of_env`](./Workero-Hyperdrive.md#val-of_env) opens the binding. It raises `Invalid_argument` when there is no such binding, or when the name is not an object.
- [`Workero.Hyperdrive.connection_string`](./Workero-Hyperdrive.md#val-connection_string) is a connection string for a database driver.
- [`Workero.Hyperdrive.host`](./Workero-Hyperdrive.md#val-host), [`Workero.Hyperdrive.port`](./Workero-Hyperdrive.md#val-port), [`Workero.Hyperdrive.user`](./Workero-Hyperdrive.md#val-user), [`Workero.Hyperdrive.password`](./Workero-Hyperdrive.md#val-password) and [`Workero.Hyperdrive.database`](./Workero-Hyperdrive.md#val-database) give the parts of it.
The host and the password are valid only inside the running Worker. The password and the connection string are secrets: do not log them or return them in a response. No error from workero contains them. A field that is missing or has the wrong type raises `Invalid_argument` with the expected and the actual JavaScript type.


## Test

`workerd` has a `hyperdrive` binding type, and the tests of workero use it. Its host ends with `.hyperdrive.local` and no database listens behind it. The tests check the details only. `wrangler dev` connects to `localConnectionString` instead.
