
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

The handler gets the arguments of the call as a list of [`Workero.Rpc.t`](./Workero-Rpc.md#type-t) values and returns one. They are JSON values and also bytes, dates, big integers, maps, sets, streams, stubs and functions. See [`Workero.Rpc`](./Workero-Rpc.md) for the full list. The handler runs in its own fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the other bindings. An exception that the handler raises rejects the call. The caller sees an error whose message includes the exception.

The runtime creates a new instance of the class for each call. The function given to [`Workero.Entrypoint.register`](./Workero-Entrypoint.md#val-register) runs for each of them and gets the `env` and the `ctx`, so a method can call [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until). This function cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Keep no state in the instance: two calls can run in different instances.


## Call it from JavaScript

Bind the class in the `wrangler.toml` of the caller. `service` is the name of the Worker that holds the class, and `entrypoint` is the name given to [`Workero.Entrypoint.register`](./Workero-Entrypoint.md#val-register). The caller may be this Worker or another one:

```toml
[[services]]
binding = "MATH"
service = "my-worker"
entrypoint = "Math"
```
```javascript
const sum = await env.MATH.add(2, 3); // 5
const hello = await env.MATH.greet("Ana"); // "Hello, Ana"
```
An OCaml method that returns ``Null` gives `null` in JavaScript, and one that returns ``Undefined` gives `undefined`.


## Call it from OCaml

Read the binding with [`Workero.Fetcher.of_env`](./Workero-Fetcher.md#val-of_env) and call a method with [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call):

```ocaml
open Workero

let handler _req env _ctx =
  let math = Fetcher.of_env env "MATH" in
  match Entrypoint.call math "add" [ `Int 2; `Int 3 ] with
  | `Int sum -> Response.text (string_of_int sum)
  | _ -> Response.text ~status:`Bad_Gateway "unexpected result"

let () = serve handler
```
The response body is `5`.

The callee may be an entrypoint written in OCaml or in JavaScript. [`Workero.Entrypoint.call`](./Workero-Entrypoint.md#val-call) suspends like [`Workero.Promise.await`](./Workero-Promise.md#val-await). It raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the method does not exist or raises, and when the runtime rejects the call. A method that returns `undefined` in JavaScript gives ``Undefined`.


## The fetch handler

[`Workero.Entrypoint.make`](./Workero-Entrypoint.md#val-make) accepts a `~fetch` handler. It answers [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) on a binding of the class, like `env.MATH.fetch(request)` in JavaScript. Without it, such a request fails with an error.


## The scheduled, queue and email handlers

[`Workero.Entrypoint.make`](./Workero-Entrypoint.md#val-make) also accepts `~scheduled`, `~queue` and `~email`. They are the `scheduled(controller)`, `queue(batch)` and `email(message)` methods of a JavaScript `WorkerEntrypoint` class. They take the same values as [`Workero.scheduled`](./Workero.md#val-scheduled), [`Workero.queue`](./Workero.md#val-queue) and [`Workero.email`](./Workero.md#val-email), without `env` and `ctx`: the function given to [`Workero.Entrypoint.register`](./Workero-Entrypoint.md#val-register) has them.

```ocaml
open Workero

let () =
  Entrypoint.register "Jobs" (fun env _ctx ->
      Entrypoint.make
        ~scheduled:(fun controller ->
          Console.log ("cron " ^ Scheduled.cron controller))
        ~queue:(fun batch ->
          List.iter
            (fun m -> Console.log (Queue.Message.body_text m))
            (Queue.Batch.messages batch))
        ())
```
Point a cron trigger, a queue consumer or an email route at the class. Each handler runs in its own fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await). An exception that it raises rejects the event. A class answers only the events that have a handler; the runtime rejects the others.

The `email` handler on a class is untested against the runtime. The tests call the class with a mock message. They do not show that Email Routing delivers a message to a class. The `scheduled` and `queue` handlers are tested through service bindings in `workerd`.


## Limits

- A value with no [`Workero.Rpc.t`](./Workero-Rpc.md#type-t) form, such as an `Error`, raises `Invalid_argument`.
- The `tail` handler of a class is not supported.
- [`Workero.Entrypoint.register`](./Workero-Entrypoint.md#val-register) raises `Invalid_argument` when the class name is also the name of a Durable Object class, a Workflow or another entrypoint. It raises the same exception for a duplicate method name or one that is not a JavaScript identifier.
- These method names are reserved: `constructor`, `prototype`, `__proto__`, `then`, `env`, `ctx`, `fetch`, `scheduled`, `queue`, `email`, `tail`, `trace`, `tailStream`, `test`, `connect` and `dup`.
- For RPC methods on Durable Object stubs, see [Durable Objects](./durable_objects.md).