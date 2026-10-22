
# Entrypoints

A [WorkerEntrypoint](https://developers.cloudflare.com/workers/runtime-apis/rpc/) is a named class of a Worker. Its methods are RPC methods: another Worker calls them through a service binding as if they were local functions. [`Workero.Entrypoint`](./Workero-Entrypoint.md) declares such a class in OCaml. JavaScript Workers and OCaml Workers can call it.


## Declare a class

Register the class under a name at module initialisation. Give the names of its methods with `~rpc`, and a function that builds the handlers:

```ocaml
open Workero

let () =
  Entrypoint.register "Math" ~rpc:[ "add"; "greet" ] (fun env _ctx ->
      Entrypoint.make
        ~rpc:(fun name args ->
          match (name, args) with
          | "add", [ `Int a; `Int b ] -> `Int (a + b)
          | "greet", [ `String who ] ->
              `String
                (Option.value (Env.var env "GREETING") ~default:"Hello"
                ^ ", " ^ who)
          | _ -> invalid_arg ("bad call to " ^ name))
        ())
```
`workero build` runs the program once in `workerd` and exports every registered class from `index.js`. It reads the names in `~rpc` at that time, before the program has an [`Workero.Env.t`](./Workero-Env.md#type-t), so they are given apart from the handler. The `rpc` handler of [`Workero.Entrypoint.make`](./Workero-Entrypoint.md#val-make) gets the method name and the arguments, like the `rpc` handler of a Durable Object. A call to a declared name on a class whose handlers have no `rpc` fails with an error.

The handler gets the arguments of the call as a list of JSON values and returns one JSON value. It runs in its own fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the other bindings. An exception that the handler raises rejects the call. The caller sees an `Error` whose message is the exception.

The runtime creates a new instance of the class for each call. The function given to [`Workero.Entrypoint.register`](./Workero-Entrypoint.md#val-register) runs for each of them and gets the `env` and the `ctx`, so a method can call [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until). Keep no state in it.


## Call it from JavaScript

Bind the class in the `wrangler.toml` of the caller. The caller may be this Worker or another one:

```toml
[[services]]
binding = "MATH"
service = "my-worker"
entrypoint = "Math"
```
```javascript
const sum = await env.MATH.add(2, 3); // 5
```

## Call it from OCaml

Read the binding with [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) and call a method with [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call):

```ocaml
let handler _req env _ctx =
  let math = Fetcher.of_env env "MATH" in
  match Entrypoint.call math "add" [ `Int 2; `Int 3 ] with
  | `Int sum -> Response.text (string_of_int sum)
  | _ -> Response.text ~status:`Bad_Gateway "unexpected result"
```
The callee may be an entrypoint written in OCaml or in JavaScript. [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the method does not exist or raises, and when the runtime rejects the call.


## The fetch handler

[`Workero.Entrypoint.make`](./Workero-Entrypoint.md#val-make) accepts a `~fetch` handler. It answers [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) on a binding of the class. Without it, such a request fails with an error.


## Limits

- Arguments and results are JSON values. RPC also accepts `Uint8Array`, `Date`, `Map`, `BigInt`, streams and stubs, but [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call) and the handlers do not. A result with no JSON form raises `Invalid_argument`. A result of `undefined` is ``Null`.
- The `scheduled`, `queue`, `email` and `tail` handlers of a class are not supported.
- A class cannot share its name with a Durable Object class, and the method names `constructor`, `prototype`, `__proto__`, `then`, `env`, `ctx`, `fetch`, `scheduled`, `queue`, `email`, `tail`, `trace`, `tailStream`, `test`, `connect` and `dup` are reserved.
- RPC methods on Durable Object stubs are not part of this page.