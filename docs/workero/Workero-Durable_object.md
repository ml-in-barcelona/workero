
# Module `Workero.Durable_object`

Durable Objects with SQLite storage.

A Durable Object class is a function from its [`State`](./Workero-Durable_object-State.md) and the [`Env`](./Workero-Env.md) to the handlers of one object, built with [`make`](./#val-make) and bound to a name with [`register`](./#val-register). Declare the class in `wrangler.toml` with `[durable_objects]` and a migration with `new_sqlite_classes`, or with the `exports` map and `storage = "sqlite"`. `workero build` exports every registered class. Only SQLite-backed classes are supported: [`Storage`](./Workero-Durable_object-Storage.md) fails on a class backed by the legacy key-value storage.

Handlers on one object interleave only where they suspend, so a handler that uses [`Storage`](./Workero-Durable_object-Storage.md) and never calls [`Promise.await`](./Workero-Promise.md#val-await) runs without interruption. Keep the state of an object in values created inside the function given to [`register`](./#val-register), never in module-level values: one isolate may host many objects, and the runtime may evict an object from memory and create it again later.

```ocaml
module Id : sig ... end
```
```ocaml
module Storage : sig ... end
```
The storage of one object. The key-value functions are synchronous: they never suspend. Values are JSON, converted with `JSON.stringify` and `JSON.parse`. A `Date` stored by JavaScript code reads as its ISO string and a `Map` as `{}`. `get` and `list` raise `Invalid_argument` for a stored value that `JSON.stringify` rejects, such as a `BigInt` or a cyclic object. The functions raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws, for example on a class that is not backed by SQLite.

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
  unit ->
  t
```
`make ()` gives an object that handles no event. `init` runs under `blockConcurrencyWhile` before the first event, each time the object is created, and may call [`Promise.await`](./Workero-Promise.md#val-await); if it raises, the runtime resets the object. `fetch` answers the requests that a stub sends. `alarm` runs when the alarm is due; an exception makes the runtime retry it. Every handler runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). A stub fetch on an object without a `fetch` handler fails.

```ocaml
val register : string -> (State.t -> Env.t -> t) -> unit
```
`register class_name create` binds `create` to the class that `workero build` exports under `class_name`. Call it at module initialisation, once per class. The build reads the names by running the program in `workerd`; a `register` call that a condition skips at initialisation is not exported.

`create` runs each time the runtime creates the object, before the first event. It must not call [`Promise.await`](./Workero-Promise.md#val-await): that raises `Invalid_argument`. Load stored values in `~init` of [`make`](./#val-make). If `create` raises, the object fails to start and the request that needed it fails.

Raises `Invalid_argument` when `class_name` is empty, starts with a digit, has a character other than an ASCII letter, a digit, `"_"` or `"$"`, is `"default"`, `"then"` or `"__proto__"`, or is already registered. Reserved words such as `"class"` are accepted: the generated module exports the class under that name without declaring a variable of it.

```ocaml
module Namespace : sig ... end
```