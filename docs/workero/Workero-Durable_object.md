
# Module `Workero.Durable_object`

Durable Objects with SQLite-backed key-value and SQL storage.

A Durable Object class is a function from its [`State`](./Workero-Durable_object-State.md) and the [`Env`](./Workero-Env.md) to the handlers of one object, built with [`make`](./#val-make) and bound to a name with [`register`](./#val-register). Declare the class in `wrangler.toml` with `[durable_objects]` and a migration with `new_sqlite_classes`, or with the `exports` map and `storage = "sqlite"`. `workero build` exports every registered class. [`Storage`](./Workero-Durable_object-Storage.md) requires a SQLite-backed class; its key-value and SQL methods fail on legacy storage. `fetch`, `alarm`, hibernatable WebSocket event handlers, and the RPC methods that you declare with `~rpc` in [`register`](./#val-register) are exported. See [Durable Objects](./durable_objects.md).

Handlers on one object interleave only where they suspend, so a handler that uses only the synchronous key-value methods and never calls [`Promise.await`](./Workero-Promise.md#val-await) runs without interruption. Keep the state of an object in values created inside the function given to [`register`](./#val-register), never in module-level values: one isolate may host many objects, and the runtime may evict an object from memory and create it again later.

```ocaml
module Id : sig ... end
```
```ocaml
module Sql : sig ... end
```
The SQLite database of an object. Calls are synchronous: they never suspend. An SQL error raises [`Js_error`](./Workero.md#exception-Js_error). Numbers are JavaScript numbers, so an `Int` is exact only within ±`2^53`; see [`Sql_value`](./Workero-Sql_value.md).

```ocaml
module Storage : sig ... end
```
The storage of one object. `get`, `put`, `delete`, and `list` do not suspend; `delete_all`, `sync`, and the alarm methods do. Values are JSON, converted with `JSON.stringify` and `JSON.parse`. A `Date` stored by JavaScript code reads as its ISO string and a `Map` as `{}`. `get` and `list` raise `Invalid_argument` for a stored value that `JSON.stringify` rejects, such as a `BigInt` or a cyclic object. The functions raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws, for example on a class that is not backed by SQLite.

```ocaml
module Container : sig ... end
```
The container attached to an object, on Cloudflare Containers. Declare it in `wrangler.toml` with `[[containers]]` and the class name of the object. The container starts only when [`start`](./Workero-Durable_object-Container.md#val-start) runs. The functions raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws or rejects, for example when no image is configured or the container is not running.

```ocaml
module State : sig ... end
```
```ocaml
type alarm_info = {
  retry_count : int;
  is_retry : bool;
}
```
`retry_count` is 0 on the first attempt.

```ocaml
type t
```
The handlers of one object.

```ocaml
val make : 
  ?init:(unit -> unit) ->
  ?fetch:(Request.t -> Response.t) ->
  ?alarm:(alarm_info -> unit) ->
  ?websocket_message:(Websocket.t -> Websocket.message -> unit) ->
  ?websocket_close:
    (Websocket.t -> code:int -> reason:string -> was_clean:bool -> unit) ->
  ?websocket_error:(Websocket.t -> string -> unit) ->
  ?rpc:(string -> Rpc.t list -> Rpc.t) ->
  unit ->
  t
```
`make ()` gives an object that handles no event. `init` runs under `blockConcurrencyWhile` before the first event, each time the object is created, and may call [`Promise.await`](./Workero-Promise.md#val-await); if it raises, the runtime resets the object. `fetch` answers the requests that a stub sends. `alarm` runs when the alarm is due; an exception makes the runtime retry it. The `websocket_*` handlers get the events of sockets accepted with [`State.accept_websocket`](./Workero-Durable_object-State.md#val-accept_websocket); `websocket_error` gets the error message. `rpc` answers the calls of the methods that [`register`](./#val-register) declared: `rpc name args` gets the method name and the arguments as [`Rpc.t`](./Workero-Rpc.md#type-t) values, and returns the result as one. See [`register`](./#val-register). Every handler runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). A stub fetch on an object without a `fetch` handler fails.

```ocaml
val register : ?rpc:string list -> string -> (State.t -> Env.t -> t) -> unit
```
`register class_name create` binds `create` to the class that `workero build` exports under `class_name`. Call it at module initialization, once per class. The build reads the names by running the program in `workerd`; a `register` call that a condition skips at initialization is not exported.

`create` runs each time the runtime creates the object, before the first event. It must not call [`Promise.await`](./Workero-Promise.md#val-await): that raises `Invalid_argument`. Load stored values in `~init` of [`make`](./#val-make). If `create` raises, the object fails to start and the request that needed it fails.

`rpc` names the RPC methods of the class, for example `["increment"]`. The build adds each name as a method of the exported class, so JavaScript code calls `stub.increment(...)` and OCaml code calls [`call`](./#val-call). The `rpc` handler of [`make`](./#val-make) runs each call. A name must follow the rules of `class_name`, must be unique in the class, and must not be `fetch`, `alarm`, `connect`, `constructor`, `prototype`, `webSocketMessage`, `webSocketClose` or `webSocketError`. Declare the names here, not in `create`: the build reads them before any object exists. A call to a declared name on a class whose handlers have no `rpc` fails.

Raises `Invalid_argument` when `class_name` is empty, starts with a digit, has a character other than an ASCII letter, a digit, `"_"` or `"$"`, is `"default"`, `"then"` or `"__proto__"`, or is already registered. Reserved words such as `"class"` are accepted: the generated module exports the class under that name without declaring a variable of it. It also raises `Invalid_argument` for an invalid or repeated name in `rpc`.

```ocaml
val call : Fetcher.t -> string -> Rpc.t list -> Rpc.t
```
`call stub name args` calls the RPC method `name` of the object that `stub` reaches, with `args`, and waits for the result. It is [`Rpc.call`](./Workero-Rpc.md#val-call): arguments and result are [`Rpc.t`](./Workero-Rpc.md#type-t) values, so `Date`, `Map`, bytes, streams, stubs and functions cross the call, and a JavaScript `undefined` result reads as ``Undefined`. The runtime creates the object on the first call. Suspends. Raises [`Js_error`](./Workero.md#exception-Js_error) when the method is missing or when it raises or rejects; the error message is that of the remote exception. Raises `Invalid_argument` when an argument or the result has no [`Rpc.t`](./Workero-Rpc.md#type-t) form.

```ocaml
module Namespace : sig ... end
```