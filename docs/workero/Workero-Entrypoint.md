
# Module `Workero.Entrypoint`

`WorkerEntrypoint` classes with RPC methods.

An entrypoint class is a set of named methods that other Workers call through a service binding, like `env.MATH.add(1, 2)` in JavaScript. Declare one with [`register`](./#val-register). `workero build` exports every registered class, so a binding can name it with `entrypoint = "Math"` in `wrangler.toml`:

```
  [[services]]
  binding = "MATH"
  service = "my-worker"
  entrypoint = "Math"
```
Another Worker, in JavaScript or OCaml, calls the methods of that binding. Use [`call`](./#val-call) from OCaml.

Arguments and results are [`Rpc.t`](./Workero-Rpc.md#type-t) values: JSON, and also bytes, `Date`, `BigInt`, `Map`, `Set`, streams, stubs and functions. A method that returns nothing in JavaScript gives ``Undefined` to [`call`](./#val-call).

```ocaml
type t
```
The handlers of one entrypoint instance.

```ocaml
val make : 
  ?fetch:(Request.t -> Response.t) ->
  ?rpc:(string -> Rpc.t list -> Rpc.t) ->
  unit ->
  t
```
`make ()` gives an entrypoint that answers no call. `fetch` answers requests sent to the binding with [`Fetcher.fetch`](./Workero-Fetcher.md#val-fetch). `rpc` answers the calls of the methods that [`register`](./#val-register) declared: `rpc name args` gets the method name and the arguments, and returns the result. It decides what an unknown name does; raise an exception to reject the call. Every handler runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). An exception raised by a handler rejects the call, so the caller gets an error.

```ocaml
val register : ?rpc:string list -> string -> (Env.t -> Context.t -> t) -> unit
```
`register ~rpc class_name create` binds `create` to the class that `workero build` exports under `class_name`. Call it at module initialisation, once per class. `rpc` lists the method names, for example `["add"]`. The build reads them by running the program in `workerd`, before it has an [`Env.t`](./Workero-Env.md#type-t), so they are given here and answered by the `rpc` handler of [`make`](./#val-make). A call to a declared name on a class whose handlers have no `rpc` fails.

`create` gets the `env` and the `ctx` of the instance, so a method can call [`Context.wait_until`](./Workero-Context.md#val-wait_until). It runs for each call, as the runtime creates a new instance of the class for each call. It must not call [`Promise.await`](./Workero-Promise.md#val-await): that raises `Invalid_argument`. Keep no state in the instance; two calls can run in different instances. If `create` raises, the call fails.

Raises `Invalid_argument` when `class_name` is not a valid class name (see [`Durable_object.register`](./Workero-Durable_object.md#val-register)), when it is also the name of a Durable Object class or of another entrypoint, or when `rpc` has a duplicate or a name that is not a JavaScript identifier. The names `constructor`, `prototype`, `__proto__`, `then`, `env`, `ctx`, `fetch`, `scheduled`, `queue`, `email`, `tail`, `trace`, `tailStream`, `test`, `connect` and `dup` are reserved.

```ocaml
val call : Fetcher.t -> string -> Rpc.t list -> Rpc.t
```
`call binding name args` calls the RPC method `name` of the entrypoint behind `binding`, a service binding read with [`Fetcher.of_env`](./Workero-Fetcher.md#val-of_env), and waits for the result. It is [`Rpc.call`](./Workero-Rpc.md#val-call). A result that is `undefined` in JavaScript gives ``Undefined`. Suspends like [`Promise.await`](./Workero-Promise.md#val-await).

Raises [`Js_error`](./Workero.md#exception-Js_error) when the method does not exist, when it raises, or when the runtime rejects the call. Raises `Invalid_argument` when the result has no [`Rpc.t`](./Workero-Rpc.md#type-t) form, or when an argument has none.
