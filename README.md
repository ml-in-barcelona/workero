# workero

Write Cloudflare Workers in OCaml (via wasm_of_ocaml)

```ocaml
let handler req env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "hello\n"
  | POST, "/echo" -> Response.make (Request.bytes req)
  | GET, "/upstream" ->
      let r = Workero.fetch "https://example.com/" in
      Response.text ~status:(`Status (Response.status r)) (Response.body_text r)
  | GET, "/env" ->
      Response.text (Option.value (Env.var env "GREETING") ~default:"unset")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```

Handlers run in direct style, with no monad and no callbacks. A wait such as
`Request.text`, `Workero.fetch` or `Promise.await` suspends the handler with
OCaml 5 effects over JSPI, so other requests run meanwhile
([how it works](docs/workero/async.md)). Use `Context.wait_until ctx f` for
work that continues after the response.

`Workero.JSON` reads and writes JSON with
[jsonkit](https://github.com/melange-community/jsonkit). Values are
`Jsonkit.t`. Add `jsonkit` to your dune `libraries` to build or decode them:

```ocaml
let handler req _env _ctx =
  match Workero.JSON.parse req with
  | Ok json -> Workero.JSON.response json
  | Error msg -> Workero.JSON.error msg

let () = Workero.serve handler
```

`Workero.Router` matches methods and paths with parameters, as in
`/users/:id<int>` and `/files/:rest<string...>`. It answers 404, 405 and 400
itself:

```ocaml
let router =
  Workero.Router.make
    [
      Workero.Router.get "/users/:id<int>" (fun params _req _env _ctx ->
          Workero.Response.text (Workero.Router.param_exn params "id"));
    ]

let () = Workero.serve (Workero.Router.to_handler router)
```

Register a Cron Trigger handler with `Workero.scheduled`. It can run alongside
`Workero.serve`, or on its own. Add the schedule to `wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]
```

```ocaml
let () =
  Workero.scheduled (fun controller _env _ctx ->
      ignore (Workero.Scheduled.cron controller))
