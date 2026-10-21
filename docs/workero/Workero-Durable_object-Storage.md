
# Module `Durable_object.Storage`

The storage of one object. The key-value functions are synchronous: they never suspend. Values are JSON, converted with `JSON.stringify` and `JSON.parse`. A `Date` stored by JavaScript code reads as its ISO string and a `Map` as `{}`. `get` and `list` raise `Invalid_argument` for a stored value that `JSON.stringify` rejects, such as a `BigInt` or a cyclic object. The functions raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws, for example on a class that is not backed by SQLite.

```ocaml
type t
```
```ocaml
val get : t -> string -> Jsonkit.t option
```
`None` when the key is absent.

```ocaml
val put : t -> string -> Jsonkit.t -> unit
```
```ocaml
val delete : t -> string -> bool
```
`true` when the key existed.

```ocaml
val list : 
  ?prefix:string ->
  ?start:string ->
  ?end_:string ->
  ?reverse:bool ->
  ?limit:int ->
  t ->
  (string * Jsonkit.t) list
```
Entries in key order (`reverse` flips it). `start` is inclusive and `end_` is exclusive.

```ocaml
val sql : t -> Sql.t
```
```ocaml
val transaction_sync : t -> (unit -> 'a) -> 'a
```
`transaction_sync storage f` runs `f` in a transaction and returns its result. If `f` raises, every write of `f` to storage and to SQL is rolled back and the same exception reaches the caller. `f` cannot suspend: a call to [`Promise.await`](./Workero-Promise.md#val-await) in it raises `Invalid_argument`.

```ocaml
val delete_all : t -> unit
```
Deletes every key-value pair. It does not delete an alarm. Suspends.

```ocaml
val sync : t -> unit
```
Waits until earlier writes are durable. Suspends.


### Alarms

An object has at most one alarm. When it is due, the runtime calls the `alarm` handler of the object, wakes the object up if it was evicted, and retries a failing handler. A class that gives no `alarm` to [`make`](./Workero-Durable_object.md#val-make) still accepts [`set_alarm`](./#val-set_alarm); its alarm fails and is retried until the runtime gives up. These functions suspend.

```ocaml
val get_alarm : t -> float option
```
The scheduled time, in milliseconds since the Unix epoch, or `None` when there is no alarm.

```ocaml
val set_alarm : 
  ?allow_concurrency:bool ->
  ?allow_unconfirmed:bool ->
  t ->
  at:float ->
  unit
```
`set_alarm storage ~at` schedules the alarm at `at`, in milliseconds since the Unix epoch, and replaces an earlier alarm. A time in the past runs the handler at once.

```ocaml
val set_alarm_after : 
  ?allow_concurrency:bool ->
  ?allow_unconfirmed:bool ->
  t ->
  ms:float ->
  unit
```
`set_alarm_after storage ~ms` is [`set_alarm`](./#val-set_alarm) with `at` set to [`Date.now`](./Workero-Date.md#val-now) plus `ms`.

```ocaml
val delete_alarm : t -> unit
```
Cancels the alarm. It does nothing when there is none.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```