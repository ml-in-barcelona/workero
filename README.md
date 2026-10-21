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

Both commands accept `--out <dir>` to choose another output directory. See the
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
