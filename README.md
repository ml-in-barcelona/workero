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
      Response.text ~status:(Response.status r) (Response.body_text r)
  | GET, "/env" ->
      Response.text (Option.value (Env.var env "GREETING") ~default:"unset")
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
```

Handlers run in direct style: `Request.text`, `Workero.fetch`, and
`Promise.await` wait for JavaScript promises without blocking other requests.
Use `Context.wait_until ctx f` for work that continues after the response.

`Workero.JSON` reads and writes JSON with
[jsonkit](https://github.com/melange-community/jsonkit):

```ocaml
let handler req _env _ctx =
  match Workero.JSON.parse req with
  | Ok json -> Workero.JSON.response json
  | Error msg -> Workero.JSON.error msg

let () = Workero.serve handler
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

- [https://workero-example-basic.davesnx.workers.dev](https://workero-example-basic.davesnx.workers.dev) ([source](examples/basic/)): reports the OCaml version and backend.
- [https://workero-example-react.davesnx.workers.dev](https://workero-example-react.davesnx.workers.dev) ([source](examples/react/)): renders a page on the server.
- [https://workero-example-limits.davesnx.workers.dev](https://workero-example-limits.davesnx.workers.dev) ([source](examples/limits/)): runs a CPU task or allocates memory.
- [https://workero-example-features.davesnx.workers.dev](https://workero-example-features.davesnx.workers.dev) ([source](examples/features/)): serves routes for wasm_of_ocaml features.
- [https://workero-example-hello.davesnx.workers.dev](https://workero-example-hello.davesnx.workers.dev) ([source](examples/hello/)): runs effect handlers and awaits promises.
- [https://workero-example-jspi.davesnx.workers.dev](https://workero-example-jspi.davesnx.workers.dev) ([source](examples/jspi/)): compares sequential and concurrent waits.

To work on the repository, see [CONTRIBUTING.md](CONTRIBUTING.md).
