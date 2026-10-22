
# Durable Objects

A [Durable Object](https://developers.cloudflare.com/durable-objects/) is a small stateful server. Every object has an id. Requests for the same id reach the same object, wherever they start, and the object keeps its state in storage. [`Workero.Durable_object`](./Workero-Durable_object.md) supports objects with SQLite storage. It covers storage keys, SQL, transactions, alarms, hibernatable WebSockets and requests through a stub.


## Declare a class

Write the class as a function, register it under a name at module initialisation, and give the name to Wrangler:

```ocaml
open Workero

let () =
  Durable_object.register "Counter" (fun state _env ->
      let storage = Durable_object.State.storage state in
      let count = ref 0 in
      Durable_object.make
        ~init:(fun () ->
          count :=
            match Durable_object.Storage.get storage "count" with
            | Some (`Int n) -> n
            | _ -> 0)
        ~fetch:(fun _req ->
          incr count;
          Durable_object.Storage.put storage "count" (`Int !count);
          Response.text (string_of_int !count))
        ())

let handler req env _ctx =
  let counters = Durable_object.Namespace.of_env env "COUNTER" in
  let name = Option.value (URL.query (Request.url req) "name") ~default:"main" in
  let stub = Durable_object.Namespace.get_by_name counters name in
  Fetcher.fetch stub "http://counter/incr"

let () = Workero.serve handler
```
```toml
main = "_worker/index.js"

[[durable_objects.bindings]]
name = "COUNTER"
class_name = "Counter"

[[migrations]]
tag = "v1"
new_sqlite_classes = ["Counter"]
```
Cloudflare also accepts the newer `exports` map in place of `migrations`. Use `storage = "sqlite"` there. Classes with the older key-value storage are not supported.

The function given to [`Workero.Durable_object.register`](./Workero-Durable_object.md#val-register) runs each time the runtime creates the object. It returns the handlers of that object with [`Workero.Durable_object.make`](./Workero-Durable_object.md#val-make). Keep the state of the object in values that the function creates, as `count` above. Never keep it in a module-level value: one isolate can host several objects, and the runtime can remove an idle object from memory and create it again later.

The function cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await): the runtime needs the object at once. Such a call raises `Invalid_argument`, and the object fails to start. Work that waits belongs in `~init`. The runtime runs `init` before the first event, each time it creates the object, and queues other events until `init` returns. Use it to read stored values, as `count` above does.

Handlers are optional. `fetch` answers the requests of a stub. A call on an object without a `fetch` handler fails. Each handler runs in its own fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Two events on one object interleave only where one of them waits. Storage keys are synchronous, so a handler that does not wait runs without interruption.


## Build

`workero build` needs to know the class names, because a JavaScript module exports classes by static name. It runs the program once in `workerd`, reads the names that `register` collected, and exports one class for each. Put `register` calls at the top level of the program. A call that depends on a condition at initialisation is exported only when the condition holds in `workerd`. Any name made of ASCII letters, digits, `_` and `$` works, except `default`, `then`, `__proto__` and names that start with a digit. The build exports each class under its name without declaring a variable of that name, so a name cannot clash with the generated code.

The build fails, and prints the error of the program, when the program raises during initialisation. It also fails when the program does not finish initialising in 30 seconds; set `WORKERO_PROBE_TIMEOUT` to a number of seconds to change the limit. `workerd` must be installed: `npm install workerd`, or `wrangler`, provides it. `workero build` looks for it on `PATH`, then in `node_modules/.bin` of the current directory and its parents. Set `WORKERD` to a path, or to a name that `PATH` resolves, to use another binary. See [CLI](./cli.md).


## Reach an object

[`Workero.Durable_object.Namespace.of_env`](./Workero-Durable_object-Namespace.md#val-of_env) opens the binding. An id comes from a name (`id_from_name`), from a string that `Id.to_string` wrote (`id_from_string`), or at random (`unique_id`). [`Workero.Durable_object.Namespace.get`](./Workero-Durable_object-Namespace.md#val-get) gives the stub of an id, and `get_by_name` does both steps. The stub is a [`Workero.Fetcher.t`](./Workero-Fetcher.md#type-t). Its `fetch` reaches the `fetch` handler of the object, with the path and the query of the URL. The host is ignored.

[`Workero.Durable_object.Id.name`](./Workero-Durable_object-Id.md#val-name) gives the name of an id made with `id_from_name`. [`Workero.Durable_object.State.id`](./Workero-Durable_object-State.md#val-id) gives the id of the running object.


## RPC methods

A class can expose methods that callers invoke on the stub, such as `stub.increment()`, without building a request. Declare the method names with `~rpc` in [`Workero.Durable_object.register`](./Workero-Durable_object.md#val-register), and answer the calls with the `~rpc` handler of [`Workero.Durable_object.make`](./Workero-Durable_object.md#val-make):

```ocaml
let () =
  Durable_object.register ~rpc:[ "increment"; "add" ] "Counter" (fun state _env ->
      let storage = Durable_object.State.storage state in
      Durable_object.make
        ~rpc:(fun name args ->
          match (name, args) with
          | "increment", [] ->
              let n =
                match Durable_object.Storage.get storage "count" with
                | Some (`Int n) -> n + 1
                | _ -> 1
              in
              Durable_object.Storage.put storage "count" (`Int n);
              `Int n
          | "add", [ `Int a; `Int b ] -> `Int (a + b)
          | _ -> invalid_arg ("bad call to " ^ name))
        ())
```
The names must be known before any object exists, because `workero build` adds them to the exported class. `rpc` receives the name and the arguments as `Jsonkit.t`, and returns the result as JSON. A JavaScript caller sees a promise for the result: `await stub.add(1, 2)`. An exception in the handler rejects the call with its message. A handler runs in its own fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await).

OCaml code calls a method with [`Workero.Durable_object.call`](./Workero-Durable_object.md#val-call):

```ocaml
let stub = Durable_object.Namespace.get_by_name counters "main" in
match Durable_object.call stub "add" [ `Int 1; `Int 2 ] with
| `Int n -> n
| _ -> failwith "unexpected result"
```
A call to a missing method, or to a method that raises, raises [`Workero.Js_error`](./Workero.md#exception-Js_error). Arguments and results are JSON: values that JSON cannot carry, such as `Date`, `Map`, `BigInt`, streams and other stubs, are not supported. A JavaScript `undefined` argument or result becomes ``Null`.


## Storage

[`Workero.Durable_object.Storage`](./Workero-Durable_object-Storage.md) reads and writes keys without suspending. Values are `Jsonkit.t`. They go through `JSON.stringify` and `JSON.parse` around the runtime's own storage. A value written by JavaScript code reads as its JSON form: a `Date` is its ISO string and a `Map` is `{}`. `get` and `list` raise `Invalid_argument` for a stored value that `JSON.stringify` rejects, such as a `BigInt` or a cyclic object. [`Workero.Durable_object.Storage.list`](./Workero-Durable_object-Storage.md#val-list) takes `prefix`, `start`, `end_`, `reverse` and `limit`.


## SQL

[`Workero.Durable_object.Storage.sql`](./Workero-Durable_object-Storage.md#val-sql) gives the SQLite database of the object. [`Workero.Durable_object.Sql.query`](./Workero-Durable_object-Sql.md#val-query) returns rows as [`Workero.Sql_value.row`](./Workero-Sql_value.md#type-row), [`Workero.Durable_object.Sql.run`](./Workero-Durable_object-Sql.md#val-run) returns the rows written, and parameters bind to the `?` marks:

```ocaml
let sql = Durable_object.Storage.sql storage in
ignore
  (Durable_object.Sql.run sql
     "CREATE TABLE IF NOT EXISTS visits (at INTEGER, path TEXT)");
ignore
  (Durable_object.Sql.run
     ~params:[ Int (Int64.of_float (Date.now ())); Text "/home" ]
     sql "INSERT INTO visits VALUES (?, ?)");
let rows = Durable_object.Sql.query sql "SELECT path FROM visits"
```
Calls are synchronous and never suspend. An SQL error raises [`Workero.Js_error`](./Workero.md#exception-Js_error). The runtime returns numbers as JavaScript numbers. A `REAL` that holds `2.0` reads as `Int 2L`, and an `INTEGER` beyond 253 reads as a rounded `Float`; an `Int` you write is exact only within ±253. See [`Workero.Sql_value`](./Workero-Sql_value.md).

[`Workero.Durable_object.Storage.transaction_sync`](./Workero-Durable_object-Storage.md#val-transaction_sync) runs a function in a transaction. If the function raises, the runtime rolls back the writes to SQL and to storage keys, and the same exception reaches the caller. The function cannot wait: a call to [`Workero.Promise.await`](./Workero-Promise.md#val-await) in it raises `Invalid_argument` and rolls the transaction back. The asynchronous `transaction` of JavaScript has no equivalent.


## Hibernatable WebSockets

A socket accepted with [`Workero.Durable_object.State.accept_websocket`](./Workero-Durable_object-State.md#val-accept_websocket) stays connected while the object is evicted from memory, so an idle chat room costs nothing. The runtime creates the object again when a message arrives and calls its `websocket_message`, `websocket_close` or `websocket_error` handler:

```ocaml
Durable_object.register "Room" (fun state _env ->
    Durable_object.make
      ~fetch:(fun _req ->
        let { Websocket.client; server } = Websocket.pair () in
        Durable_object.State.accept_websocket ~tags:[ "room" ] state server;
        Websocket.response client)
      ~websocket_message:(fun ws message ->
        match message with
        | Websocket.Text text ->
            List.iter
              (fun peer -> Websocket.send peer (Text text))
              (Durable_object.State.websockets ~tag:"room" state)
        | Binary _ -> ())
      ~websocket_close:(fun ws ~code ~reason ~was_clean:_ ->
        Websocket.close ~code ~reason ws)
      ())
```
Per-socket state in memory is lost when the object hibernates. Keep it with [`Workero.Websocket.serialize_attachment`](./Workero-Websocket.md#val-serialize_attachment), which holds at most 2048 bytes, and read it with [`Workero.Websocket.deserialize_attachment`](./Workero-Websocket.md#val-deserialize_attachment). [`Workero.Durable_object.State.set_websocket_auto_response`](./Workero-Durable_object-State.md#val-set_websocket_auto_response) answers a fixed text message, such as a ping, without waking the object. A socket that was accepted with [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) does not hibernate and does not reach these handlers.

A class without a `websocket_message` handler still accepts hibernatable sockets, and the runtime drops their messages without a reply.


## Alarms

An object has one alarm. The runtime calls the `alarm` handler of the object when the alarm is due, also when the object left memory:

```ocaml
Durable_object.register "Reminder" (fun state _env ->
    let storage = Durable_object.State.storage state in
    Durable_object.make
      ~fetch:(fun _req ->
        Durable_object.Storage.set_alarm_after storage ~ms:60_000.;
        Response.text "reminder set")
      ~alarm:(fun info ->
        Console.log (Printf.sprintf "alarm, attempt %d" (info.retry_count + 1)))
      ())
```
[`Workero.Durable_object.Storage.set_alarm`](./Workero-Durable_object-Storage.md#val-set_alarm) takes a time in milliseconds since the Unix epoch. [`Workero.Durable_object.Storage.get_alarm`](./Workero-Durable_object-Storage.md#val-get_alarm) reads it and [`Workero.Durable_object.Storage.delete_alarm`](./Workero-Durable_object-Storage.md#val-delete_alarm) cancels it. If the handler raises, the runtime runs it again with a growing delay and a larger `retry_count`. The runtime stops after a few tries. A class without an `alarm` handler still accepts `set_alarm`, and the alarm then fails and retries.


## Other state functions

- [`Workero.Durable_object.State.wait_until`](./Workero-Durable_object-State.md#val-wait_until) keeps the object alive for background work after the response.
- [`Workero.Durable_object.State.block_concurrency_while`](./Workero-Durable_object-State.md#val-block_concurrency_while) runs a function while no other event reaches the object. If the function raises, the runtime resets the object and fails the running requests; the next request creates the object again.
- [`Workero.Durable_object.Storage.sync`](./Workero-Durable_object-Storage.md#val-sync) waits until earlier writes are durable, and [`Workero.Durable_object.Storage.delete_all`](./Workero-Durable_object-Storage.md#val-delete_all) removes every key.

## Test locally

`wrangler dev` runs Durable Objects. In a `workerd` config for `workerd test`, declare the classes on the Worker service, bind the namespace, and give the service *on-disk* storage. SQLite storage needs it; `inMemory` storage does not support it:

```capnp
(name = "worker", worker = (
  compatibilityDate = "2025-06-01",
  modules = [ ... ],
  bindings = [(name = "COUNTER", durableObjectNamespace = "Counter")],
  durableObjectNamespaces = [(className = "Counter", uniqueKey = "counter", enableSql = true)],
  durableObjectStorage = (localDisk = "disk"),
)),
(name = "disk", disk = (path = "do-data", writable = true)),
```
The first module of the Worker must be `index.js`, which exports the classes. `test/worker/run.sh` shows the full setup. `workerd` does not implement jurisdictions: `unique_id ~jurisdiction` raises `Js_error` there.