```

Read required secrets with `Env.secret`, object variables with `Env.json`, and
Secrets Store secrets with `Secret_store`. Call another Worker through a service
binding with `Fetcher`:

```ocaml
let handler req env _ctx =
  let open Workero in
  let token = Env.secret env "API_TOKEN" in
  let backend = Fetcher.of_env env "BACKEND" in
  let res =
    Fetcher.fetch ~headers:[ ("authorization", "Bearer " ^ token) ] backend
      "http://backend/users"
  in
  Response.text ~status:(`Status (Response.status res)) (Response.body_text res)
```

Send messages to a Cloudflare Queue with `Queue`, and receive them with
`Workero.queue`. `Queue` hides `Stdlib.Queue` under `open Workero`:

```ocaml
let handler _req env _ctx =
  let jobs = Workero.Queue.of_env env "JOBS" in
  Workero.Queue.send jobs (Workero.Queue.Json (`Assoc [ ("id", `Int 7) ]));
  Workero.Response.text "queued\n"

let () =
  Workero.serve handler;
  Workero.queue (fun batch _env _ctx ->
      List.iter
        (fun message ->
          ignore (Workero.Queue.Message.body_json message);
          Workero.Queue.Message.ack message)
        (Workero.Queue.Batch.messages batch))
```

Open an outbound TCP connection with `Socket`. Reads and writes use the
`Stream` reader and writer:

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let socket = Socket.connect ~host:"gopher.floodgap.com" ~port:70 () in
  Socket.opened socket;
  Stream.Writer.write (Socket.writer socket) "/\r\n";
  let reply = Stream.Reader.read (Socket.reader socket) in
  Socket.close socket;
  Response.text (Option.value reply ~default:"")
```

Receive email from Email Routing with `Workero.email`. The handler forwards,
replies to or rejects each message:

```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      let open Workero in
      if Email.raw_size message > 1_000_000 then
        Email.set_reject message "message too large"
      else Email.forward message "me@example.org")
```

`Hyperdrive` gives the connection details of a database (it has no query
driver yet), `Rate_limiter.limit` checks a rate limit binding, `Ai.run` runs a
Workers AI model with JSON input and output, and `Analytics_engine.write`
records a data point:

```ocaml
let handler req env _ctx =
  let open Workero in
  let key = Option.value (Request.header req "cf-connecting-ip") ~default:"anon" in
  if not (Rate_limiter.limit (Rate_limiter.of_env env "LIMITER") key) then
    Response.text ~status:`Too_Many_Requests "slow down\n"
  else begin
    Analytics_engine.write ~index:key ~doubles:[ 1. ]
      (Analytics_engine.of_env env "EVENTS");
    JSON.response
      (Ai.run (Ai.of_env env "AI") "@cf/meta/llama-3.1-8b-instruct"
         (`Assoc [ ("prompt", `String "Say hi") ]))
  end
```

Keep state in a Durable Object with SQLite storage. Register the class at the
top level of the program, and declare it in `wrangler.toml`:

```ocaml
let () =
  Workero.Durable_object.register "Counter" (fun state _env ->
      let open Workero in
      let storage = Durable_object.State.storage state in
      Durable_object.make
        ~fetch:(fun _req ->
          let n =
            match Durable_object.Storage.get storage "count" with
            | Some (`Int n) -> n + 1
            | _ -> 1
          in
          Durable_object.Storage.put storage "count" (`Int n);
          Response.text (string_of_int n))
        ())
```

Reach an object with `Durable_object.Namespace.get_by_name` and `Fetcher.fetch`.
RPC methods: `register ~rpc:["incr"]` and `make ~rpc` let a JavaScript caller
write `stub.incr()`; OCaml code uses `Durable_object.call`.
Alarms use `Storage.set_alarm` and the `~alarm` handler. `Storage.sql` and
`Storage.transaction_sync` give SQL and transactions. `State.accept_websocket`
and the `~websocket_message` handler serve hibernatable WebSockets.

Expose RPC methods to other Workers with `Entrypoint.register`, bind the class
with `entrypoint = "Math"` in a `[[services]]` entry, and call it from OCaml with
`Entrypoint.call (Fetcher.of_env env "MATH") "add" [ `Int 2; `Int 3 ]`:

```ocaml
let () =
  Workero.Entrypoint.register "Math" ~rpc:[ "add" ] (fun _env _ctx ->
      Workero.Entrypoint.make
        ~rpc:(fun name args ->
          match (name, args) with
          | "add", [ `Int a; `Int b ] -> `Int (a + b)
          | _ -> invalid_arg name)
        ())
```

## Build and package a worker

Build an executable with `(modes wasm)` from the dune project:

```sh
workero build src/main.bc.wasm.js
```

`build` runs dune and writes the worker to `_worker/`. If dune already built the
executable, package its output without running dune again:

```sh
workero package _build/default/src/main.bc.wasm.js
```

Both commands accept `--out <dir>` to choose another output directory. They run
the program once in `workerd` to find its Durable Object and entrypoint classes, so `workerd`
must be installed (`npm install workerd`, or Wrangler). See the
[documentation](https://ml-in-barcelona.github.io/workero/workero/),
[getting started](https://ml-in-barcelona.github.io/workero/workero/getting_started.html),
and [CLI guide](https://ml-in-barcelona.github.io/workero/workero/cli.html).

## Demos

- [https://workero-example-basic.davesnx.workers.dev](https://workero-example-basic.davesnx.workers.dev) ([source](examples/basic/)): reports the OCaml version, the backend and the requests served by the isolate.
- [https://workero-example-limits.davesnx.workers.dev](https://workero-example-limits.davesnx.workers.dev) ([source](examples/limits/)): runs a CPU task or allocates memory.
- [https://workero-example-features.davesnx.workers.dev](https://workero-example-features.davesnx.workers.dev) ([source](examples/features/)): serves routes for wasm_of_ocaml features.
- [https://workero-example-hello.davesnx.workers.dev](https://workero-example-hello.davesnx.workers.dev) ([source](examples/hello/)): runs effect handlers and awaits promises.
- [https://workero-example-promise.davesnx.workers.dev](https://workero-example-promise.davesnx.workers.dev) ([source](examples/promise/)): compares sequential and concurrent waits.
- [https://workero-example-react.davesnx.workers.dev](https://workero-example-react.davesnx.workers.dev) ([source](examples/react/)): runs a lightweight version of [server-reason-react](https://github.com/ml-in-barcelona/server-reason-react) for React SSR in OCaml.

To work on the repository, see [CONTRIBUTING.md](CONTRIBUTING.md).
