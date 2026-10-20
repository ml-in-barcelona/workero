# workero

Write Cloudflare Workers in OCaml (via wasm_of_ocaml)

- `lib/`: the `workero` library (`Workero.serve`, `Workero.scheduled`, `Workero.fetch`, `Request`, `Method`, `Context`, `Response`, `Env`, `Scheduled`, `URL`).
- `lib/json/`: the `workero-json` package (`Workero_json`): JSON request bodies and responses with [jsonkit](https://github.com/melange-community/jsonkit).
- `test/`: unit tests (`test/unit/`), the worker tests (`test/worker/`) and the JSON tests (`test/json/`). See Development.
- `bin/`: the `workero` CLI. `workero build <dir>/<name>` writes a worker to `_worker/`.
- `examples/basic/`: a hello world worker that reports the OCaml version and backend.
- `examples/react/`: server-side React with `.mlx` components.
- `examples/limits/`: pushes the Workers limits with a CPU route and a memory route.
- `examples/bench.sh`: bundle size and response times for an example (`DIR=examples/react examples/bench.sh`).
- `template/`: a starter project to copy. See its README.
- `examples/hello/`, `examples/hello-jspi/`: the experiments that led here. Each one is its own dune project.

## Demos

- https://workero-example.davesnx.workers.dev (`examples/basic`): hello world, reports the OCaml version and backend.
- https://workero-example-react.davesnx.workers.dev (`examples/react`): a page rendered on the server from `.mlx` components.
- https://workero-example-limits.davesnx.workers.dev (`examples/limits`): `/cpu?n=1000&iter=500` renders a Mandelbrot set, `/memory?mb=200` allocates 200 MB. Raise the numbers until it fails.

## Size

Cloudflare limits a worker to 64 MiB uncompressed and sets no compressed limit ([limits](https://developers.cloudflare.com/workers/platform/limits/#worker-size)). The examples upload 96 to 123 KiB (31 to 40 KiB gzip).

## Usage

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

Handlers run in direct style: `Request.text`, `Workero.fetch` and
`Promise.await` wait for the JavaScript Promise without blocking other
requests. A rejected Promise raises `Workero.Js_error`. Use
`Context.wait_until ctx f` for work that continues after the response.

For JSON, depend on `workero-json`:

```ocaml
match Workero_json.parse req with
| Ok json -> Workero_json.response json
| Error msg -> Workero_json.error msg
```

## Cron triggers

`Workero.scheduled` registers a handler for Cron Triggers. It can run next to
`Workero.serve`; `workero build` exports only the handlers the program
registered, so a cron-only worker works. List the schedules in
`wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]
```

```ocaml
let () =
  Workero.scheduled (fun controller _env _ctx ->
      ignore (Workero.Scheduled.cron controller))
```

## Logging

`print_endline`, `Printf.printf "...%!"`, `prerr_endline` and
`Printf.eprintf "...%!"` reach the Workers logs (checked in workerd). Output
that is not flushed, such as `Printf.printf` without `%!` or a newline-only
`print_string`, stays in the buffer: flush it.

## Development

`make help` lists the targets. `make test` runs the unit, worker and JSON
tests.

- Unit tests, `test/unit/`: alcotest executables built with `(modes js)` and run
  by node through `dune test`. They cover code that does not await, such as
  `Workero.URL`. Alcotest has no wasm runtime, and node 22 has no JSPI, so code
  that uses `Promise.await` cannot run here. To add a test, write a function in
  `test/unit/test_workero.ml` and list it in `Alcotest.run`. A new file needs a
  `(test (name ...) (modes js) (libraries workero alcotest))` stanza.
- Worker tests, `test/worker/`: `make test-worker` builds `test/worker/main.ml`
  with `workero build`, then runs `test/worker/tests.mjs` in `workerd test`
  (no port). The worker is bound as `env.WORKER`, with `GREETING` set. To add a
  test, add a route to `test/worker/main.ml` and a case to `cases` in
  `tests.mjs` (`status`, `body`, `headers`, or `throws` for a handler that
  raises: a service binding rethrows where HTTP answers 500). `workerd` must be
  on `PATH`; `npm install workerd` or `wrangler` provides it.
- JSON tests, `test/json/`: the same two kinds for `workero-json`
  (`test/json/test_json.ml`, and `make test-json` for `test/json/tests.mjs`).
